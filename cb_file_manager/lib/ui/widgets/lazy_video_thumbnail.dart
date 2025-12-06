import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../helpers/media/video_thumbnail_helper.dart';
import '../../helpers/ui/frame_timing_optimizer.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:remixicon/remixicon.dart' as remix;

/// A widget that efficiently displays a video thumbnail with lazy loading
/// and background processing to avoid UI thread blocking during scrolling
class LazyVideoThumbnail extends StatefulWidget {
  /// Path to the video file for which the thumbnail should be generated
  final String videoPath;

  /// Width of the thumbnail
  final double width;

  /// Height of the thumbnail
  final double height;

  /// Builder function that returns a widget to show when thumbnail is loading or on error
  final Widget Function() fallbackBuilder;

  /// Whether to keep the thumbnail in memory when it's scrolled out of view
  final bool keepAlive;

  /// If true, only shows the placeholder and doesn't attempt to load thumbnails
  final bool placeholderOnly;

  /// Callback when thumbnail is successfully generated
  final Function(String path)? onThumbnailGenerated;

  /// Callback when thumbnail generation fails with an error
  final Function(dynamic error)? onError;

  const LazyVideoThumbnail({
    Key? key,
    required this.videoPath,
    this.width = 160,
    this.height = 120,
    required this.fallbackBuilder,
    this.keepAlive = true,
    this.placeholderOnly = false,
    this.onThumbnailGenerated,
    this.onError,
  }) : super(key: key);

  @override
  State<LazyVideoThumbnail> createState() => _LazyVideoThumbnailState();
}

class _LazyVideoThumbnailState extends State<LazyVideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  // Notifiers to maintain widget state
  final _visibilityNotifier = ValueNotifier<bool>(false);
  final _thumbnailPathNotifier = ValueNotifier<String?>(null);
  final _progressNotifier = ValueNotifier<double>(0.0);

  // State tracking
  bool _isLoading = false;
  bool _wasAttempted = false;
  bool _isThumbnailGenerated = false;
  bool _shouldRegenerateThumbnail = true;
  bool _hasSyncLoadLog = false;
  bool _hasFrameLoadLog = false;

  // Progress simulation timer
  Timer? _progressTimer;

  // Lightweight cache polling to recover missed repaints
  Timer? _cachePollTimer;
  int _cachePollAttempts = 0;
  static const int _maxCachePollAttempts = 10; // ~5s if 500ms interval

  // PERFORMANCE: Debouncing timer for visibility changes
  Timer? _visibilityDebounceTimer;
  static const Duration _visibilityDebounceDuration =
      Duration(milliseconds: 300);

  // Stream subscription to cache clear events
  StreamSubscription? _cacheChangedSubscription;
  // Subscription to per-file thumbnail ready notifications
  StreamSubscription<String>? _thumbReadySubscription;

  // AutomaticKeepAliveClientMixin implementation
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    // Use the helper's throttled log method
    VideoThumbnailHelper.logWithThrottle(
        '[Thumbnail] Initializing thumbnail', widget.videoPath);

    _scheduleInitialLoad();

    // Subscribe to cache changed events
    _cacheChangedSubscription = VideoThumbnailHelper.onCacheChanged.listen((_) {
      _handleCacheCleared();
    });

    // Listen for specific thumbnail ready events for this video path
    _thumbReadySubscription =
        VideoThumbnailHelper.onThumbnailReady.listen((readyVideoPath) async {
      if (!mounted) return;
      if (readyVideoPath != widget.videoPath) return;

      // If we don't yet show a thumbnail, update from cache and repaint
      if (_thumbnailPathNotifier.value == null) {
        try {
          final cached =
              await VideoThumbnailHelper.getFromCache(widget.videoPath);
          if (!mounted) return;
          if (cached != null) {
            _thumbnailPathNotifier.value = cached;
            _isThumbnailGenerated = true;
            _shouldRegenerateThumbnail = false;
            _onThumbnailGenerated(cached);
            _cachePollTimer?.cancel();
            _cachePollAttempts = 0;
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _visibilityNotifier.dispose();
    _thumbnailPathNotifier.dispose();
    _progressNotifier.dispose();
    _progressTimer?.cancel();
    _cachePollTimer?.cancel();
    _visibilityDebounceTimer?.cancel();
    _cacheChangedSubscription?.cancel();
    _thumbReadySubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(LazyVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only set regeneration flag if the path actually changed
    if (widget.videoPath != oldWidget.videoPath) {
      _shouldRegenerateThumbnail = true;
      _hasSyncLoadLog = false;
      _hasFrameLoadLog = false;
      _scheduleInitialLoad();
    }
  }

  /// Handle the event when the thumbnail cache is cleared
  void _handleCacheCleared() {
    // Use the helper's throttled log method
    VideoThumbnailHelper.logWithThrottle(
        '[Thumbnail] Cache cleared notification received', widget.videoPath);

    if (!mounted) return;

    _thumbnailPathNotifier.value = null;
    _isThumbnailGenerated = false;
    _shouldRegenerateThumbnail = true;
    _wasAttempted = false;
    _hasSyncLoadLog = false; // Reset frame log flag when cache is cleared
    _hasFrameLoadLog = false; // Reset frame log flag when cache is cleared

    // Only reload immediately if the widget is visible
    if (_visibilityNotifier.value) {
      // Use the helper's throttled log method
      VideoThumbnailHelper.logWithThrottle(
          '[Thumbnail] Widget is visible, reloading thumbnail after cache clear',
          widget.videoPath);

      // Use a small delay to allow other operations to complete first
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;

        // Request with high priority and force regeneration
        _loadThumbnail(forceRegenerate: true, isPriority: true);
        _startCachePolling();
      });
    }
  }

  /// Schedule initial thumbnail load after layout is complete
  void _scheduleInitialLoad() {
    // Don't schedule if we've determined we don't need to regenerate
    if (!_shouldRegenerateThumbnail) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Start a Future chain to check cache and load thumbnail
      VideoThumbnailHelper.getFromCache(widget.videoPath)
          .then((cachedThumbnailPath) {
        if (!mounted) return;

        // If we have a cached path, use it immediately
        if (cachedThumbnailPath != null) {
          _thumbnailPathNotifier.value = cachedThumbnailPath;
          _isThumbnailGenerated = true;
          _shouldRegenerateThumbnail = false;

          // Notify parent if we already have a thumbnail
          if (widget.onThumbnailGenerated != null) {
            widget.onThumbnailGenerated!(cachedThumbnailPath);
          }
          return;
        }

        // If no cached thumbnail, check if we should load
        if (_visibilityNotifier.value && !widget.placeholderOnly) {
          _loadThumbnail(isPriority: true);
        }
      }).catchError((error) {
        // Use the helper's throttled log method
        VideoThumbnailHelper.logWithThrottle(
            '[Thumbnail] Error checking cache: $error', widget.videoPath);

        // Try loading anyway if visible and not in placeholder mode
        if (mounted && _visibilityNotifier.value && !widget.placeholderOnly) {
          _loadThumbnail(isPriority: true);
        }
      });
    });
  }

  /// Start loading the thumbnail
  void _loadThumbnail({bool forceRegenerate = false, bool isPriority = false}) {
    // Skip if already loading, if we're in placeholder-only mode,
    // if we already have a thumbnail generated and don't need to regenerate,
    // or if we've determined we don't need to regenerate
    if (_isLoading ||
        widget.placeholderOnly ||
        (_thumbnailPathNotifier.value != null && !forceRegenerate) ||
        (!_shouldRegenerateThumbnail && !forceRegenerate)) {
      return;
    }

    // Use the helper's throttled log method
    VideoThumbnailHelper.logWithThrottle(
        '[Thumbnail] Starting thumbnail load (force=$forceRegenerate, priority=$isPriority)',
        widget.videoPath);

    _isLoading = true;
    _wasAttempted = true;
    _progressNotifier.value = 0.0;

    // Start progress simulation for better UX
    _simulateProgressUpdates();

    // Use VideoThumbnailHelper directly instead of ThumbnailIsolateManager
    VideoThumbnailHelper.generateThumbnail(
      widget.videoPath,
      isPriority: isPriority,
      forceRegenerate: forceRegenerate,
    ).then((path) {
      if (!mounted) return;

      _progressTimer?.cancel();
      _isLoading = false;

      if (path != null) {
        // Use the helper's throttled log method
        VideoThumbnailHelper.logWithThrottle(
            '[Thumbnail] Thumbnail generated successfully', widget.videoPath);

        _thumbnailPathNotifier.value = path;
        _isThumbnailGenerated = true;
        _shouldRegenerateThumbnail = false;
        _onThumbnailGenerated(path);
        // Stop polling if running
        _cachePollTimer?.cancel();
        _cachePollAttempts = 0;
      } else {
        // Use the helper's throttled log method
        VideoThumbnailHelper.logWithThrottle(
            '[Thumbnail] Failed to generate thumbnail', widget.videoPath);

        _thumbnailPathNotifier.value = null;

        // Call onError callback if provided
        if (widget.onError != null) {
          widget.onError!('Failed to generate thumbnail');
        }

        // Start polling cache while visible to recover missed updates
        if (_visibilityNotifier.value) {
          _startCachePolling();
        }
      }

      // Update UI - no need for setState since we use ValueListenableBuilder
      _progressNotifier.value = 1.0;
    }).catchError((error) {
      if (!mounted) return;

      _progressTimer?.cancel();
      // Use the helper's throttled log method
      VideoThumbnailHelper.logWithThrottle(
          '[Thumbnail] Error generating thumbnail: $error', widget.videoPath);

      _thumbnailPathNotifier.value = null;
      _isLoading = false;
      _progressNotifier.value = 0.0;

      // Call onError callback if provided
      if (widget.onError != null) {
        widget.onError!(error);
      }
      // No setState needed - ValueListenableBuilder will handle UI updates
    });
  }

  /// Simulate progress updates for better UX while thumbnail is generating
  /// PERFORMANCE: Removed periodic timer to eliminate timer storm during scrolling
  void _simulateProgressUpdates() {
    _progressTimer?.cancel();
    _progressNotifier.value = 0.0;

    // Use a single delayed update instead of periodic timer
    // This eliminates the timer storm issue while still providing visual feedback
    _progressTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _thumbnailPathNotifier.value == null) {
        _progressNotifier.value = 0.5;
      }
    });
  }

  /// Handle the thumbnail generation completion
  void _onThumbnailGenerated(String path) {
    // Notify parent about the thumbnail being generated
    if (widget.onThumbnailGenerated != null) {
      // Use a post-frame callback to avoid calling during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Use the helper's throttled log method
          VideoThumbnailHelper.logWithThrottle(
              '[Thumbnail] Notifying parent about thumbnail generated',
              widget.videoPath);
          widget.onThumbnailGenerated!(path);
        }
      });
    }

    // No need for setState - ValueListenableBuilder will handle UI updates automatically
  }

  /// Visibility change handler that triggers thumbnail loading when widget becomes visible
  /// PERFORMANCE: Added debouncing to prevent excessive operations during scrolling
  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final isNowVisible = info.visibleFraction > 0;
    final wasVisible = _visibilityNotifier.value;

    // Only process if visibility actually changed to reduce unnecessary operations
    if (isNowVisible == wasVisible) return;

    // Cancel any pending debounced visibility change
    _visibilityDebounceTimer?.cancel();

    if (isNowVisible) {
      // Debounce visibility becoming true to avoid loading during fast scrolling
      _visibilityDebounceTimer = Timer(_visibilityDebounceDuration, () {
        if (!mounted || !_visibilityNotifier.value) return;

        _visibilityNotifier.value = true;

        // Load thumbnail if needed when widget becomes visible
        if (_thumbnailPathNotifier.value == null &&
            !_isLoading &&
            !widget.placeholderOnly &&
            !_isThumbnailGenerated) {
          _loadThumbnail(isPriority: true);
          _startCachePolling();
        } else if (_wasAttempted &&
            _thumbnailPathNotifier.value == null &&
            !_isLoading &&
            !widget.placeholderOnly &&
            !_isThumbnailGenerated) {
          _loadThumbnail(forceRegenerate: true, isPriority: true);
          _startCachePolling();
        }
      });
    } else {
      // Immediately handle becoming invisible (no debounce needed)
      _visibilityNotifier.value = false;
      _cachePollTimer?.cancel();
      _cachePollAttempts = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Ensure frame timing is optimized
    FrameTimingOptimizer().optimizeImageRendering();

    // Use a unique key for the VisibilityDetector based on video path
    // This helps Flutter identify and reuse this widget when possible
    // Use collision-free key to ensure VisibilityDetector delivers events reliably
    final Key visibilityKey = ValueKey('vid-visibility:${widget.videoPath}');

    return RepaintBoundary(
      child: ValueListenableBuilder<String?>(
        valueListenable: _thumbnailPathNotifier,
        builder: (context, thumbnailPath, _) {
          // First check if we have a valid thumbnail to display
          if (thumbnailPath != null) {
            return _buildThumbnailImage(thumbnailPath);
          }

          // The main widget that detects visibility and loads thumbnails
          return VisibilityDetector(
            key: visibilityKey,
            onVisibilityChanged: _onVisibilityChanged,
            child: widget
                .fallbackBuilder(), // Simplified - no need for Stack with single child
          );
        },
      ),
    );
  }

  // PERFORMANCE: Replaced periodic polling with event-driven approach
  // The cache polling timer was causing performance issues during scrolling
  // Now we rely on the thumbnail ready stream subscription instead
  void _startCachePolling() {
    _cachePollTimer?.cancel();
    _cachePollAttempts = 0;

    // Single delayed check instead of periodic polling
    // This dramatically reduces timer overhead during scrolling
    _cachePollTimer = Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted || !_visibilityNotifier.value) {
        return;
      }

      if (_thumbnailPathNotifier.value != null || _isLoading) {
        return;
      }

      try {
        final cached =
            await VideoThumbnailHelper.getFromCache(widget.videoPath);
        if (cached != null && mounted) {
          _thumbnailPathNotifier.value = cached;
          _isThumbnailGenerated = true;
          _shouldRegenerateThumbnail = false;
          _onThumbnailGenerated(cached);
        }
      } catch (_) {}
    });
  }

  /// Build the actual thumbnail image
  Widget _buildThumbnailImage(String thumbnailPath) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(thumbnailPath),
          key: ValueKey(
              'thumbnail-${widget.videoPath}-${thumbnailPath.hashCode}'),
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            // Use the helper's throttled log method
            VideoThumbnailHelper.logWithThrottle(
                '[Thumbnail] Error loading thumbnail image: $error',
                widget.videoPath);

            _thumbnailPathNotifier.value = null;
            _isLoading = false;
            _isThumbnailGenerated = false;
            _shouldRegenerateThumbnail = true;
            VideoThumbnailHelper.removeFromCache(widget.videoPath);
            return widget.fallbackBuilder();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              if (!_hasSyncLoadLog) {
                // Use the helper's throttled log method
                VideoThumbnailHelper.logWithThrottle(
                    '[Thumbnail] Thumbnail image loaded synchronously',
                    widget.videoPath);
                _hasSyncLoadLog = true;
              }
              // Also notify for synchronously loaded images
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    widget.onThumbnailGenerated != null &&
                    !_isThumbnailGenerated) {
                  widget.onThumbnailGenerated!(thumbnailPath);
                  _isThumbnailGenerated = true;
                  _shouldRegenerateThumbnail = false;
                }
              });
              return child;
            }

            if (frame != null) {
              if (!_hasFrameLoadLog) {
                // Use the helper's throttled log method
                VideoThumbnailHelper.logWithThrottle(
                    '[Thumbnail] Thumbnail image frame loaded',
                    widget.videoPath);
                _hasFrameLoadLog = true;
              }
              // Thumbnail is ready now
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    widget.onThumbnailGenerated != null &&
                    !_isThumbnailGenerated) {
                  widget.onThumbnailGenerated!(thumbnailPath);
                  _isThumbnailGenerated = true;
                  _shouldRegenerateThumbnail = false;
                }
              });
            }

            return AnimatedSwitcher(
              duration: const Duration(
                  milliseconds: 50), // Reduced from 200ms to avoid flickering
              child: frame != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        // Add video play icon overlay for local videos
                        const Center(
                          child: Icon(
                            remix.Remix.play_circle_line,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: widget.width,
                      height: widget.height,
                      child: widget.fallbackBuilder()),
            );
          },
        ),
      ),
    );
  }
}
