import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:cb_file_manager/ui/components/video_player/video_player.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'dart:async';
import 'dart:math';
import 'package:cb_file_manager/helpers/folder_sort_manager.dart';

class VideoGalleryScreen extends StatefulWidget {
  final String path;
  final bool recursive;

  const VideoGalleryScreen({
    Key? key,
    required this.path,
    this.recursive = true,
  }) : super(key: key);

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<File>> _videoFilesFuture;
  late UserPreferences _preferences;
  late double _thumbnailSize;

  // Cải thiện ScrollController với cơ chế throttle & smooth
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollEndTimer;
  bool _isScrolling = false;

  bool _isLoadingThumbnails = false;
  bool _isMounted = false;

  // Sorting variables
  SortOption _currentSortOption = SortOption.nameAsc;
  List<File> _videoFiles = [];

  // View mode and selection variables
  ViewMode _viewMode = ViewMode.grid;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};
  String? _searchQuery;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences.instance;
    _loadPreferences();
    _loadVideos();
    _isMounted = true;

    // Lắng nghe sự kiện scroll để tối ưu hóa việc tải hình ảnh
    _scrollController.addListener(() {
      // Đánh dấu là đang cuộn
      if (!_isScrolling) {
        setState(() {
          _isScrolling = true;
        });
      }

      // Hủy timer hiện tại nếu có
      _scrollEndTimer?.cancel();

      // Tạo timer mới để biết khi nào cuộn kết thúc
      _scrollEndTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _isScrolling = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollEndTimer?.cancel();
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    if (mounted) {
      final thumbnailSize = await _preferences.getVideoGalleryThumbnailSize();
      final sortOption = await _preferences.getSortOption();
      final viewMode = await _preferences.getViewMode();

      setState(() {
        _thumbnailSize = thumbnailSize;
        _currentSortOption = sortOption;
        _viewMode = viewMode;
      });
    }
  }

  void _loadVideos() {
    _videoFilesFuture = getAllVideos(widget.path, recursive: widget.recursive);

    _videoFilesFuture.then((videos) {
      if (_isMounted) {
        setState(() {
          _videoFiles = videos;
          _sortVideoFiles();

          if (videos.isNotEmpty) {
            _isLoadingThumbnails = true;
          }
        });

        if (videos.isNotEmpty) {
          // Sử dụng VideoThumbnailHelper
          final videoPaths = videos.map((file) => file.path).toList();

          // Tải trước thumbnail với VideoThumbnailHelper
          VideoThumbnailHelper.optimizedBatchPreload(videoPaths).then((_) {
            if (_isMounted) {
              setState(() {
                _isLoadingThumbnails = false;
              });
            }
          });
        }
      }
    });
  }

  void _sortVideoFiles() {
    switch (_currentSortOption) {
      case SortOption.nameAsc:
        _videoFiles.sort((a, b) => pathlib
            .basename(a.path)
            .toLowerCase()
            .compareTo(pathlib.basename(b.path).toLowerCase()));
        break;

      case SortOption.nameDesc:
        _videoFiles.sort((a, b) => pathlib
            .basename(b.path)
            .toLowerCase()
            .compareTo(pathlib.basename(a.path).toLowerCase()));
        break;

      case SortOption.dateAsc:
        _videoFiles.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.dateDesc:
        _videoFiles.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeAsc:
        _videoFiles.sort((a, b) {
          try {
            return a.lengthSync().compareTo(b.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.sizeDesc:
        _videoFiles.sort((a, b) {
          try {
            return b.lengthSync().compareTo(a.lengthSync());
          } catch (e) {
            return 0;
          }
        });
        break;

      case SortOption.typeAsc:
        _videoFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.typeDesc:
        _videoFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.dateCreatedAsc:
        _videoFiles.sort((a, b) {
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
        _videoFiles.sort((a, b) {
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
        _videoFiles.sort((a, b) => pathlib
            .extension(a.path)
            .toLowerCase()
            .compareTo(pathlib.extension(b.path).toLowerCase()));
        break;

      case SortOption.extensionDesc:
        _videoFiles.sort((a, b) => pathlib
            .extension(b.path)
            .toLowerCase()
            .compareTo(pathlib.extension(a.path).toLowerCase()));
        break;

      case SortOption.attributesAsc:
        _videoFiles.sort((a, b) {
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
        _videoFiles.sort((a, b) {
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
        _sortVideoFiles();
      });

      // Save sort preference (global and folder-specific)
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

  double _calculateThumbnailSize(BuildContext context, int columns) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 16 - ((columns - 1) * 8);
    return availableWidth / columns;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Nếu đang ở chế độ chọn nhiều mục, hiển thị AppBar khác
    if (_isSelectionMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${_selectedFilePaths.length} video đã chọn'),
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
              tooltip: 'Xóa video đã chọn',
              onPressed: _selectedFilePaths.isEmpty
                  ? null
                  : () => _showDeleteConfirmationDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Chọn tất cả',
              onPressed: () {
                setState(() {
                  if (_selectedFilePaths.length == _videoFiles.length) {
                    _selectedFilePaths.clear();
                  } else {
                    _selectedFilePaths.addAll(_videoFiles.map((f) => f.path));
                  }
                });
              },
            ),
          ],
        ),
        body: _buildVideoContent(),
      );
    }

    // Sử dụng SharedActionBar để xây dựng danh sách actions
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
          _loadVideos();
        });
      },
      onGridSizePressed: () => SharedActionBar.showGridSizeDialog(
        context,
        currentGridSize: _thumbnailSize.round(),
        onApply: (size) async {
          setState(() {
            _thumbnailSize = size.toDouble();
          });

          // Lưu cài đặt
          try {
            await _preferences.setVideoGalleryThumbnailSize(size.toDouble());
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
      title: 'Video Gallery: ${pathlib.basename(widget.path)}',
      actions: actions,
      body: _buildVideoContent(),
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

  // Xây dựng nội dung video tùy theo chế độ xem
  Widget _buildVideoContent() {
    if (_videoFiles.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy video trong thư mục này',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        // Tìm kiếm và hiển thị kết quả
        if (_searchQuery != null && _searchQuery!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
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
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

        // Hiển thị video theo chế độ xem (danh sách hoặc lưới)
        Padding(
          padding: EdgeInsets.only(top: _searchQuery != null ? 50.0 : 0.0),
          child:
              _viewMode == ViewMode.grid ? _buildGridView() : _buildListView(),
        ),

        // Thông báo đang tải thumbnail
        if (_isLoadingThumbnails)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Đang tải thumbnail',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Hiển thị video dạng lưới
  Widget _buildGridView() {
    final columns = _thumbnailSize.round();
    final thumbnailSize = _calculateThumbnailSize(context, columns);

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      // Tối ưu scroll physics để cuộn mượt hơn
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Sử dụng caching cho các mục để tránh rebuild khi cuộn
      cacheExtent: 500, // Cache nhiều hơn để giảm loading khi cuộn nhanh
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 12,
      ),
      itemCount: _videoFiles.length,
      itemBuilder: (context, index) {
        final file = _videoFiles[index];
        final isSelected = _selectedFilePaths.contains(file.path);
        // Dùng placeholderOnly khi đang cuộn để giảm tải cho main thread
        final bool usePlaceholder = _isScrolling;

        return Stack(
          children: [
            OptimizedVideoThumbnailItem(
              file: file,
              width: thumbnailSize,
              height: thumbnailSize * 12 / 16,
              usePlaceholder: usePlaceholder, // Thêm flag này
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
                          builder: (context) =>
                              VideoPlayerFullScreen(file: file),
                        ),
                      );
                    },
            ),

            // Hiển thị biểu tượng chọn nếu đang ở chế độ chọn
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
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
        );
      },
    );
  }

  // Hiển thị video dạng danh sách
  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _videoFiles.length,
      itemBuilder: (context, index) {
        final file = _videoFiles[index];
        final isSelected = _selectedFilePaths.contains(file.path);
        final fileExtension = pathlib.extension(file.path).toLowerCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ThumbnailHelper.buildVideoThumbnail(
                      videoPath: file.path,
                      width: 60,
                      height: 60,
                      isVisible: true,
                      onThumbnailGenerated: (_) {},
                      fallbackBuilder: () => Container(
                        color: Colors.black12,
                        child: const Icon(Icons.movie, color: Colors.grey),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
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
                if (!snapshot.hasData) {
                  return const Text('Đang tải thông tin...');
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
                    onPressed: () => _showVideoOptions(context, file),
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
                        builder: (context) => VideoPlayerFullScreen(file: file),
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

  // Hiển thị menu tùy chọn cho video
  void _showVideoOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Phát video'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerFullScreen(file: file),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Thông tin video'),
            onTap: () {
              Navigator.pop(context);
              _showVideoInfoDialog(context, file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Chia sẻ'),
            onTap: () {
              Navigator.pop(context);
              // Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Chức năng chia sẻ sẽ được triển khai trong tương lai')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Xóa video', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmationDialog(context, [file.path]);
            },
          ),
        ],
      ),
    );
  }

  // Hiển thị dialog thông tin video
  void _showVideoInfoDialog(BuildContext context, File file) async {
    try {
      final fileStat = await file.stat();
      final fileSize = _formatFileSize(fileStat.size);
      final modified = fileStat.modified;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Thông tin video'),
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
      debugPrint('Error showing video info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hiển thị thông tin video: $e')),
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

  // Dialog xác nhận xóa video
  void _showDeleteConfirmationDialog(BuildContext context,
      [List<String>? specificPaths]) {
    final paths = specificPaths ?? _selectedFilePaths.toList();
    final count = paths.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa $count video?'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa các video đã chọn? Hành động này không thể hoàn tác.'),
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

              // Xử lý xóa file
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

              // Cập nhật danh sách video
              setState(() {
                _videoFiles.removeWhere((file) => paths.contains(file.path));
                _selectedFilePaths.clear();
                _isSelectionMode = false;
              });

              // Hiển thị thông báo kết quả
              if (failedPaths.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã xóa $successCount video')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Đã xóa $successCount video, ${failedPaths.length} lỗi')),
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

  // Dialog tìm kiếm video
  void _showSearchDialog(BuildContext context) {
    String searchQuery = _searchQuery ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm kiếm video'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên video...',
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
                });
                return;
              }

              setState(() {
                _searchQuery = searchQuery.trim();

                // Lọc video theo tên
                final searchLower = _searchQuery!.toLowerCase();
                _videoFiles = _videoFiles
                    .where((file) => pathlib
                        .basename(file.path)
                        .toLowerCase()
                        .contains(searchLower))
                    .toList();

                _sortVideoFiles();
              });
            },
            child: const Text('TÌM KIẾM'),
          ),
        ],
      ),
    );
  }

  // Lưu cài đặt chế độ xem
  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  // TODO: These methods are currently unused but may be needed for future tag management functionality
  /*
  void _showRemoveTagsDialog(
    // ... existing code ...
  }

  void _showManageAllTagsDialog(BuildContext context) {
    // ... existing code ...
  }

  Future<void> _addTags(List<String> filePaths, String tag) async {
    // ... existing code ...
  }
  */
}

class OptimizedVideoThumbnailItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool usePlaceholder;

  const OptimizedVideoThumbnailItem({
    Key? key,
    required this.file,
    required this.onTap,
    this.width = 120,
    this.height = 90,
    this.usePlaceholder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String ext = pathlib.extension(file.path).toLowerCase();

    // Optimize frame timing before rendering thumbnails
    FrameTimingOptimizer().optimizeImageRendering();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Sử dụng LazyVideoThumbnail để hiển thị thumbnail
                  LazyVideoThumbnail(
                    videoPath: file.path,
                    width: width,
                    height: height,
                    placeholderOnly: usePlaceholder,
                    fallbackBuilder: () => _buildFallbackThumbnail(ext),
                  ),

                  // Play button overlay
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(width > 100 ? 8 : 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: width > 100 ? 32 : 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filename overlay ở dưới
            Container(
              color: Colors.grey[100],
              padding: EdgeInsets.all(width > 100 ? 8 : 4),
              child: Text(
                pathlib.basename(file.path),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: width > 100 ? 12 : 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(String ext) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(ext),
        ),
      ),
      child: Center(
        child: Icon(
          _getVideoTypeIcon(ext),
          size: width > 100 ? 48 : 32,
          color: Colors.white.withAlpha(179),
        ),
      ),
    );
  }

  IconData _getVideoTypeIcon(String ext) {
    switch (ext) {
      case '.mp4':
        return Icons.movie;
      case '.mkv':
        return Icons.movie;
      case '.avi':
        return Icons.videocam;
      case '.mov':
        return Icons.videocam;
      case '.wmv':
        return Icons.video_library;
      default:
        return Icons.video_file;
    }
  }

  List<Color> _getGradientColors(String ext) {
    switch (ext) {
      case '.mp4':
        return [Colors.blue[900]!, Colors.blue[600]!];
      case '.mkv':
        return [Colors.green[900]!, Colors.green[600]!];
      case '.avi':
        return [Colors.purple[900]!, Colors.purple[600]!];
      case '.mov':
        return [Colors.orange[900]!, Colors.orange[600]!];
      case '.wmv':
        return [Colors.red[900]!, Colors.red[600]!];
      default:
        return [Colors.grey[900]!, Colors.grey[700]!];
    }
  }
}

class VideoPlayerFullScreen extends StatefulWidget {
  final File file;

  const VideoPlayerFullScreen({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  _VideoPlayerFullScreenState createState() => _VideoPlayerFullScreenState();
}

class _VideoPlayerFullScreenState extends State<VideoPlayerFullScreen> {
  Map<String, dynamic>? _videoMetadata;
  bool _isFullScreen = false;
  bool _showAppBar = true; // Control app bar visibility

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use Scaffold instead of BaseScreen to have more control over app bar visibility
      appBar: _isFullScreen && !_showAppBar
          ? null // Hide app bar completely when in fullscreen and _showAppBar is false
          : AppBar(
              title: Text(pathlib.basename(widget.file.path)),
              backgroundColor: Colors.black,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showVideoInfo(context),
                ),
              ],
            ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: VideoPlayer.file(
            file: widget.file,
            autoPlay: true,
            showControls: true,
            allowFullScreen: true,
            onVideoInitialized: (metadata) {
              setState(() {
                _videoMetadata = metadata;
              });
            },
            onError: (errorMessage) {
              // Optional: Show a snackbar or other notification
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $errorMessage')),
              );
            },
            // Add callbacks to synchronize fullscreen state and control visibility
            onFullScreenChanged: () {
              setState(() {
                _isFullScreen = !_isFullScreen;
                // When entering fullscreen, start with controls/appbar visible then hide after delay
                _showAppBar = true;
                if (_isFullScreen) {
                  // Auto-hide after a delay
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _isFullScreen) {
                      setState(() {
                        _showAppBar = false;
                      });
                    }
                  });
                }
              });
            },
            onControlVisibilityChanged: () {
              // Sync app bar visibility with video controls visibility
              if (_isFullScreen) {
                setState(() {
                  _showAppBar = true;
                });
                // Auto-hide after a delay
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _isFullScreen) {
                    setState(() {
                      _showAppBar = false;
                    });
                  }
                });
              }
            },
          ),
        ),
      ),
    );
  }

  void _showVideoInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VideoInfoDialog(
        file: widget.file,
        videoMetadata: _videoMetadata,
      ),
    );
  }
}
