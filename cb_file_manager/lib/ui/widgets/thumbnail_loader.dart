import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

/// A global thumbnail cache to avoid regenerating thumbnails
class ThumbnailWidgetCache {
  static final ThumbnailWidgetCache _instance =
      ThumbnailWidgetCache._internal();
  factory ThumbnailWidgetCache() => _instance;
  ThumbnailWidgetCache._internal();

  final Map<String, Widget> _thumbnailWidgets = {};
  final Map<String, DateTime> _lastAccessTime = {};
  final Set<String> _generatingThumbnails = {};

  static const int _maxCacheSize = 200;
  static const Duration _cacheRetentionTime = Duration(minutes: 15);

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

  bool isGeneratingThumbnail(String path) =>
      _generatingThumbnails.contains(path);
  void markGeneratingThumbnail(String path) => _generatingThumbnails.add(path);
  void markThumbnailGenerated(String path) =>
      _generatingThumbnails.remove(path);

  void clearCache() {
    _thumbnailWidgets.clear();
    _lastAccessTime.clear();
    _generatingThumbnails.clear();
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
      _lastAccessTime.remove(path);
    }
  }
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
    with AutomaticKeepAliveClientMixin {
  final ThumbnailWidgetCache _cache = ThumbnailWidgetCache();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier<bool>(false);
  StreamSubscription? _cacheChangedSubscription;
  bool _widgetMounted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _widgetMounted = true;

    // Listen for cache changes
    _cacheChangedSubscription = VideoThumbnailHelper.onCacheChanged.listen((_) {
      if (_widgetMounted) {
        // Reset cache and force reload of thumbnails
        _cache.clearCache();
        _invalidateThumbnail();
      }
    });

    // Optimize frame timing for better performance during scrolling
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_widgetMounted) {
        _loadThumbnail();
      }
    });
  }

  @override
  void didUpdateWidget(ThumbnailLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.isVideo != widget.isVideo ||
        oldWidget.isImage != widget.isImage) {
      _invalidateThumbnail();
    }
  }

  void _invalidateThumbnail() {
    _isLoadingNotifier.value = true;
    _hasErrorNotifier.value = false;
    // Use a small delay to prevent multiple reloads in quick succession
    Future.delayed(const Duration(milliseconds: 10), () {
      if (_widgetMounted) {
        _loadThumbnail();
      }
    });
  }

  @override
  void dispose() {
    _cacheChangedSubscription?.cancel();
    _isLoadingNotifier.dispose();
    _hasErrorNotifier.dispose();
    _widgetMounted = false;
    super.dispose();
  }

  void _loadThumbnail() {
    // Skip if not a previewable file
    if (!widget.isImage && !widget.isVideo) {
      _isLoadingNotifier.value = false;
      return;
    }

    // Check if already in cache
    if (_cache.isGeneratingThumbnail(widget.filePath)) {
      // Already being generated, just wait
      return;
    }

    FrameTimingOptimizer().optimizeImageRendering();

    if (widget.isImage) {
      // For images, we just need to check if the file exists
      _isLoadingNotifier.value = true;
      File(widget.filePath).exists().then((exists) {
        if (_widgetMounted) {
          _isLoadingNotifier.value = false;
          _hasErrorNotifier.value = !exists;
          if (exists && widget.onThumbnailLoaded != null) {
            widget.onThumbnailLoaded!();
          }
        }
      });
    } else if (widget.isVideo) {
      // Video thumbnails are handled by LazyVideoThumbnail
      _isLoadingNotifier.value = true;
      _hasErrorNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // For files that are neither images nor videos
    if (!widget.isImage && !widget.isVideo) {
      return _buildFallbackWidget();
    }

    final borderRadius = widget.borderRadius ?? BorderRadius.zero;

    // Wrap in try-catch to handle any rendering errors
    try {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isLoadingNotifier,
          builder: (context, isLoading, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: _hasErrorNotifier,
              builder: (context, hasError, _) {
                if (hasError) {
                  return _buildFallbackWidget();
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Main content
                    _buildThumbnailContent(),

                    // Loading indicator overlay
                    if (isLoading && widget.showLoadingIndicator)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      );
    } catch (e) {
      debugPrint(
          'ThumbnailLoader: Error rendering thumbnail for ${widget.filePath}: $e');
      return _buildFallbackWidget();
    }
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

  Widget _buildVideoThumbnail() {
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
              !error.contains('BackgroundIsolateBinaryMessenger')) {
            debugPrint(
                'ThumbnailLoader: Error generating video thumbnail for ${widget.filePath}: $error');
          }
        }
      },
      fallbackBuilder: () => _buildFallbackWidget(),
    );
  }

  Widget _buildImageThumbnail() {
    return Image.file(
      File(widget.filePath),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
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
          child: Icon(
            EvaIcons.videoOutline,
            size: 36,
            color: Colors.red,
          ),
        ),
      );
    } else if (widget.isImage) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(
            EvaIcons.imageOutline,
            size: 36,
            color: Colors.blue,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(
            EvaIcons.fileOutline,
            size: 36,
            color: Colors.grey,
          ),
        ),
      );
    }
  }
}
