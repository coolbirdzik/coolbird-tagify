import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:path/path.dart' as pathlib;
import 'dart:math';
import 'package:share_plus/share_plus.dart'; // Add import for Share Plus
// Add import for XFile
import 'package:cb_file_manager/helpers/folder_sort_manager.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';

class ImageGalleryScreen extends StatefulWidget {
  final String path;
  final bool recursive;

  const ImageGalleryScreen({
    Key? key,
    required this.path,
    this.recursive = true,
  }) : super(key: key);

  @override
  ImageGalleryScreenState createState() => ImageGalleryScreenState();
}

class ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late Future<List<File>> _imageFilesFuture;
  late UserPreferences _preferences;
  late double _thumbnailSize = 150.0; // Default size

  List<File> _imageFiles = [];
  Map<String, List<String>> _fileTagsMap = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};
  SortOption _currentSortOption = SortOption.nameAsc;
  ViewMode _viewMode = ViewMode.grid;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences.instance;
    _loadPreferences();
    _loadImages();
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

  Future<void> _loadImages() async {
    _imageFilesFuture = getAllImages(widget.path, recursive: widget.recursive);
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
          _sortImageFiles();
        });
      }
    });
  }

  void _sortImageFiles() {
    switch (_currentSortOption) {
      case SortOption.nameAsc:
        _imageFiles.sort((a, b) => pathlib
            .basename(a.path)
            .toLowerCase()
            .compareTo(pathlib.basename(b.path).toLowerCase()));
        break;

      case SortOption.nameDesc:
        _imageFiles.sort((a, b) => pathlib
            .basename(b.path)
            .toLowerCase()
            .compareTo(pathlib.basename(a.path).toLowerCase()));
        break;

      case SortOption.dateAsc:
        _imageFiles.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.dateDesc:
        _imageFiles.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeAsc:
        _imageFiles.sort((a, b) {
          try {
            return a.lengthSync().compareTo(b.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeDesc:
        _imageFiles.sort((a, b) {
          try {
            return b.lengthSync().compareTo(a.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.typeAsc:
        _imageFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.typeDesc:
        _imageFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.dateCreatedAsc:
        _imageFiles.sort((a, b) {
          try {
            // On Windows, changed means creation time
            if (Platform.isWindows) {
              final aStats = FileStat.statSync(a.path);
              final bStats = FileStat.statSync(b.path);
              return aStats.changed.compareTo(bStats.changed);
            } else {
              // On other platforms, fallback to modified time
              return a.lastModifiedSync().compareTo(b.lastModifiedSync());
            }
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.dateCreatedDesc:
        _imageFiles.sort((a, b) {
          try {
            // On Windows, changed means creation time
            if (Platform.isWindows) {
              final aStats = FileStat.statSync(a.path);
              final bStats = FileStat.statSync(b.path);
              return bStats.changed.compareTo(aStats.changed);
            } else {
              // On other platforms, fallback to modified time
              return b.lastModifiedSync().compareTo(a.lastModifiedSync());
            }
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.extensionAsc:
        _imageFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.extensionDesc:
        _imageFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.attributesAsc:
        _imageFiles.sort((a, b) {
          try {
            final aStats = FileStat.statSync(a.path);
            final bStats = FileStat.statSync(b.path);
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return aAttrs.compareTo(bAttrs);
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.attributesDesc:
        _imageFiles.sort((a, b) {
          try {
            final aStats = FileStat.statSync(a.path);
            final bStats = FileStat.statSync(b.path);
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return bAttrs.compareTo(aAttrs);
          } catch (e) {
            return 0;
          }
        });
        break;
    }
  }

  void _setSortOption(SortOption option) async {
    if (_currentSortOption != option) {
      setState(() {
        _currentSortOption = option;
        _sortImageFiles();
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
              Navigator.of(context).pop();
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

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

    List<Widget> actions = SharedActionBar.buildCommonActions(
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
    );

    return BaseScreen(
      title: 'Image Gallery: ${pathlib.basename(widget.path)}',
      actions: actions,
      body: _buildImageContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isSelectionMode = true;
          });
        },
        child: const Icon(Icons.checklist),
      ),
    );
  }

  Widget _buildImageContent() {
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
        if (_searchQuery != null && _searchQuery!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Text('Tìm kiếm: "$_searchQuery"'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _searchQuery = null;
                        _loadImages();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: _searchQuery != null ? 50.0 : 0.0),
          child:
              _viewMode == ViewMode.grid ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _thumbnailSize.round(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) {
        final file = _imageFiles[index];
        final isSelected = _selectedFilePaths.contains(file.path);
        final tags = _fileTagsMap[file.path] ?? []; // Get tags for the file

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedFilePaths.remove(file.path);
                } else {
                  _selectedFilePaths.add(file.path);
                }
              });
            } else {
              // Use our enhanced ImageViewerScreen with all files
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
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedFilePaths.add(file.path);
              });
            }
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.grey[200],
                  child: Hero(
                    tag: file.path,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Add the tags overlay here
              if (tags.isNotEmpty)
                _buildTagsOverlay(tags, _thumbnailSize.round()),
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.blue : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagsOverlay(List<String> tags, int gridSize) {
    if (tags.isEmpty) return const SizedBox.shrink();

    // Determine compactness and number of tags based on grid size
    bool verySmallGrid = gridSize >= 5;
    bool smallGrid = gridSize == 4;
    bool mediumGrid = gridSize == 3;
    bool largeGrid = gridSize <= 2;

    List<Widget> tagWidgets = [];
    int maxTagsToShow = 1;
    bool useCompactChips = true;

    if (largeGrid) {
      maxTagsToShow = 3;
      useCompactChips = false;
    } else if (mediumGrid) {
      maxTagsToShow = 2;
      useCompactChips = true;
    } else if (smallGrid) {
      maxTagsToShow = 1;
      useCompactChips = true;
    } else if (verySmallGrid) {
      // Only show icon and count for very small items
      return Positioned(
        bottom: 4,
        left: 4,
        right: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.label_outline, color: Colors.white, size: 12),
              const SizedBox(width: 2),
              Text(
                '${tags.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    for (int i = 0; i < tags.length && i < maxTagsToShow; i++) {
      tagWidgets.add(TagChip(
          tag: tags[i],
          isCompact: useCompactChips,
          onTap: () {
            // Optional: Handle tag tap, e.g., search by tag
            // final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
            // bloc.add(SearchByTag(tags[i]));
          }));
    }

    if (tags.length > maxTagsToShow) {
      tagWidgets.add(Text(
        '+${tags.length - maxTagsToShow}',
        style:
            TextStyle(color: Colors.white, fontSize: useCompactChips ? 10 : 12),
      ));
    }

    return Positioned(
      bottom: 5,
      left: 5,
      right: 5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          alignment: WrapAlignment.start,
          children: tagWidgets,
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) {
        final file = _imageFiles[index];
        final isSelected = _selectedFilePaths.contains(file.path);
        final fileExtension = pathlib.extension(file.path).toLowerCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            title: Text(
              pathlib.basename(file.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: FutureBuilder<FileStat>(
              future: file.stat(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.loading,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.loading,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(snapshot.error.toString()),
                      ],
                    ),
                  );
                }

                final fileStat = snapshot.data!;
                final fileSize = _formatFileSize(fileStat.size);
                final fileDate = _formatDate(fileStat.modified);
                return Text('$fileExtension • $fileSize • $fileDate');
              },
            ),
            selected: isSelected,
            trailing: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFilePaths.add(file.path);
                        } else {
                          _selectedFilePaths.remove(file.path);
                        }
                      });
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showImageOptions(context, file),
                  ),
            onTap: _isSelectionMode
                ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedFilePaths.remove(file.path);
                      } else {
                        _selectedFilePaths.add(file.path);
                      }
                    });
                  }
                : () {
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
                  },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedFilePaths.add(file.path);
                });
              }
            },
          ),
        );
      },
    );
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
                  Navigator.of(context).pop();
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
              Navigator.of(context).pop();
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
