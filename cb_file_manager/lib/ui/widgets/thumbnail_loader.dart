import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/network/network_thumbnail_helper.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:cb_file_manager/ui/components/common/skeleton.dart';
import 'package:remixicon/remixicon.dart' as remix;

/// Memory pool để tái sử dụng image objects và giảm memory fragmentation
class ImageMemoryPool {
  static final Map<String, ui.Image> _imagePool = {};
  static final Map<String, DateTime> _lastUsed = {};
  static const int maxPoolSize = 50;
  static const Duration maxAge = Duration(minutes: 5);

  static void putImage(String key, ui.Image image) {
    _cleanupOldImages();
    if (_imagePool.length >= maxPoolSize) {
      _evictOldest();
    }
    _imagePool[key] = image;
    _lastUsed[key] = DateTime.now();
  }

  static ui.Image? getImage(String key) {
    final image = _imagePool[key];
    if (image != null) {
      _lastUsed[key] = DateTime.now();
    }
    return image;
  }

  static void _cleanupOldImages() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _lastUsed.forEach((key, lastUsed) {
      if (now.difference(lastUsed) > maxAge) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _imagePool[key]?.dispose();
      _imagePool.remove(key);
      _lastUsed.remove(key);
    }
  }

  static void _evictOldest() {
    if (_lastUsed.isEmpty) return;

    final oldest =
        _lastUsed.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b);

    _imagePool[oldest.key]?.dispose();
    _imagePool.remove(oldest.key);
    _lastUsed.remove(oldest.key);
  }

  static void clear() {
    _imagePool.values.forEach((image) => image.dispose());
    _imagePool.clear();
    _lastUsed.clear();
  }
}

/// A global thumbnail cache to avoid regenerating thumbnails
class ThumbnailWidgetCache {
  static final ThumbnailWidgetCache _instance =
      ThumbnailWidgetCache._internal();
  factory ThumbnailWidgetCache() => _instance;
  ThumbnailWidgetCache._internal();

  final Map<String, Widget> _thumbnailWidgets = {};
  final Map<String, String> _thumbnailPaths =
      {}; // Cache for thumbnail file paths
  final Map<String, DateTime> _lastAccessTime = {};
  final Set<String> _generatingThumbnails = {};

  // Stream controller to notify widgets when new thumbnails are available
  final StreamController<String> _thumbnailReadyController =
      StreamController<String>.broadcast();
  Stream<String> get onThumbnailReady => _thumbnailReadyController.stream;

  // Stream controller to notify when all thumbnails are loaded
  static final StreamController<bool> _allThumbnailsLoadedController =
      StreamController<bool>.broadcast();
  static Stream<bool> get onAllThumbnailsLoaded =>
      _allThumbnailsLoadedController.stream;

  // PERFORMANCE: Further reduced cache sizes for better memory management
  static const int _maxCacheSize = 150; // Further reduced from 200 for desktop
  static const Duration _cacheRetentionTime = Duration(
    minutes: 15, // Reduced from 30 minutes
  );

  Widget? getCachedThumbnailWidget(String path) {
    final widget = _thumbnailWidgets[path];
    if (widget != null) {
      _lastAccessTime[path] = DateTime.now();
    }
    return widget;
  }

  void cacheWidgetThumbnail(String path, Widget thumbnailWidget) {
    _thumbnailWidgets[path] = thumbnailWidget;
    _lastAccessTime[path] = DateTime.now();
    _cleanupCacheIfNeeded();
  }

  String? getCachedThumbnailPath(String path) {
    final thumbnailPath = _thumbnailPaths[path];
    if (thumbnailPath != null) {
      _lastAccessTime[path] = DateTime.now();
    }
    return thumbnailPath;
  }

  void cacheThumbnailPath(String path, String thumbnailPath) {
    _thumbnailPaths[path] = thumbnailPath;
    _lastAccessTime[path] = DateTime.now();
    _cleanupCacheIfNeeded();

    // Notify all listening widgets that a new thumbnail is ready
    _thumbnailReadyController.add(path);
  }

  bool isGeneratingThumbnail(String path) =>
      _generatingThumbnails.contains(path);
  void markGeneratingThumbnail(String path) => _generatingThumbnails.add(path);
  void markThumbnailGenerated(String path) {
    _generatingThumbnails.remove(path);

    // If no more thumbnails are being generated, notify listeners
    if (_generatingThumbnails.isEmpty &&
        ThumbnailLoader.pendingThumbnailCount == 0) {
      _allThumbnailsLoadedController.add(true);
    }
  }

  void clearCache() {
    _thumbnailWidgets.clear();
    _thumbnailPaths.clear();
    _lastAccessTime.clear();
    _generatingThumbnails.clear();
  }

  void dispose() {
    _thumbnailReadyController.close();
    _allThumbnailsLoadedController.close();
    clearCache();
    debugPrint('ThumbnailWidgetCache: Disposed resources');
  }

  void _cleanupCacheIfNeeded() {
    if (_thumbnailWidgets.length > _maxCacheSize) {
      // Sort by last access time (oldest first)
      final sortedEntries = _lastAccessTime.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      // Remove oldest entries until we're below the limit
      final entriesToRemove = sortedEntries.take((_maxCacheSize * 0.2).round());
      for (final entry in entriesToRemove) {
        _thumbnailWidgets.remove(entry.key);
        _lastAccessTime.remove(entry.key);
      }
    }
  }

  // Clean up entries that haven't been accessed for a while
  void cleanupStaleEntries() {
    final now = DateTime.now();
    final stalePaths = _lastAccessTime.entries
        .where((entry) => now.difference(entry.value) > _cacheRetentionTime)
        .map((entry) => entry.key)
        .toList();

    for (final path in stalePaths) {
      _thumbnailWidgets.remove(path);
      _thumbnailPaths.remove(path);
      _lastAccessTime.remove(path);
    }
  }

  // Check if any thumbnails are still being generated
  bool get isAnyThumbnailGenerating =>
      _generatingThumbnails.isNotEmpty ||
      ThumbnailLoader.pendingThumbnailCount > 0;
}

/// A widget that displays thumbnails for images and videos with loading indicators
class ThumbnailLoader extends StatefulWidget {
  final String filePath;
  final bool isVideo;
  final bool isImage;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showLoadingIndicator;
  final Widget Function()? fallbackBuilder;
  final VoidCallback? onThumbnailLoaded;
  final BorderRadius? borderRadius;
  final bool isPriority;

  // Static counter to track pending thumbnail generation tasks
  static int pendingThumbnailCount = 0;

  // Stream controller to notify when background tasks change
  static final StreamController<int> _pendingTasksController =
      StreamController<int>.broadcast();
  static Stream<int> get onPendingTasksChanged =>
      _pendingTasksController.stream;

  // Method to check if any background tasks are still running
  static bool get hasBackgroundTasks =>
      pendingThumbnailCount > 0 ||
      ThumbnailWidgetCache()._generatingThumbnails.isNotEmpty;

  // Method to reset pending thumbnail count
  static void resetPendingCount() {
    if (pendingThumbnailCount > 0) {
      pendingThumbnailCount = 0;
      _pendingTasksController.add(0);
    }
  }

  // Method to force reset pending count (for debugging and edge cases)
  static void forceResetPendingCount() {
    pendingThumbnailCount = 0;
    _pendingTasksController.add(0);
  }

  // Method to clean up static resources
  static void disposeStatic() {
    _pendingTasksController.close();
    ThumbnailWidgetCache._allThumbnailsLoadedController.close();
    debugPrint('ThumbnailLoader: Disposed static resources');
  }

  // Static method to reset failed attempts (useful for network reconnection)
  static void resetFailedAttempts() {
    _ThumbnailLoaderState._failedAttempts.clear();
    _ThumbnailLoaderState._lastAttemptTime.clear();
  }

  const ThumbnailLoader({
    Key? key,
    required this.filePath,
    required this.isVideo,
    required this.isImage,
    this.width = double.infinity,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
    this.showLoadingIndicator = true,
    this.fallbackBuilder,
    this.onThumbnailLoaded,
    this.borderRadius,
    this.isPriority = false,
  }) : super(key: key);

  @override
  State<ThumbnailLoader> createState() => _ThumbnailLoaderState();
}

class _ThumbnailLoaderState extends State<ThumbnailLoader>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ThumbnailWidgetCache _cache = ThumbnailWidgetCache();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier<bool>(false);
  StreamSubscription? _cacheChangedSubscription;
  StreamSubscription? _thumbnailReadySubscription;
  bool _widgetMounted = true;
  Timer? _loadTimer;
  Timer? _delayedLoadTimer;
  Timer? _refreshTimer;
  Timer? _visibilityDebounceTimer;
  String? _networkThumbnailPath; // Store the generated thumbnail path

  // PERFORMANCE: Reduced debounce timing for better responsiveness during scrolling
  static const Duration _visibilityDebounceDuration = Duration(
      milliseconds: 150); // Reduced from 300ms for faster thumbnail loading

  // PERFORMANCE: Adaptive filter quality based on scrolling state
  bool _isScrolling = false;
  Timer? _scrollStopTimer;
  static const Duration _scrollStopDelay = Duration(milliseconds: 150);

  // Viewport-based loading priority system
  static final List<String> _loadingQueue = [];
  static bool _isProcessingQueue = false;

  // Background processing limits
  static const int maxConcurrentLoads = 3;
  static int _currentLoads = 0;

  // Track failed attempts with retry limits and backoff
  static final _failedAttempts = <String, int>{};
  static final _lastAttemptTime = <String, DateTime>{};
  static const int _maxRetries = 3;
  static const Duration _retryBackoff = Duration(seconds: 2);

  // Limit how many thumbnails can be loaded at once per screen
  static int _activeLoaders = 0;
  static const int _maxActiveLoaders =
      6; // Giới hạn loader đồng thời để giảm drop frame

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _widgetMounted = true;
    WidgetsBinding.instance.addObserver(this);

    // Listen for cache changes
    _cacheChangedSubscription = VideoThumbnailHelper.onCacheChanged.listen((_) {
      if (_widgetMounted) {
        // Reset cache and force reload of thumbnails
        _cache.clearCache();
        _invalidateThumbnail();
      }
    });

    // Listen for thumbnail ready notifications
    _thumbnailReadySubscription = _cache.onThumbnailReady.listen((path) {
      if (_widgetMounted && mounted && path == widget.filePath) {
        final cachedPath = _cache.getCachedThumbnailPath(widget.filePath);
        if (cachedPath != null) {
          setState(() {
            _networkThumbnailPath = cachedPath;
          });
          _isLoadingNotifier.value = false;
          _hasErrorNotifier.value = false;

          if (widget.onThumbnailLoaded != null) {
            widget.onThumbnailLoaded!();
          }
        }
      }
    });

    // Check cache first before loading
    final cachedPath = _cache.getCachedThumbnailPath(widget.filePath);
    if (cachedPath != null) {
      _networkThumbnailPath = cachedPath;
      _isLoadingNotifier.value = false;
      _hasErrorNotifier.value = false;
    } else {
      // Không khởi tạo thumbnail ngay; chờ khi widget thực sự hiển thị (VisibilityDetector)
    }
  }

  void _scheduleLoad() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 50), () {
      // Reduced delay
      if (mounted) {
        _loadThumbnail();
      }
    });
  }

  // Smart loading với priority queue
  void _scheduleLoadWithDelay() {
    _delayedLoadTimer?.cancel();
    _delayedLoadTimer = Timer(const Duration(milliseconds: 300), () {
      if (_widgetMounted && mounted) {
        _addToLoadingQueue();
      }
    });
  }

  // Add to priority queue thay vì load ngay
  void _addToLoadingQueue() {
    if (!_loadingQueue.contains(widget.filePath)) {
      _loadingQueue.add(widget.filePath);
      _processLoadingQueue();
    }
  }

  // Process queue với concurrency limit
  static void _processLoadingQueue() {
    if (_isProcessingQueue || _currentLoads >= maxConcurrentLoads) return;
    if (_loadingQueue.isEmpty) return;

    _isProcessingQueue = true;

    // Process next item
    _loadingQueue.removeAt(0);
    _currentLoads++;

    // Find widget and trigger load
    // (Implementation would need widget registry)

    _isProcessingQueue = false;

    // Continue processing
    if (_loadingQueue.isNotEmpty && _currentLoads < maxConcurrentLoads) {
      Timer(const Duration(milliseconds: 50), _processLoadingQueue);
    }
  }

  // Cancel pending loads để tiết kiệm resources
  void _cancelPendingLoad() {
    _loadTimer?.cancel();
    _delayedLoadTimer?.cancel();
    _loadingQueue.remove(widget.filePath);
  }

  @override
  void didUpdateWidget(ThumbnailLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.isVideo != widget.isVideo ||
        oldWidget.isImage != widget.isImage) {
      _networkThumbnailPath = null; // Reset thumbnail path
      _loadThumbnail(); // Load immediately
    }
  }

  void _invalidateThumbnail() {
    _isLoadingNotifier.value = true;
    _hasErrorNotifier.value = false;
    _networkThumbnailPath = null;
    // Use a small delay to prevent multiple reloads in quick succession
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_widgetMounted && mounted) {
        _loadThumbnail();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cacheChangedSubscription?.cancel();
    _thumbnailReadySubscription?.cancel();
    _isLoadingNotifier.dispose();
    _hasErrorNotifier.dispose();
    _widgetMounted = false;
    _loadTimer?.cancel();
    _delayedLoadTimer?.cancel();
    _refreshTimer?.cancel();
    _visibilityDebounceTimer?.cancel();
    _scrollStopTimer?.cancel();

    // Clear retry tracking for this path
    _failedAttempts.remove(widget.filePath);
    _lastAttemptTime.remove(widget.filePath);

    // Cleanup memory
    _networkThumbnailPath = null;

    // Mark this path as invisible (lower priority)
    if (widget.filePath.startsWith('#network/')) {
      NetworkThumbnailHelper().markInvisible(widget.filePath);
    }

    super.dispose();
  }

  // Static method to reset failed attempts (useful for network reconnection)
  static void resetFailedAttempts() {
    _failedAttempts.clear();
    _lastAttemptTime.clear();
  }

  // Tránh tải lại thumbnail không cần thiết
  bool _shouldSkipReload(String? path, String? previousPath) {
    if (path == previousPath) return true;
    if (path == null || previousPath == null) return false;

    // Nếu đã là network path thì không reload nếu phần phía sau giống nhau
    // (tránh reload lại khi chỉ có giao thức thay đổi)
    if (path.startsWith('#network/') && previousPath.startsWith('#network/')) {
      final pathSegments = path.split('/');
      final previousSegments = previousPath.split('/');

      // Check if base paths (without protocol) match
      if (pathSegments.length > 3 && previousSegments.length > 3) {
        final basePath = pathSegments.sublist(3).join('/');
        final previousBasePath = previousSegments.sublist(3).join('/');
        if (basePath == previousBasePath) return true;
      }
    }

    return false;
  }

  void _loadThumbnail() async {
    if (!_widgetMounted) return;

    final path = widget.filePath;
    final prevPath = _networkThumbnailPath;

    if (_shouldSkipReload(path, prevPath)) {
      return; // Avoid unnecessary reloads
    }

    // Check retry limits and backoff
    final now = DateTime.now();
    final lastAttempt = _lastAttemptTime[path];
    final failedCount = _failedAttempts[path] ?? 0;

    // Skip if we've exceeded max retries
    if (failedCount >= _maxRetries) {
      _hasErrorNotifier.value = true;
      _isLoadingNotifier.value = false;
      return;
    }

    // Skip if we tried too recently (exponential backoff)
    if (lastAttempt != null) {
      final backoffDelay = Duration(
        seconds: _retryBackoff.inSeconds * (failedCount + 1),
      );
      if (now.difference(lastAttempt) < backoffDelay) {
        return;
      }
    }

    // Đánh dấu đang tải
    setState(() {
      _isLoadingNotifier.value = true;
      _hasErrorNotifier.value = false;
    });

    // Track this attempt
    _lastAttemptTime[path] = now;

    try {
      if (path.isEmpty) {
        _hasErrorNotifier.value = true;
        _failedAttempts[path] = failedCount + 1;
        return;
      }

      // First try file directly if it exists locally
      final file = File(path);
      bool fileExists = false;
      try {
        fileExists = !path.startsWith('#') && await file.exists();
      } catch (e) {
        // Ignore file access errors
      }

      String? thumbPath;

      // Priority processing for visible thumbnails
      if (path.startsWith('#network/')) {
        NetworkThumbnailHelper().markVisible(path);
      }

      if (fileExists) {
        if (widget.isVideo) {
          try {
            thumbPath = await VideoThumbnailHelper.getThumbnail(
              path,
              isPriority: true,
              forceRegenerate: false,
            );
          } catch (e) {
            // Video thumbnail generation failed
          }
        } else if (widget.isImage) {
          thumbPath = path; // Đối với local image files, dùng path trực tiếp
        }
      } else if (path.startsWith('#network/')) {
        // For network files (SMB, FTP, etc)
        final thumbnailHelper = NetworkThumbnailHelper();
        // Reduce work on mobile and limit concurrency
        final bool isMobile = Platform.isAndroid || Platform.isIOS;
        final int genSize = isMobile ? 128 : 256;
        final int limit = isMobile ? 3 : _maxActiveLoaders;
        if (_activeLoaders >= limit) {
          // Back off briefly and retry via scheduler
          await Future.delayed(const Duration(milliseconds: 120));
        }
        if (_activeLoaders >= limit) {
          _scheduleLoad();
          return;
        }
        _activeLoaders++;
        try {
          thumbPath =
              await thumbnailHelper.generateThumbnail(path, size: genSize);
        } finally {
          _activeLoaders--;
        }
      }

      if (!_widgetMounted) return;

      if (thumbPath != null) {
        // Reset failed count on success
        _failedAttempts.remove(path);
        setState(() {
          _networkThumbnailPath = thumbPath;
          _isLoadingNotifier.value = false;
        });
      } else {
        _failedAttempts[path] = failedCount + 1;
        _hasErrorNotifier.value = true;
      }
    } catch (e) {
      if (!_widgetMounted) return;
      _failedAttempts[path] = failedCount + 1;
      _hasErrorNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Gói toàn bộ nội dung bên trong VisibilityDetector để chỉ tải khi thấy trên màn hình
    return RepaintBoundary(
      child: VisibilityDetector(
        key: ValueKey('vis-${widget.filePath}'),
        onVisibilityChanged: (info) {
          if (!_widgetMounted) return;

          // PERFORMANCE: Detect scrolling for adaptive quality
          _markScrolling();

          // PERFORMANCE: Debounce visibility changes to prevent excessive operations during scrolling
          _visibilityDebounceTimer?.cancel();

          // Chỉ load khi visible fraction > 20% để tránh load quá sớm
          if (info.visibleFraction > 0.2) {
            // Debounce becoming visible to avoid loading during fast scrolling
            _visibilityDebounceTimer = Timer(_visibilityDebounceDuration, () {
              if (!_widgetMounted) return;

              // Became visible
              NetworkThumbnailHelper().markVisible(widget.filePath);

              // Nếu chưa tải thumbnail, bắt đầu tải với delay để tránh spam
              if (_networkThumbnailPath == null &&
                  !_cache.isGeneratingThumbnail(widget.filePath)) {
                _scheduleLoadWithDelay();
              }
            });
          } else if (info.visibleFraction == 0) {
            // Immediately handle becoming invisible (no debounce needed)
            NetworkThumbnailHelper().markInvisible(widget.filePath);
            _cancelPendingLoad();
          }
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          // PERFORMANCE: Consolidated ValueListenableBuilder to eliminate double rebuilds
          child: ValueListenableBuilder<bool>(
            valueListenable: _hasErrorNotifier,
            builder: (context, hasError, _) {
              if (hasError) {
                return RepaintBoundary(child: _buildFallbackWidget());
              }

              // Use a separate ValueListenableBuilder only for loading state
              // to minimize rebuilds when only loading state changes
              return ValueListenableBuilder<bool>(
                valueListenable: _isLoadingNotifier,
                builder: (context, isLoading, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main content - wrap in RepaintBoundary
                      RepaintBoundary(child: _buildThumbnailContent()),

                      // Skeleton loading overlay - static for better performance
                      if (isLoading && widget.showLoadingIndicator)
                        RepaintBoundary(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800]?.withValues(alpha: 0.8),
                              borderRadius: widget.borderRadius,
                            ),
                            child: Center(
                              child: _buildSkeletonLoader(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (widget.isVideo) {
      return _buildVideoThumbnail();
    } else if (widget.isImage) {
      return _buildImageThumbnail();
    } else {
      return _buildFallbackWidget();
    }
  }

  // PERFORMANCE: Mark that scrolling is happening and reset timer
  void _markScrolling() {
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
    }

    _scrollStopTimer?.cancel();
    _scrollStopTimer = Timer(_scrollStopDelay, () {
      if (mounted) {
        setState(() => _isScrolling = false);
      }
    });
  }

  // PERFORMANCE: Get adaptive filter quality based on scroll state
  FilterQuality _getAdaptiveFilterQuality() {
    // Use low quality during scrolling for better performance
    if (_isScrolling) {
      return FilterQuality.low;
    }

    // Use higher quality when stopped
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    return isMobile ? FilterQuality.medium : FilterQuality.high;
  }

  Widget _buildVideoThumbnail() {
    // For SMB videos, we need special handling
    if (widget.filePath.toLowerCase().startsWith('#network/smb/')) {
      // Check if we have a cached thumbnail path
      final cachedPath = _cache.getCachedThumbnailPath(widget.filePath);
      final thumbnailPath = _networkThumbnailPath ?? cachedPath;

      if (thumbnailPath != null) {
        // We have a thumbnail, display it
        // PERFORMANCE: Use adaptive filter quality based on scrolling state
        return Image.file(
          File(thumbnailPath),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: _getAdaptiveFilterQuality(),
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_widgetMounted) {
                _hasErrorNotifier.value = true;
              }
            });
            return _buildFallbackWidget();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_widgetMounted) {
                  _isLoadingNotifier.value = false;
                  if (widget.onThumbnailLoaded != null) {
                    widget.onThumbnailLoaded!();
                  }
                }
              });
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                // Add video play icon overlay
                const Center(
                  child: Icon(
                    remix.Remix.play_circle_line,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            );
          },
        );
      }

      // No thumbnail yet, try to generate one
      if (!_cache.isGeneratingThumbnail(widget.filePath)) {
        _cache.markGeneratingThumbnail(widget.filePath);
        final bool isMobile = Platform.isAndroid || Platform.isIOS;
        final int limit = isMobile ? 3 : _maxActiveLoaders;
        if (_activeLoaders >= limit) {
          _cache.markThumbnailGenerated(widget.filePath);
          _scheduleLoad();
          return _buildFallbackWidget();
        }
        _activeLoaders++;

        // Increment pending thumbnail count only when actually starting
        ThumbnailLoader.pendingThumbnailCount++;
        ThumbnailLoader._pendingTasksController.add(
          ThumbnailLoader.pendingThumbnailCount,
        );

        // Use NetworkThumbnailHelper to generate the thumbnail
        final int genSize = (Platform.isAndroid || Platform.isIOS) ? 128 : 256;
        NetworkThumbnailHelper()
            .generateThumbnail(
              widget.filePath,
              size: genSize,
            )
            .timeout(const Duration(seconds: 8)) // Longer timeout for videos
            .then((path) {
          if (_widgetMounted && path != null) {
            setState(() {
              _networkThumbnailPath = path;
              _cache.cacheThumbnailPath(widget.filePath, path);
            });
            _isLoadingNotifier.value = false;
            if (widget.onThumbnailLoaded != null) {
              widget.onThumbnailLoaded!();
            }
          } else {
            _isLoadingNotifier.value = false;
          }
          _cache.markThumbnailGenerated(widget.filePath);
          _activeLoaders--;

          // Decrement pending thumbnail count
          ThumbnailLoader.pendingThumbnailCount--;
          ThumbnailLoader._pendingTasksController.add(
            ThumbnailLoader.pendingThumbnailCount,
          );
        }).catchError((error) {
          if (_widgetMounted) {
            _isLoadingNotifier.value = false;
            _hasErrorNotifier.value = true;
          }
          _cache.markThumbnailGenerated(widget.filePath);
          _activeLoaders--;

          // Decrement pending thumbnail count
          ThumbnailLoader.pendingThumbnailCount--;
          ThumbnailLoader._pendingTasksController.add(
            ThumbnailLoader.pendingThumbnailCount,
          );
        });
      }

      // Return fallback while loading
      return _buildFallbackWidget();
    }

    // For local videos, use LazyVideoThumbnail
    return LazyVideoThumbnail(
      videoPath: widget.filePath,
      width: widget.width,
      height: widget.height,
      onThumbnailGenerated: (path) {
        if (_widgetMounted) {
          _isLoadingNotifier.value = false;
          if (widget.onThumbnailLoaded != null) {
            widget.onThumbnailLoaded!();
          }
        }
      },
      onError: (error) {
        if (_widgetMounted) {
          // Always set loading to false on error
          _isLoadingNotifier.value = false;
          _hasErrorNotifier.value = true;

          // Only log errors if they're not related to BackgroundIsolateBinaryMessenger
          if (error is! String ||
              !error.contains('BackgroundIsolateBinaryMessenger')) {}
        }
      },
      fallbackBuilder: () => _buildFallbackWidget(),
    );
  }

  Widget _buildImageThumbnail() {
    // For network files, use the generated thumbnail path if available
    if (widget.filePath.startsWith('#network/')) {
      // Check cache first
      final cachedPath = _cache.getCachedThumbnailPath(widget.filePath);
      final thumbnailPath = _networkThumbnailPath ?? cachedPath;

      if (thumbnailPath != null) {
        // Cache the path if not already cached
        if (cachedPath == null) {
          _cache.cacheThumbnailPath(widget.filePath, thumbnailPath);
        }

        // PERFORMANCE: Use adaptive filter quality based on scrolling state
        return Image.file(
          File(thumbnailPath),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: _getAdaptiveFilterQuality(),
          cacheWidth: widget.width.isInfinite ? null : widget.width.toInt(),
          cacheHeight: widget.height.isInfinite ? null : widget.height.toInt(),
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_widgetMounted) {
                _hasErrorNotifier.value = true;
              }
            });
            return _buildFallbackWidget();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_widgetMounted) {
                  _isLoadingNotifier.value = false;
                  if (widget.onThumbnailLoaded != null) {
                    widget.onThumbnailLoaded!();
                  }
                }
              });
            }
            return child;
          },
        );
      } else {
        // No thumbnail available yet, show fallback
        // Trigger thumbnail generation if not already in progress
        if (!_cache.isGeneratingThumbnail(widget.filePath)) {
          _cache.markGeneratingThumbnail(widget.filePath);
          final bool isMobile = Platform.isAndroid || Platform.isIOS;
          final int limit = isMobile ? 3 : _maxActiveLoaders;
          if (_activeLoaders >= limit) {
            _cache.markThumbnailGenerated(widget.filePath);
            _scheduleLoad();
            return _buildFallbackWidget();
          }
          _activeLoaders++;

          // Increment pending thumbnail count only when actually starting
          ThumbnailLoader.pendingThumbnailCount++;
          ThumbnailLoader._pendingTasksController.add(
            ThumbnailLoader.pendingThumbnailCount,
          );

          final int genSize =
              (Platform.isAndroid || Platform.isIOS) ? 128 : 256;
          NetworkThumbnailHelper()
              .generateThumbnail(widget.filePath, size: genSize)
              .timeout(const Duration(seconds: 6))
              .then((path) {
            if (_widgetMounted && path != null) {
              setState(() {
                _networkThumbnailPath = path;
                _cache.cacheThumbnailPath(widget.filePath, path);
              });
              _isLoadingNotifier.value = false;
              if (widget.onThumbnailLoaded != null) {
                widget.onThumbnailLoaded!();
              }
            } else {
              _isLoadingNotifier.value = false;
            }
            _cache.markThumbnailGenerated(widget.filePath);
            _activeLoaders--;

            // Decrement pending thumbnail count
            ThumbnailLoader.pendingThumbnailCount--;
            ThumbnailLoader._pendingTasksController.add(
              ThumbnailLoader.pendingThumbnailCount,
            );
          }).catchError((error) {
            // Check if this is a skip exception (backoff)
            if (error.toString().contains('ThumbnailSkippedException')) {
              // Don't update error state for skipped thumbnails
              if (_widgetMounted) {
                _isLoadingNotifier.value = false;
              }
              _cache.markThumbnailGenerated(widget.filePath);
              _activeLoaders--;

              // Decrement counter since we incremented it at the start
              ThumbnailLoader.pendingThumbnailCount--;
              ThumbnailLoader._pendingTasksController.add(
                ThumbnailLoader.pendingThumbnailCount,
              );
              return; // Don't log or update error state
            }

            if (_widgetMounted) {
              _isLoadingNotifier.value = false;
              _hasErrorNotifier.value = true;
            }
            _cache.markThumbnailGenerated(widget.filePath);
            _activeLoaders--;

            // Decrement pending thumbnail count
            ThumbnailLoader.pendingThumbnailCount--;
            ThumbnailLoader._pendingTasksController.add(
              ThumbnailLoader.pendingThumbnailCount,
            );

            // Only log errors if they're not related to BackgroundIsolateBinaryMessenger
            if (error is! String ||
                !error.contains('BackgroundIsolateBinaryMessenger')) {}
          });
        }

        return _buildFallbackWidget();
      }
    }

    // For local files, use the original logic
    // PERFORMANCE: Use adaptive filter quality based on scrolling state
    return Image.file(
      File(widget.filePath),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: _getAdaptiveFilterQuality(),
      cacheWidth: widget.width.isInfinite ? null : widget.width.toInt(),
      cacheHeight: widget.height.isInfinite ? null : widget.height.toInt(),
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_widgetMounted) {
            _hasErrorNotifier.value = true;
          }
        });
        return _buildFallbackWidget();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_widgetMounted) {
              _isLoadingNotifier.value = false;
              if (widget.onThumbnailLoaded != null) {
                widget.onThumbnailLoaded!();
              }
            }
          });
        }
        return child;
      },
    );
  }

  Widget _buildFallbackWidget() {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!();
    }

    if (widget.isVideo) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(remix.Remix.video_line, size: 36, color: Colors.red),
        ),
      );
    } else if (widget.isImage) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(remix.Remix.image_line, size: 36, color: Colors.blue),
        ),
      );
    } else {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(remix.Remix.file_3_line, size: 36, color: Colors.grey),
        ),
      );
    }
  }

  /// Build skeleton loader using unified ShimmerBox
  Widget _buildSkeletonLoader() {
    return ShimmerBox(
      width: double.infinity,
      height: double.infinity,
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
    );
  }
}
