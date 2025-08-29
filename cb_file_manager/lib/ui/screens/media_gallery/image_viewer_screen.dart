import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as pathlib;
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
import 'package:cb_file_manager/ui/components/thumbnail_strip.dart';
import 'package:cb_file_manager/helpers/files/trash_manager.dart';
import 'package:share_plus/share_plus.dart'; // Add import for Share Plus
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
// Add import for XFile
import '../../utils/route.dart';

class ImageViewerScreen extends StatefulWidget {
  final File file;
  final List<File>? imageFiles; // Optional list of all images in the folder
  final int initialIndex; // When provided with imageFiles, start at this index

  const ImageViewerScreen({
    Key? key,
    required this.file,
    this.imageFiles,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  late List<File> _allImages;
  int _currentIndex = 0;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  bool _showThumbnailStrip =
      true; // Biến để kiểm soát việc hiển thị thanh thumbnail
  double _rotation = 0.0;
  double _brightness = 0.0;
  double _contrast = 0.0;
  bool _isEditMode = false;

  // Thêm map để cache dữ liệu ảnh đã tải
  final Map<String, Uint8List> _imageCache = {};
  // Biến để theo dõi ảnh đang tải
  final Set<String> _loadingImages = {};
  // Kích thước tối đa của cache (số lượng ảnh)
  final int _maxCacheSize = 5;

  final double _minScale = 0.5;
  final double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _initImageList();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });

    // Tiền tải ảnh hiện tại và các ảnh hàng xóm
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchNeighboringImages();
    });

    // Apply frame timing optimization for better performance
    FrameTimingOptimizer().optimizeImageRendering();

    // Ensure status bar is hidden in fullscreen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom]);
  }

  void _initImageList() {
    if (widget.imageFiles != null) {
      _allImages = List.from(widget.imageFiles!);
      _currentIndex = widget.initialIndex;
    } else {
      _allImages = [widget.file];
      _currentIndex = 0;
    }

    _pageController = PageController(initialPage: _currentIndex);

    // Load image list from directory if not provided
    if (widget.imageFiles == null) {
      _loadImagesFromDirectory();
    }
  }

  Future<void> _loadImagesFromDirectory() async {
    try {
      final directory = Directory(pathlib.dirname(widget.file.path));
      if (await directory.exists()) {
        final entities = await directory.list().toList();

        final images = entities.whereType<File>().where((file) {
          return FileTypeUtils.isImageFile(file.path);
        }).toList();

        // Sort images by name
        images.sort((a, b) => pathlib
            .basename(a.path)
            .toLowerCase()
            .compareTo(pathlib.basename(b.path).toLowerCase()));

        // Find current image index based on absolute path comparison
        final currentPath = widget.file.path;
        final index = images.indexWhere(
            (file) => file.path == currentPath // Exact path matching
            );

        if (mounted) {
          setState(() {
            // Only update the list if we found images
            if (images.isNotEmpty) {
              _allImages = images;

              // Make sure the current image is in the list and index is valid
              if (index >= 0) {
                _currentIndex = index;
                // Dispose old controller before creating new one
                _pageController.dispose();
                _pageController = PageController(initialPage: _currentIndex);

                // Clear cache to avoid any mismatch
                _imageCache.clear();

                // Pre-load current image
                _loadAndCacheImage(images[_currentIndex]);
              } else {
                // If we somehow can't find the image in the directory
                // Just use the original file passed in constructor
                debugPrint(
                    'Warning: Could not find current image in directory. Path: $currentPath');
                _allImages = [widget.file];
                _currentIndex = 0;
                _pageController.dispose();
                _pageController = PageController(initialPage: 0);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading images from directory: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_animationController.isAnimating) return;

    if (_transformationController.value != Matrix4.identity()) {
      // Reset to identity if already zoomed in
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    } else {
      // Zoom in around tap point
      final position = details.localPosition;

      // Calculate the focal point for zooming (centered on the tap position)
      const double scale = 2.5;

      // Create a transformation matrix that zooms to a scale of 2.5x
      // centered on the position that was double-tapped
      final Matrix4 zoomed = Matrix4.identity()
        ..translate(position.dx, position.dy)
        ..scale(scale)
        ..translate(-position.dx, -position.dy);

      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: zoomed,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    }

    _animationController.forward(from: 0);
  }

  void _resetTransformation() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward(from: 0);
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      }
    });
  }

  void _rotateImage() {
    setState(() {
      _rotation += 90.0;
      if (_rotation >= 360.0) {
        _rotation = 0.0;
      }
    });
    _resetTransformation();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        // Reset adjustments when exiting edit mode
        _brightness = 0.0;
        _contrast = 0.0;
      }
    });
  }

  void _toggleThumbnailStrip() {
    setState(() {
      _showThumbnailStrip = !_showThumbnailStrip;
    });
  }

  void _showImageInfo(BuildContext context, File file) async {
    try {
      final fileStat = await file.stat();
      final fileSize = _formatFileSize(fileStat.size);
      final modified = fileStat.modified;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Image Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('File name', pathlib.basename(file.path)),
                  const Divider(),
                  _infoRow('Path', file.path),
                  const Divider(),
                  _infoRow('Size', fileSize),
                  const Divider(),
                  _infoRow('Type', pathlib.extension(file.path).toUpperCase()),
                  const Divider(),
                  _infoRow('Last modified',
                      '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  RouteUtils.safePopDialog(context);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing image info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to display image information: $e')),
      );
    }
  }

  Future<void> _deleteImage(BuildContext context) async {
    final file = _allImages[_currentIndex];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text(
            'Are you sure you want to move "${pathlib.basename(file.path)}" to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('MOVE TO TRASH',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Use TrashManager instead of directly deleting
        final success = await TrashManager().moveToTrash(file.path);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image moved to trash')),
          );

          setState(() {
            _allImages.removeAt(_currentIndex);
            if (_allImages.isEmpty) {
              // No more images to show, return to previous screen
              RouteUtils.safePopDialog(context);
            } else {
              // Adjust current index if needed
              if (_currentIndex >= _allImages.length) {
                _currentIndex = _allImages.length - 1;
              }
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to move image to trash')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move image to trash: $e')),
        );
      }
    }
  }

  void _shareImage() {
    final file = _allImages[_currentIndex];
    final XFile xFile = XFile(file.path);
    Share.shareXFiles([xFile], text: 'Check out this image!');
  }

  // Phương thức để tải và cache ảnh
  Future<Uint8List?> _loadAndCacheImage(File file) async {
    final path = file.path;

    // Nếu đang tải, chờ đợi và không thực hiện tải lại
    if (_loadingImages.contains(path)) {
      // Chờ đợi cho đến khi ảnh được tải và cache
      int attempts = 0;
      while (_loadingImages.contains(path) && attempts < 100) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
      }
      return _imageCache[path];
    }

    // Nếu đã có trong cache, trả về ngay
    if (_imageCache.containsKey(path)) {
      return _imageCache[path];
    }

    // Bắt đầu tải ảnh
    _loadingImages.add(path);

    try {
      // Đọc dữ liệu ảnh
      final bytes = await file.readAsBytes();

      // Lưu vào cache
      _imageCache[path] = bytes;

      // Quản lý kích thước cache - xóa mục cũ nhất nếu vượt giới hạn
      if (_imageCache.length > _maxCacheSize) {
        final oldest = _imageCache.keys.first;
        _imageCache.remove(oldest);
      }

      return bytes;
    } catch (e) {
      debugPrint('Error loading image $path: $e');
      return null;
    } finally {
      _loadingImages.remove(path);
    }
  }

  // Phương thức tiền tải ảnh hàng xóm
  void _prefetchNeighboringImages() {
    if (_allImages.length <= 1) return;

    // Tải ảnh hiện tại nếu chưa được tải
    _loadAndCacheImage(_allImages[_currentIndex]);

    // Tải ảnh tiếp theo nếu có
    if (_currentIndex < _allImages.length - 1) {
      _loadAndCacheImage(_allImages[_currentIndex + 1]);
    }

    // Tải ảnh trước đó nếu có
    if (_currentIndex > 0) {
      _loadAndCacheImage(_allImages[_currentIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allImages.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No images to display'),
        ),
      );
    }

    // If in normal viewing mode (not editing)
    if (!_isEditMode) {
      return RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            // Handle escape key press to exit the image viewer
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              RouteUtils.safePopDialog(context);
              return;
            }

            // Handle left arrow key press
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                _currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            // Handle right arrow key press
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                _currentIndex < _allImages.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _controlsVisible
              ? AppBar(
                  backgroundColor: Colors.black.withAlpha(179),
                  title: Text(pathlib.basename(_allImages[_currentIndex].path)),
                  elevation: 0,
                  actions: [
                    // Nút để bật/tắt thanh thumbnail
                    IconButton(
                      icon: Icon(
                        _showThumbnailStrip
                            ? EvaIcons.gridOutline
                            : EvaIcons.grid,
                        size: 22,
                      ),
                      tooltip: _showThumbnailStrip
                          ? 'Hide thumbnails'
                          : 'Show thumbnails',
                      onPressed: _toggleThumbnailStrip,
                    ),
                    // Nút chỉnh sửa ảnh
                    IconButton(
                      icon: const Icon(EvaIcons.editOutline, size: 22),
                      tooltip: 'Edit image',
                      onPressed: _toggleEditMode,
                    ),
                  ],
                )
              : null,
          extendBodyBehindAppBar: true,
          body: Listener(
            onPointerDown: (PointerDownEvent event) {
              // Mouse button 4 is usually the back button (button value is 8)
              if (event.buttons == 8 && _currentIndex > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              // Mouse button 5 is usually the forward button (button value is 16)
              else if (event.buttons == 16 &&
                  _currentIndex < _allImages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Column(
              children: [
                // Main image viewer
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleControls,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _allImages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          // Reset transformation when changing pages
                          _transformationController.value = Matrix4.identity();
                          _rotation = 0.0;
                        });
                        // Tiền tải ảnh kế tiếp và trước đó khi người dùng chuyển ảnh
                        _prefetchNeighboringImages();
                      },
                      itemBuilder: (context, index) {
                        final file = _allImages[index];
                        return Center(
                          child: GestureDetector(
                            onDoubleTapDown: _handleDoubleTap,
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              clipBehavior: Clip
                                  .none, // Allow content to overflow its bounds when zoomed
                              constrained:
                                  false, // Allow content to be larger than the viewport
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height,
                                alignment: Alignment.center,
                                child: Hero(
                                  tag: file.path,
                                  child: Transform.rotate(
                                    angle: _rotation * pi / 180,
                                    child: RepaintBoundary(
                                      child: FutureBuilder<Uint8List?>(
                                        future: _loadAndCacheImage(file),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            // Show loading indicator while image is being loaded
                                            return const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(
                                                    color: Colors.white70,
                                                  ),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'Loading image...',
                                                    style: TextStyle(
                                                        color: Colors.white70),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            // Show error if image loading failed
                                            return Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 80,
                                                  color: Colors.white
                                                      .withAlpha(179),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Failed to load image',
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withAlpha(179)),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  snapshot.error.toString(),
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withAlpha(128),
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            );
                                          } else if (snapshot.hasData) {
                                            // Image loaded successfully, display it
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.high,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image,
                                                      size: 80,
                                                      color: Colors.white
                                                          .withAlpha(179),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Failed to decode image',
                                                      style: TextStyle(
                                                          color: Colors.white
                                                              .withAlpha(179)),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          } else {
                                            // No data and no error
                                            return const Center(
                                              child: Text(
                                                'No image data',
                                                style: TextStyle(
                                                    color: Colors.white70),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Thumbnail strip at the bottom
                if (_controlsVisible &&
                    _showThumbnailStrip &&
                    _allImages.length > 1)
                  Container(
                    height: 70,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(179),
                      border: const Border(
                        top: BorderSide(
                          color: Colors.white24,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ThumbnailStrip(
                      images: _allImages,
                      currentIndex: _currentIndex,
                      onThumbnailTap: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: _controlsVisible
              ? BottomAppBar(
                  color: Colors.black.withAlpha(179),
                  height: 48, // Giảm chiều cao để gọn hơn
                  padding: EdgeInsets.zero, // Loại bỏ padding mặc định
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(EvaIcons.refreshOutline, size: 22),
                        tooltip: 'Rotate',
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        constraints:
                            const BoxConstraints(), // Loại bỏ kích thước tối thiểu
                        onPressed: _rotateImage,
                      ),
                      IconButton(
                        icon: const Icon(EvaIcons.shareOutline, size: 22),
                        tooltip: 'Share',
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: _shareImage,
                      ),
                      IconButton(
                        icon: const Icon(EvaIcons.trashOutline, size: 22),
                        tooltip: 'Delete',
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () => _deleteImage(context),
                      ),
                      IconButton(
                        icon: const Icon(EvaIcons.infoOutline, size: 22),
                        tooltip: 'Info',
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            _showImageInfo(context, _allImages[_currentIndex]),
                      ),
                      // Thêm nút chuyển chế độ toàn màn hình
                      IconButton(
                        icon: Icon(
                          _isFullscreen ? EvaIcons.minimize : EvaIcons.maximize,
                          size: 22,
                        ),
                        tooltip:
                            _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _controlsVisible && _allImages.length > 1
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0),
                      child: FloatingActionButton(
                        heroTag: "prevBtn",
                        backgroundColor: Colors.black.withAlpha(179),
                        mini: true,
                        onPressed: _currentIndex > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        child: Icon(
                          EvaIcons.arrowIosBack,
                          color: _currentIndex > 0 ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 24.0),
                      child: FloatingActionButton(
                        heroTag: "nextBtn",
                        backgroundColor: Colors.black.withAlpha(179),
                        mini: true,
                        onPressed: _currentIndex < _allImages.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        child: Icon(
                          EvaIcons.arrowIosForward,
                          color: _currentIndex < _allImages.length - 1
                              ? Colors.white
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      );
    } else {
      // Edit mode UI with sliders for adjustments
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withAlpha(179),
          title: const Text('Edit Image'),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _toggleEditMode,
              child: const Text('DONE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(
                    _calculateColorMatrix(_brightness, _contrast),
                  ),
                  child: FutureBuilder<Uint8List?>(
                    future: _loadAndCacheImage(_allImages[_currentIndex]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // Show loading indicator
                        return const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading image for editing...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      } else if (snapshot.hasError) {
                        // Show error
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 80,
                              color: Colors.white.withAlpha(179),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style:
                                  TextStyle(color: Colors.white.withAlpha(179)),
                            ),
                          ],
                        );
                      } else if (snapshot.hasData) {
                        // Show image with effects
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        );
                      } else {
                        // No data
                        return const Center(
                          child: Text(
                            'No image data',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.black.withAlpha(179),
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brightness slider
                  Row(
                    children: [
                      const Icon(EvaIcons.sun, color: Colors.white, size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: -1.0,
                          max: 1.0,
                          divisions: 20,
                          label: 'Brightness: ${(_brightness * 100).round()}%',
                          onChanged: (value) {
                            setState(() {
                              _brightness = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Contrast slider
                  Row(
                    children: [
                      const Icon(EvaIcons.colorPaletteOutline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          min: -1.0,
                          max: 1.0,
                          divisions: 20,
                          label: 'Contrast: ${(_contrast * 100).round()}%',
                          onChanged: (value) {
                            setState(() {
                              _contrast = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _brightness = 0.0;
                            _contrast = 0.0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(100, 36),
                        ),
                        icon: const Icon(EvaIcons.refreshOutline, size: 18),
                        label: const Text('Reset'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement save functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Save feature will be implemented soon'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(100, 36),
                        ),
                        icon: const Icon(EvaIcons.saveOutline, size: 18),
                        label: const Text('Save Copy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // Helper method to calculate color matrix for brightness and contrast adjustments
  List<double> _calculateColorMatrix(double brightness, double contrast) {
    final double b = brightness;
    final double c = contrast + 1.0;

    // This matrix applies both brightness and contrast adjustments
    return [
      c,
      0,
      0,
      0,
      b * 255,
      0,
      c,
      0,
      0,
      b * 255,
      0,
      0,
      c,
      0,
      b * 255,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
