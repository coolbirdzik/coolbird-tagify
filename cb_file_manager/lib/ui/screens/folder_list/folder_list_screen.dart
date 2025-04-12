import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart'; // Import SharedActionBar
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/main.dart'; // Import for goHome function

import 'folder_list_bloc.dart';
import 'folder_list_event.dart';
import 'folder_list_state.dart';

// Import all components using index file
import 'components/index.dart';

class FolderListScreen extends StatefulWidget {
  final String path;

  const FolderListScreen({Key? key, required this.path}) : super(key: key);

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  late TextEditingController _searchController;
  late TextEditingController _tagController;
  String? _currentFilter;
  String? _currentSearchTag;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

  // View and sort preferences
  late ViewMode _viewMode;
  late SortOption _sortOption;
  late int _gridZoomLevel;

  // Create the bloc instance at the class level
  late FolderListBloc _folderListBloc;

  // Global search toggle for tag search
  bool isGlobalSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tagController = TextEditingController();

    // Initialize the bloc
    _folderListBloc = FolderListBloc();
    _folderListBloc.add(FolderListLoad(widget.path));

    _saveLastAccessedFolder();

    // Load preferences
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          final prefs = UserPreferences();
          await prefs.init();
          final lastFolder = prefs.getLastAccessedFolder();

          if (lastFolder == widget.path) {
            await prefs.clearLastAccessedFolder();
          }
        }
      } catch (e) {
        print('Error in dispose cleanup: $e');
      }
    });

    _searchController.dispose();
    _tagController.dispose();
    _folderListBloc.close();
    super.dispose();
  }

  // Helper methods
  Future<void> _saveLastAccessedFolder() async {
    try {
      final directory = Directory(widget.path);
      if (await directory.exists()) {
        final UserPreferences prefs = UserPreferences();
        await prefs.init();
        await prefs.setLastAccessedFolder(widget.path);
      } else {
        print(
            'Cannot save last folder: directory does not exist: ${widget.path}');
      }
    } catch (e) {
      print('Error saving last accessed folder: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();

      setState(() {
        _viewMode = prefs.getViewMode();
        _sortOption = prefs.getSortOption();
        _gridZoomLevel = prefs.getGridZoomLevel();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _folderListBloc.add(SetViewMode(_viewMode));
          _folderListBloc.add(SetSortOption(_sortOption));
          _folderListBloc.add(SetGridZoom(_gridZoomLevel));
        }
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      print('Error saving view mode: $e');
    }
  }

  Future<void> _saveSortSetting(SortOption option) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setSortOption(option);
    } catch (e) {
      print('Error saving sort option: $e');
    }
  }

  Future<void> _saveGridZoomSetting(int zoomLevel) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setGridZoomLevel(zoomLevel);
      setState(() {
        _gridZoomLevel = zoomLevel;
      });
    } catch (e) {
      print('Error saving grid zoom level: $e');
    }
  }

  void _changeZoomLevel(int delta) {
    final currentZoom = _gridZoomLevel;
    final newZoom = (currentZoom + delta).clamp(
      UserPreferences.minGridZoomLevel,
      UserPreferences.maxGridZoomLevel,
    );

    if (newZoom != currentZoom) {
      _folderListBloc.add(SetGridZoom(newZoom));
      _saveGridZoomSetting(newZoom);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFilePaths.clear();
      }
    });
  }

  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFilePaths.contains(filePath)) {
        _selectedFilePaths.remove(filePath);
      } else {
        _selectedFilePaths.add(filePath);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFilePaths.clear();
    });
  }

  void _toggleViewMode() {
    final newMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
    _folderListBloc.add(SetViewMode(newMode));
    _saveViewModeSetting(newMode);
    setState(() {
      _viewMode = newMode;
    });
  }

  void _refreshFileList() {
    _folderListBloc.add(FolderListLoad(widget.path));
  }

  void _showSearchScreen(BuildContext context, FolderListState state) {
    showDialog(
      context: context,
      builder: (context) => SearchDialog(
        currentPath: widget.path,
        files: state.files.whereType<File>().toList(),
        folders: state.folders.whereType<Directory>().toList(),
      ),
    );
  }

  void _navigateToPath(String path) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FolderListScreen(path: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FolderListBloc>.value(
      value: _folderListBloc,
      child: BlocBuilder<FolderListBloc, FolderListState>(
        builder: (context, state) {
          _currentSearchTag = state.currentSearchTag;
          _currentFilter = state.currentFilter;

          // Sử dụng SharedActionBar nếu không ở chế độ chọn
          List<Widget> actions = _isSelectionMode
              ? []
              : SharedActionBar.buildCommonActions(
                  context: context,
                  onSearchPressed: () => _showSearchScreen(context, state),
                  onSortOptionSelected: (SortOption option) {
                    _folderListBloc.add(SetSortOption(option));
                    _saveSortSetting(option);
                  },
                  currentSortOption: state.sortOption,
                  viewMode: state.viewMode,
                  onViewModeToggled: _toggleViewMode,
                  onRefresh: _refreshFileList,
                  onGridSizePressed: state.viewMode == ViewMode.grid
                      ? () => SharedActionBar.showGridSizeDialog(
                            context,
                            currentGridSize: state.gridZoomLevel,
                            onApply: _handleGridZoomChange,
                          )
                      : null,
                  onSelectionModeToggled: _toggleSelectionMode,
                  onManageTagsPressed: () {
                    showManageTagsDialog(context, state.allTags.toList());
                  },
                  onGallerySelected: (value) {
                    if (value == 'image_gallery') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageGalleryScreen(
                            path: widget.path,
                            recursive: false,
                          ),
                        ),
                      );
                    } else if (value == 'video_gallery') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoGalleryScreen(
                            path: widget.path,
                            recursive: false,
                          ),
                        ),
                      );
                    }
                  },
                  currentPath: widget.path,
                );

          // If we're in selection mode, show a completely different AppBar
          if (_isSelectionMode) {
            return Scaffold(
              appBar: AppBar(
                title: Text('${_selectedFilePaths.length} selected'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                actions: [
                  if (_selectedFilePaths.isNotEmpty) ...[
                    // Tag management dropdown menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.label),
                      tooltip: 'Quản lý thẻ',
                      onSelected: (value) {
                        if (value == 'add_tag') {
                          showBatchAddTagDialog(
                              context, _selectedFilePaths.toList());
                        } else if (value == 'remove_tag') {
                          _showRemoveTagsDialog(
                              context, _selectedFilePaths.toList());
                        } else if (value == 'manage_all_tags') {
                          _showManageAllTagsDialog(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'add_tag',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline),
                              SizedBox(width: 8),
                              Text('Thêm thẻ'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'remove_tag',
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle_outline),
                              SizedBox(width: 8),
                              Text('Xóa thẻ'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'manage_all_tags',
                          child: Row(
                            children: [
                              Icon(Icons.settings),
                              SizedBox(width: 8),
                              Text('Quản lý tất cả thẻ'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete selected',
                      onPressed: () {
                        _showDeleteConfirmationDialog(context);
                      },
                    ),
                  ],
                ],
              ),
              body: _buildBody(context, state),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  showBatchAddTagDialog(context, _selectedFilePaths.toList());
                },
                child: const Icon(Icons.label),
              ),
            );
          }

          return BaseScreen(
            title: 'Files',
            actions: actions,
            body: _buildBody(context, state),
            floatingActionButton: FloatingActionButton(
              onPressed: _toggleSelectionMode,
              child: const Icon(Icons.checklist),
            ),
          );
        },
      ),
    );
  }

  Widget _sizePreviewBox(int size, int currentSize) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: currentSize == size ? Colors.blue : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.count(
            crossAxisCount: size,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              size * size,
              (index) => Container(
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$size',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedFilePaths.length} items?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete these items?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              BlocProvider.of<FolderListBloc>(context)
                  .add(FolderListDeleteFiles(_selectedFilePaths.toList()));
              Navigator.of(context).pop();
              _clearSelection();
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, FolderListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _folderListBloc.add(FolderListLoad(widget.path));
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Show search results if searching
    if (_currentSearchTag != null && state.searchResults.isNotEmpty) {
      return _buildSearchResultsList(context, state);
    }

    // Show filtered files if a filter is active
    if (_currentFilter != null &&
        _currentFilter!.isNotEmpty &&
        state.filteredFiles.isNotEmpty) {
      return Column(
        children: [
          BreadcrumbNavigation(
            currentPath: widget.path,
            onPathTap: _navigateToPath,
          ),
          _buildMediaGalleryButtons(context),
          Expanded(
            child: FileView(
              files: state.filteredFiles.whereType<File>().toList(),
              folders: [], // No folders in filtered view
              state: state,
              isSelectionMode: _isSelectionMode,
              isGridView: state.viewMode == ViewMode.grid,
              selectedFiles: _selectedFilePaths.toList(),
              toggleFileSelection: _toggleFileSelection,
              toggleSelectionMode: _toggleSelectionMode,
              showDeleteTagDialog: _showDeleteTagDialog,
              showAddTagToFileDialog: _showAddTagToFileDialog,
            ),
          ),
        ],
      );
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return Column(
        children: [
          BreadcrumbNavigation(
            currentPath: widget.path,
            onPathTap: _navigateToPath,
          ),
          _buildMediaGalleryButtons(context),
          const Expanded(
            child: Center(
              child: Text('Empty folder', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      );
    }

    // Default view - folders and files
    return RefreshIndicator(
      onRefresh: () async {
        _folderListBloc.add(FolderListLoad(widget.path));
      },
      child: Column(
        children: [
          BreadcrumbNavigation(
            currentPath: widget.path,
            onPathTap: _navigateToPath,
          ),
          _buildMediaGalleryButtons(context),
          Expanded(
            child: FileView(
              files: state.files.whereType<File>().toList(),
              folders: state.folders.whereType<Directory>().toList(),
              state: state,
              isSelectionMode: _isSelectionMode,
              isGridView: state.viewMode == ViewMode.grid,
              selectedFiles: _selectedFilePaths.toList(),
              toggleFileSelection: _toggleFileSelection,
              toggleSelectionMode: _toggleSelectionMode,
              showDeleteTagDialog: _showDeleteTagDialog,
              showAddTagToFileDialog: _showAddTagToFileDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context, FolderListState state) {
    String searchTitle = '';
    IconData searchIcon;

    // Determine the search type and appropriate display
    if (state.isSearchByName) {
      searchTitle = 'Search results for name: "${state.currentSearchQuery}"';
      searchIcon = Icons.search;
    } else {
      searchTitle = 'Search results for tag: "${state.currentSearchTag}"';
      searchIcon = Icons.label;
    }

    return Column(
      children: [
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(searchIcon, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
                onPressed: () {
                  _folderListBloc.add(FolderListLoad(widget.path));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FileView(
            files: state.searchResults.whereType<File>().toList(),
            folders: const [], // No folders in search results view
            state: state,
            isSelectionMode: _isSelectionMode,
            isGridView: state.viewMode == ViewMode.grid,
            selectedFiles: _selectedFilePaths.toList(),
            toggleFileSelection: _toggleFileSelection,
            toggleSelectionMode: _toggleSelectionMode,
            showDeleteTagDialog: _showDeleteTagDialog,
            showAddTagToFileDialog: _showAddTagToFileDialog,
          ),
        ),
      ],
    );
  }

  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    showAddTagToFileDialog(context, filePath);
  }

  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    showDeleteTagDialog(context, filePath, tags);
  }

  // Helper method to build media gallery option buttons
  Widget _buildMediaGalleryButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildGalleryButton(
              context: context,
              icon: Icons.photo_library,
              label: 'Images',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    path: widget.path,
                    recursive: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildGalleryButton(
              context: context,
              icon: Icons.video_library,
              label: 'Videos',
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoGalleryScreen(
                    path: widget.path,
                    recursive: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildGalleryButton(
              context: context,
              icon: Icons.photo_album,
              label: 'All Images',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    path: widget.path,
                    recursive: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildGalleryButton(
              context: context,
              icon: Icons.movie,
              label: 'All Videos',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoGalleryScreen(
                    path: widget.path,
                    recursive: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // New method to handle the grid zoom level change from the dialog
  void _handleGridZoomChange(int zoomLevel) {
    _folderListBloc.add(SetGridZoom(zoomLevel));
    _saveGridZoomSetting(zoomLevel);
  }

  // Tag management methods for selection mode
  void _showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
    showDialog(
      context: context,
      builder: (context) {
        final Set<String> availableTags = <String>{};

        // Process each file to get all tags
        Future<void> loadTags() async {
          for (final filePath in filePaths) {
            final tags = await TagManager.getTags(filePath);
            availableTags.addAll(tags);
          }

          // Force rebuild of the dialog when tags are loaded
          if (context.mounted) {
            setState(() {});
          }
        }

        // Start loading tags
        loadTags();

        // For tracking which tags to remove
        final selectedTags = <String>{};

        return StatefulBuilder(
          builder: (context, setState) {
            if (availableTags.isEmpty) {
              return AlertDialog(
                title: const Text('Không có thẻ'),
                content: const Text('Các tệp đã chọn không có thẻ nào.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('ĐÓNG'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Xóa thẻ'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chọn thẻ cần xóa khỏi các tệp đã chọn:'),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: availableTags.map((tag) {
                          return CheckboxListTile(
                            title: Text(tag),
                            value: selectedTags.contains(tag),
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('HỦY'),
                ),
                TextButton(
                  onPressed: selectedTags.isEmpty
                      ? null
                      : () async {
                          // Remove selected tags from files
                          for (final tag in selectedTags) {
                            await BatchTagManager.removeTagFromFiles(
                                filePaths, tag);
                          }
                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Đã xóa ${selectedTags.length} thẻ khỏi ${filePaths.length} tệp'),
                            ),
                          );

                          // Refresh file list to update tags
                          _refreshFileList();
                        },
                  child: const Text('XÓA THẺ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageAllTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final List<String> allTags = [];
        bool isLoading = true;

        // Load all unique tags
        Future<void> loadAllTags() async {
          final tags = await TagManager.getAllUniqueTags(widget.path);
          allTags.addAll(tags);
          isLoading = false;

          // Force rebuild of the dialog when tags are loaded
          if (context.mounted) {
            setState(() {});
          }
        }

        // Start loading tags
        loadAllTags();

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Quản lý tất cả thẻ'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tất cả thẻ hiện có trong hệ thống:'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (allTags.isEmpty
                            ? const Center(
                                child: Text('Không có thẻ nào'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: allTags.length,
                                itemBuilder: (context, index) {
                                  final tag = allTags[index];
                                  return ListTile(
                                    title: Text(tag),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        _showDeleteTagConfirmationDialog(
                                            context, tag);
                                      },
                                    ),
                                  );
                                },
                              )),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('ĐÓNG'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDeleteTagConfirmationDialog(BuildContext context, String tag) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xóa thẻ "$tag"?'),
          content: const Text(
              'Thẻ này sẽ bị xóa khỏi tất cả các tệp. Bạn có chắc chắn muốn tiếp tục?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('HỦY'),
            ),
            TextButton(
              onPressed: () async {
                // Find all files with this tag
                final files = await TagManager.findFilesByTag(widget.path, tag);

                // Remove tag from all files - Convert FileSystemEntity list to String list
                if (files.isNotEmpty) {
                  final filePaths = files.map((file) => file.path).toList();
                  await BatchTagManager.removeTagFromFiles(filePaths, tag);
                }

                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close the manage tags dialog too

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa thẻ "$tag" khỏi tất cả tệp'),
                  ),
                );

                // Refresh file list to update tags
                _refreshFileList();
              },
              child: const Text('XÓA', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
