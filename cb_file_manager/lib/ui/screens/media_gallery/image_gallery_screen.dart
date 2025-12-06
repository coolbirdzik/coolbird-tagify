import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import '../../components/common/shared_action_bar.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';

import 'package:path/path.dart' as pathlib;
import 'dart:math';
import 'package:share_plus/share_plus.dart'; // Add import for Share Plus
// Add import for XFile
import 'package:cb_file_manager/helpers/files/folder_sort_manager.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';

import 'package:cb_file_manager/services/album_service.dart';
import 'package:cb_file_manager/models/objectbox/album.dart';
import '../../utils/route.dart';
import '../../tab_manager/mobile/mobile_file_actions_controller.dart';

import 'package:cb_file_manager/helpers/core/filesystem_sorter.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/gallery_grid_view.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/gallery_list_view.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/gallery_controls.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/gallery_skeleton.dart';

class ImageGalleryScreen extends StatefulWidget {
  final String path;
  final String? directoryPath;
  final String? title;
  final bool recursive;
  final bool showAllImages;

  const ImageGalleryScreen({
    Key? key,
    this.path = '',
    this.directoryPath,
    this.title,
    this.recursive = true,
    this.showAllImages = false,
  }) : super(key: key);

  @override
  ImageGalleryScreenState createState() => ImageGalleryScreenState();
}

class ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late Future<List<File>> _imageFilesFuture;
  late UserPreferences _preferences;
  double _thumbnailSize = 3.0; // Default grid size (3 columns)
  final AlbumService _albumService = AlbumService.instance;

  List<File> _imageFiles = [];
  Map<String, List<String>> _fileTagsMap = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};
  SortOption _currentSortOption = SortOption.nameAsc;
  ViewMode _viewMode = ViewMode.grid;
  bool _isMasonry = false; // Pinterest-like layout toggle
  final Map<String, double> _imageAspectRatioCache = {}; // Cache width/height ratios
  String? _searchQuery;
  bool _isLoadingImages = true; // Track initial loading state

  // Album view mode
  bool _isAlbumView = false;
  List<Album> _albums = [];
  Album? _selectedAlbum;

  // Mobile actions controller
  MobileFileActionsController? _mobileController;
  static int _controllerIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences.instance;
    
    // Initialize mobile controller first
    final controllerId = 'image_gallery_${_controllerIdCounter++}';
    _mobileController = MobileFileActionsController.forTab(controllerId);
    
    // Register callbacks immediately (before preferences load)
    _registerMobileControllerCallbacks();
    
    // Load preferences and update controller state after
    _loadPreferences().then((_) {
      if (mounted) {
        _updateMobileControllerState();
      }
    });
    
    _loadImages();
    _loadAlbums();
  }
  
  // Register callbacks (can be called before preferences load)
  void _registerMobileControllerCallbacks() {
    if (_mobileController == null) return;
    
    // Register callbacks
    _mobileController!.onSearchSubmitted = (query) {
      setState(() {
        _searchQuery = query;
        // Just update UI, filtering happens in getter
      });
    };
    
    _mobileController!.onSortOptionSelected = (option) {
      _setSortOption(option);
    };
    
    _mobileController!.onViewModeToggled = (ViewMode mode) {
      setState(() {
        _viewMode = mode;
        _mobileController!.currentViewMode = mode;
      });
      _saveViewModeSetting(_viewMode);
    };
    
    _mobileController!.onRefresh = () {
      setState(() {
        _loadImages();
        _loadAlbums();
      });
    };
    
    _mobileController!.onGridSizePressed = () {
      SharedActionBar.showGridSizeDialog(
        context,
        currentGridSize: _thumbnailSize.round(),
        onApply: (size) async {
          setState(() {
            _thumbnailSize = size.toDouble();
          });
          // Update controller state
          _mobileController!.currentGridSize = size;
          try {
            await _preferences.setImageGalleryThumbnailSize(size.toDouble());
          } catch (e) {
            debugPrint('Error saving thumbnail size: $e');
          }
        },
      );
    };
    
    _mobileController!.onSelectionModeToggled = () {
      setState(() {
        _isSelectionMode = !_isSelectionMode;
        if (!_isSelectionMode) {
          _selectedFilePaths.clear();
        }
      });
    };

    // Masonry toggle
    _mobileController!.onMasonryToggled = () {
      setState(() {
        _isMasonry = !_isMasonry;
        _mobileController!.isMasonryLayout = _isMasonry;
      });
    };
  }
  
  // Update controller state (called after preferences load)
  void _updateMobileControllerState() {
    if (_mobileController == null) return;
    
    _mobileController!.currentSortOption = _currentSortOption;
    _mobileController!.currentViewMode = _viewMode;
    _mobileController!.currentGridSize = _thumbnailSize.round();
    _mobileController!.isMasonryLayout = _isMasonry;
  }
  
  @override
  void dispose() {
    // Cleanup controller
    if (_mobileController != null) {
      MobileFileActionsController.removeTab(_mobileController!.tabId);
    }
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (mounted) {
      final thumbnailSize = await _preferences.getImageGalleryThumbnailSize();
      final sortOption = await _preferences.getSortOption();
      final viewMode = await _preferences.getViewMode();

      setState(() {
        _thumbnailSize = thumbnailSize;
        _currentSortOption = sortOption;
        _viewMode = viewMode;
      });
    }
  }

  Future<List<File>> _getAllImagesFromCommonPaths() async {
    final List<File> allImages = [];
    final commonPaths = [
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Camera',
    ];

    for (final path in commonPaths) {
      try {
        final images = await getAllImages(path, recursive: true);
        allImages.addAll(images);
      } catch (e) {
        debugPrint('Error loading images from $path: $e');
      }
    }

    return allImages;
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoadingImages = true;
    });

    if (_isAlbumView && _selectedAlbum != null) {
      // Load images from selected album
      try {
        final albumFiles =
            await _albumService.getAlbumFiles(_selectedAlbum!.id);
        final images = albumFiles
            .map((albumFile) => File(albumFile.filePath))
            .where((file) => file.existsSync())
            .toList();

        Map<String, List<String>> tagsMap = {};
        for (var imageFile in images) {
          try {
            tagsMap[imageFile.path] = await TagManager.getTags(imageFile.path);
          } catch (e) {
            debugPrint('Error loading tags for ${imageFile.path}: $e');
            tagsMap[imageFile.path] = [];
          }
        }

        if (mounted) {
          setState(() {
            _imageFiles = images;
            _fileTagsMap = tagsMap;
            _isLoadingImages = false;
            _sortImageFiles();
          });
        }
      } catch (e) {
        debugPrint('Error loading album images: $e');
        if (mounted) {
          setState(() {
            _isLoadingImages = false;
          });
        }
      }
    } else {
      // Load images from folder
      String targetPath = widget.directoryPath ?? widget.path;

      if (widget.showAllImages) {
        // Load all images from common directories
        _imageFilesFuture = _getAllImagesFromCommonPaths();
      } else {
        _imageFilesFuture =
            getAllImages(targetPath, recursive: widget.recursive);
      }

      _imageFilesFuture.then((images) async {
        Map<String, List<String>> tagsMap = {};
        for (var imageFile in images) {
          try {
            tagsMap[imageFile.path] = await TagManager.getTags(imageFile.path);
          } catch (e) {
            debugPrint('Error loading tags for ${imageFile.path}: $e');
            tagsMap[imageFile.path] = [];
          }
        }
        if (mounted) {
          setState(() {
            _imageFiles = images;
            _fileTagsMap = tagsMap;
            _isLoadingImages = false;
            _sortImageFiles();
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isLoadingImages = false;
          });
        }
        debugPrint('Error loading images: $error');
      });
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await _albumService.getAllAlbums();
      if (mounted) {
        setState(() {
          _albums = albums;
        });
      }
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
  }

  Future<void> _sortImageFiles() async {
    // Use FileSystemSorter to sort image files
    final sortedFiles = await FileSystemSorter.sortFiles(
      _imageFiles,
      _currentSortOption,
    );
    _imageFiles = sortedFiles;
  }

  void _setSortOption(SortOption option) async {
    if (_currentSortOption != option) {
      setState(() {
        _currentSortOption = option;
      });
      await _sortImageFiles();
      setState(() {
        // Trigger rebuild after sorting
      });

      try {
        // Lưu preference toàn cục
        await _preferences.setSortOption(option);

        // Lưu cài đặt cho thư mục cụ thể
        final folderSortManager = FolderSortManager();
        bool success =
            await folderSortManager.saveFolderSortOption(widget.path, option);

        // Log kết quả
        debugPrint(
            'Saved sort option ${option.name} for folder: ${widget.path}, success: $success');
      } catch (e) {
        debugPrint('Error saving sort option: $e');
      }
    }
  }

  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  void _showSearchDialog(BuildContext context) {
    String searchQuery = _searchQuery ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm kiếm hình ảnh'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên hình ảnh...',
            prefixIcon: Icon(Icons.search),
          ),
          controller: TextEditingController(text: searchQuery),
          onChanged: (value) {
            searchQuery = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);

              if (searchQuery.trim().isEmpty) {
                setState(() {
                  _searchQuery = null;
                  _loadImages();
                });
                return;
              }

              setState(() {
                _searchQuery = searchQuery.trim();
                final searchLower = _searchQuery!.toLowerCase();

                _imageFiles = _imageFiles
                    .where((file) => pathlib
                        .basename(file.path)
                        .toLowerCase()
                        .contains(searchLower))
                    .toList();

                _sortImageFiles();
              });
            },
            child: const Text('TÌM KIẾM'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelectionMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${_selectedFilePaths.length} hình ảnh đã chọn'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedFilePaths.clear();
              });
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Xóa hình ảnh đã chọn',
              onPressed: _selectedFilePaths.isEmpty
                  ? null
                  : () => _showDeleteConfirmationDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.album),
              tooltip: 'Add to Album',
              onPressed: _selectedFilePaths.isEmpty
                  ? null
                  : () => _showAddToAlbumDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Chọn tất cả',
              onPressed: () {
                setState(() {
                  if (_selectedFilePaths.length == _imageFiles.length) {
                    _selectedFilePaths.clear();
                  } else {
                    _selectedFilePaths.addAll(_imageFiles.map((f) => f.path));
                  }
                });
              },
            ),
          ],
        ),
        body: _buildImageContent(),
      );
    }

    List<Widget> actions = [
      // Album/Folder toggle button
      IconButton(
        icon: Icon(_isAlbumView ? Icons.folder : Icons.photo_album),
        tooltip:
            _isAlbumView ? 'Switch to Folder View' : 'Switch to Album View',
        onPressed: () {
          setState(() {
            _isAlbumView = !_isAlbumView;
            _selectedAlbum = null;
            _searchQuery = null;
          });
          _loadImages();
        },
      ),
      // Album selector (only show in album view)
      if (_isAlbumView && _albums.isNotEmpty)
        PopupMenuButton<Album>(
          icon: const Icon(Icons.album),
          tooltip: 'Select Album',
          onSelected: (Album album) {
            setState(() {
              _selectedAlbum = album;
              _searchQuery = null;
            });
            _loadImages();
          },
          itemBuilder: (context) => _albums.map((album) {
            return PopupMenuItem<Album>(
              value: album,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: album.colorTheme != null
                          ? Color(int.parse(
                              album.colorTheme!.replaceFirst('#', '0xFF')))
                          : Colors.grey[300],
                    ),
                    child: album.coverImagePath != null &&
                            File(album.coverImagePath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(album.coverImagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.photo_album,
                                    size: 16, color: Colors.white);
                              },
                            ),
                          )
                        : const Icon(Icons.photo_album,
                            size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      album.name,
                      style: TextStyle(
                        fontWeight: _selectedAlbum?.id == album.id
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (_selectedAlbum?.id == album.id)
                    const Icon(Icons.check, size: 16),
                ],
              ),
            );
          }).toList(),
        ),
      ...SharedActionBar.buildCommonActions(
        context: context,
        onSearchPressed: () => _showSearchDialog(context),
        onSortOptionSelected: _setSortOption,
        currentSortOption: _currentSortOption,
        viewMode: _viewMode,
        onViewModeToggled: () {
          setState(() {
            _viewMode =
                _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
          });
          _saveViewModeSetting(_viewMode);
        },
        onRefresh: () {
          setState(() {
            _searchQuery = null;
            _loadImages();
            _loadAlbums();
          });
        },
        onGridSizePressed: () => SharedActionBar.showGridSizeDialog(
          context,
          currentGridSize: _thumbnailSize.round(),
          onApply: (size) async {
            setState(() {
              _thumbnailSize = size.toDouble();
            });

            try {
              await _preferences.setImageGalleryThumbnailSize(size.toDouble());
            } catch (e) {
              debugPrint('Error saving thumbnail size: $e');
            }
          },
        ),
        onSelectionModeToggled: () {
          setState(() {
            _isSelectionMode = true;
          });
        },
      ),
    ];

    String title;
    if (widget.title != null) {
      // Use custom title from GalleryHubScreen
      title = widget.title!;
    } else if (_isAlbumView) {
      if (_selectedAlbum != null) {
        title = 'Album: ${_selectedAlbum!.name}';
      } else {
        title = 'Albums';
      }
    } else {
      String targetPath = widget.directoryPath ?? widget.path;
      title = 'Image Gallery: ${pathlib.basename(targetPath)}';
    }

    // On mobile, use custom action bar instead of AppBar
    final isMobile = Platform.isAndroid || Platform.isIOS;
    
    return BaseScreen(
      title: title,
      actions: actions,
      showAppBar: !isMobile, // Hide AppBar on mobile
      body: isMobile 
        ? Column(
            children: [
              _buildMobileActionBar(context),
              Expanded(child: _buildImageContent()),
            ],
          )
        : _buildImageContent(),
      floatingActionButton: _isAlbumView && _albums.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCreateAlbumDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Album'),
            )
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
              child: const Icon(Icons.checklist),
            ),
    );
  }

  // Build mobile action bar using shared controller method
  Widget _buildMobileActionBar(BuildContext context) {
    if (_mobileController == null) return const SizedBox.shrink();
    return _mobileController!.buildMobileActionBar(context, viewMode: _viewMode);
  }

  Widget _buildImageContent() {
    // Show skeleton loading while data is being fetched
    if (_isLoadingImages) {
      return GallerySkeleton(
        isGrid: _viewMode == ViewMode.grid,
        thumbnailSize: _thumbnailSize,
      );
    }

    // Only show empty message after loading is complete
    if (_imageFiles.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noImagesFound,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: _searchQuery != null ? 50.0 : 0.0),
          child: _viewMode == ViewMode.grid
              ? GalleryGridView(
                  imageFiles: _imageFiles,
                  fileTagsMap: _fileTagsMap,
                  selectedFilePaths: _selectedFilePaths,
                  isSelectionMode: _isSelectionMode,
                  isMasonry: _isMasonry,
                  thumbnailSize: _thumbnailSize,
                  onTap: _onFileTap,
                  onLongPress: _onFileLongPress,
                  getAspectRatio: _getImageAspectRatio,
                )
              : GalleryListView(
                  imageFiles: _imageFiles,
                  selectedFilePaths: _selectedFilePaths,
                  isSelectionMode: _isSelectionMode,
                  onTap: _onFileTap,
                  onLongPress: _onFileLongPress,
                  onSelectionChanged: (file, selected) {
                    setState(() {
                      if (selected) {
                        _selectedFilePaths.add(file.path);
                      } else {
                        _selectedFilePaths.remove(file.path);
                      }
                    });
                  },
                ),
        ),
        GalleryControls(
          searchQuery: _searchQuery,
          onClearSearch: () {
            setState(() {
              _searchQuery = null;
              _loadImages();
            });
          },
          isMasonry: _isMasonry,
          onToggleMasonry: () => setState(() => _isMasonry = !_isMasonry),
        ),
      ],
    );
  }

  void _onFileTap(File file, int index) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedFilePaths.contains(file.path)) {
          _selectedFilePaths.remove(file.path);
        } else {
          _selectedFilePaths.add(file.path);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            file: file,
            imageFiles: _imageFiles,
            initialIndex: index,
          ),
        ),
      );
    }
  }

  void _onFileLongPress(File file) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedFilePaths.add(file.path);
      });
    }
  }

  void _showImageOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Xem hình ảnh'),
            onTap: () {
              Navigator.pop(context);
              // Find the index of the file in the image list for gallery navigation
              final index = _imageFiles.indexWhere((f) => f.path == file.path);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    file: file,
                    imageFiles: _imageFiles,
                    initialIndex: index >= 0 ? index : 0,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Thông tin hình ảnh'),
            onTap: () {
              Navigator.pop(context);
              _showImageInfoDialog(context, file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.album),
            title: const Text('Add to Album'),
            onTap: () {
              Navigator.pop(context);
              _showAddToAlbumDialog(context, [file.path]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Chia sẻ'),
            onTap: () {
              Navigator.pop(context);
              final XFile xFile = XFile(file.path);
              Share.shareXFiles([xFile], text: 'Chia sẻ hình ảnh');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title:
                const Text('Xóa hình ảnh', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmationDialog(context, [file.path]);
            },
          ),
        ],
      ),
    );
  }

  void _showImageInfoDialog(BuildContext context, File file) async {
    try {
      final fileStat = await file.stat();
      final fileSize = _formatFileSize(fileStat.size);
      final modified = fileStat.modified;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Thông tin hình ảnh'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('Tên tập tin', pathlib.basename(file.path)),
                  const Divider(),
                  _infoRow('Đường dẫn', file.path),
                  const Divider(),
                  _infoRow('Kích thước', fileSize),
                  const Divider(),
                  _infoRow(
                      'Loại tệp', pathlib.extension(file.path).toUpperCase()),
                  const Divider(),
                  _infoRow('Cập nhật lần cuối',
                      '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  RouteUtils.safePopDialog(context);
                },
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing image info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hiển thị thông tin hình ảnh: $e')),
      );
    }
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

  void _showDeleteConfirmationDialog(BuildContext context,
      [List<String>? specificPaths]) {
    final paths = specificPaths ?? _selectedFilePaths.toList();
    final count = paths.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa $count hình ảnh?'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa các hình ảnh đã chọn? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () async {
              RouteUtils.safePopDialog(context);

              int successCount = 0;
              List<String> failedPaths = [];

              for (final path in paths) {
                try {
                  final file = File(path);
                  await file.delete();
                  successCount++;
                } catch (e) {
                  debugPrint('Error deleting file $path: $e');
                  failedPaths.add(path);
                }
              }

              setState(() {
                _imageFiles.removeWhere((file) => paths.contains(file.path));
                _selectedFilePaths.clear();
                _isSelectionMode = false;
              });

              if (failedPaths.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã xóa $successCount hình ảnh')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Đã xóa $successCount hình ảnh, ${failedPaths.length} lỗi')),
                );
              }
            },
            child: const Text(
              'XÓA',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hôm nay ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hôm qua ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _showAddToAlbumDialog(BuildContext context,
      [List<String>? specificPaths]) async {
    final paths = specificPaths ?? _selectedFilePaths.toList();
    if (paths.isEmpty) return;

    try {
      final albums = await _albumService.getAllAlbums();

      if (!mounted) return;

      if (albums.isEmpty) {
        // Show dialog to create first album
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Albums Found'),
            content: const Text(
                'You need to create an album first. Would you like to go to the Album Management screen?'),
            actions: [
              TextButton(
                onPressed: () => RouteUtils.safePopDialog(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  RouteUtils.safePopDialog(context);
                  Navigator.pushNamed(context, '/albums');
                },
                child: const Text('Go to Albums'),
              ),
            ],
          ),
        );
        return;
      }

      // Show album selection dialog
      final selectedAlbum = await showDialog<Album>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              'Add ${paths.length} ${paths.length == 1 ? 'image' : 'images'} to Album'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: album.colorTheme != null
                          ? Color(int.parse(
                              album.colorTheme!.replaceFirst('#', '0xFF')))
                          : Colors.grey[300],
                    ),
                    child: album.coverImagePath != null &&
                            File(album.coverImagePath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(album.coverImagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.photo_album, size: 20);
                              },
                            ),
                          )
                        : const Icon(Icons.photo_album,
                            size: 20, color: Colors.white),
                  ),
                  title: Text(album.name),
                  subtitle: album.description != null
                      ? Text(album.description!)
                      : null,
                  onTap: () => Navigator.of(context).pop(album),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => RouteUtils.safePopDialog(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedAlbum != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Adding images to album...'),
              ],
            ),
          ),
        );

        final successCount =
            await _albumService.addFilesToAlbum(selectedAlbum.id, paths);

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          setState(() {
            _isSelectionMode = false;
            _selectedFilePaths.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Added $successCount ${successCount == 1 ? 'image' : 'images'} to "${selectedAlbum.name}"'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding images to album: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding images to album: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<double> _getImageAspectRatio(File file) async {
    final path = file.path;
    final cached = _imageAspectRatioCache[path];
    if (cached != null) return cached;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();
      final ratio = (w > 0 && h > 0) ? w / h : 1.0;
      _imageAspectRatioCache[path] = ratio;
      return ratio;
    } catch (_) {
      return 1.0;
    }
  }

  // Build skeleton loading widget


  void _showCreateAlbumDialog() {
    String albumName = '';
    String albumDescription = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Album'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Album Name',
                hintText: 'Enter album name...',
              ),
              onChanged: (value) => albumName = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter album description...',
              ),
              onChanged: (value) => albumDescription = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (albumName.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an album name')),
                );
                return;
              }

              Navigator.of(context).pop();

              try {
                final album = await _albumService.createAlbum(
                  name: albumName.trim(),
                  description: albumDescription.trim().isEmpty
                      ? null
                      : albumDescription.trim(),
                );

                if (mounted && album != null) {
                  setState(() {
                    _albums.add(album);
                    _selectedAlbum = album;
                  });
                  _loadImages();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Album "${album.name}" created successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating album: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
