import 'dart:io';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart'; // Add this import
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Import for mouse buttons
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'tab_manager.dart';

// Import folder list components with explicit alias
import '../screens/folder_list/folder_list_bloc.dart';
import '../screens/folder_list/folder_list_event.dart';
import '../screens/folder_list/folder_list_state.dart';
import '../screens/folder_list/components/index.dart' as folder_list_components;

// Import our new components with a clear namespace
import 'components/index.dart' as tab_components;
import 'tab_data.dart'; // Import TabData explicitly

/// A modified version of FolderListScreen that works with the tab system
class TabbedFolderListScreen extends StatefulWidget {
  final String path;
  final String tabId;
  final bool showAppBar; // Thêm tham số để kiểm soát việc hiển thị AppBar

  const TabbedFolderListScreen({
    Key? key,
    required this.path,
    required this.tabId,
    this.showAppBar = true, // Mặc định là hiển thị AppBar
  }) : super(key: key);

  @override
  State<TabbedFolderListScreen> createState() => _TabbedFolderListScreenState();
}

class _TabbedFolderListScreenState extends State<TabbedFolderListScreen> {
  late TextEditingController _searchController;
  late TextEditingController _tagController;
  late TextEditingController _pathController;
  String? _currentFilter;
  String? _currentSearchTag;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

  // Trạng thái hiển thị thanh tìm kiếm
  bool _showSearchBar = false;

  // Current path displayed in this tab
  String _currentPath = '';
  // Flag to indicate whether we're in path editing mode
  bool _isEditingPath = false;

  // View and sort preferences
  late ViewMode _viewMode;
  late SortOption _sortOption;
  late int _gridZoomLevel;

  // Create the bloc instance at the class level
  late FolderListBloc _folderListBloc;

  // Global search toggle for tag search
  bool isGlobalSearch = false;

  // Flag to track if we're handling a path update to avoid duplicate loads
  bool _isHandlingPathUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);

    // Initialize the bloc
    _folderListBloc = FolderListBloc();
    _folderListBloc.add(FolderListLoad(widget.path));

    _saveLastAccessedFolder();

    // Load preferences
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up a listener for TabManagerBloc state changes
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    final activeTab = tabBloc.state.activeTab;

    if (activeTab != null &&
        activeTab.id == widget.tabId &&
        activeTab.path != _currentPath) {
      // Only update if the path has actually changed
      _updatePath(activeTab.path);
    }
  }

  @override
  void didUpdateWidget(TabbedFolderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the path prop changes from parent, update our current path
    // and reload the folder list with the new path
    if (widget.path != oldWidget.path && widget.path != _currentPath) {
      _updatePath(widget.path);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    _pathController.dispose();
    _folderListBloc.close();
    super.dispose();
  }

  // Helper methods
  Future<void> _saveLastAccessedFolder() async {
    try {
      final directory = Directory(_currentPath);
      if (await directory.exists()) {
        final UserPreferences prefs = UserPreferences();
        await prefs.init();
        await prefs.setLastAccessedFolder(_currentPath);
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
    _folderListBloc.add(FolderListLoad(_currentPath));
  }

  void _showSearchScreen(BuildContext context, FolderListState state) {
    showDialog(
      context: context,
      builder: (context) => folder_list_components.SearchDialog(
        currentPath: _currentPath,
        files: state.files.whereType<File>().toList(),
        folders: state.folders.whereType<Directory>().toList(),
        onFolderSelected: (path) {
          // Khi người dùng chọn thư mục, chuyển đến thư mục đó trong tab hiện tại
          _navigateToPath(path);
        },
        onFileSelected: (file) {
          // Khi người dùng chọn file, mở file đó
          final extension = file.path.split('.').last.toLowerCase();
          final isVideo =
              ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension);
          _onFileTap(file, isVideo);
        },
      ),
    );
  }

  // Hiển thị tooltip hướng dẫn sử dụng tìm kiếm tag khi người dùng nhấn vào icon tìm kiếm lần đầu
  void _showSearchTip(BuildContext context) {
    final UserPreferences prefs = UserPreferences();
    prefs.init().then((_) {
      prefs.getSearchTipShown().then((shown) {
        if (!shown) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Mẹo tìm kiếm'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Tìm kiếm theo tên'),
                    subtitle: Text('Gõ từ khóa để tìm tệp theo tên'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.local_offer),
                    title: Text('Tìm kiếm theo tag'),
                    subtitle: Text('Gõ # và tên tag (ví dụ: #important)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _showSearchBar = true;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          prefs.setSearchTipShown(true);
        } else {
          setState(() {
            _showSearchBar = true;
          });
        }
      });
    });
  }

  // This method updates both the tab's path in the TabManager
  // and the local UI state to display the new path
  void _navigateToPath(String path) {
    // Update the current path in local state
    setState(() {
      _currentPath = path;
      _pathController.text = path;
    });

    // Clear any search or filter state when navigating
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(ClearSearchAndFilters());
    }

    // Update the tab's path in the TabManager
    context.read<TabManagerBloc>().add(UpdateTabPath(widget.tabId, path));

    // Also add this path to the tab's navigation history
    context.read<TabManagerBloc>().add(AddToTabHistory(widget.tabId, path));

    // Update the folder list to show the new path
    _folderListBloc.add(FolderListLoad(path));

    // Save this folder as last accessed
    _saveLastAccessedFolder();

    // Update the tab name based on the new path
    final pathParts = path.split(Platform.pathSeparator);
    final lastPart =
        pathParts.lastWhere((part) => part.isNotEmpty, orElse: () => 'Root');
    final tabName = lastPart.isEmpty ? 'Root' : lastPart;

    // Update tab name if needed
    context.read<TabManagerBloc>().add(UpdateTabName(widget.tabId, tabName));
  }

  // Handle path submission when user manually edits the path
  void _handlePathSubmit(String path) {
    // Handle empty path as drive selection view
    if (path.isEmpty && Platform.isWindows) {
      setState(() {
        _currentPath = '';
        _pathController.text = '';
        _isEditingPath = false;
      });
      return;
    }

    // Check if path exists
    final directory = Directory(path);
    directory.exists().then((exists) {
      if (exists) {
        _navigateToPath(path);
        setState(() {
          _isEditingPath = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đường dẫn không tồn tại hoặc không thể truy cập'),
            backgroundColor: Colors.red,
          ),
        );
        // Revert to current path
        _pathController.text = _currentPath;
      }
    });
  }

  Future<bool> _handleBackNavigation() async {
    // First check if we're in selection mode
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedFilePaths.clear();
      });
      return false; // Don't exit the app, just exit selection mode
    }

    // Check if we're showing search results
    if (_currentSearchTag != null || _currentFilter != null) {
      _folderListBloc.add(const ClearSearchAndFilters());
      _folderListBloc.add(FolderListLoad(_currentPath));
      return false; // Don't exit the app, just exit search mode
    }

    // Check if we are at a root drive level (like C:\) and should navigate to drive selection
    if (Platform.isWindows &&
        (_currentPath.length == 3 && _currentPath.endsWith(':\\'))) {
      setState(() {
        _currentPath = '';
        _pathController.text = '';
      });

      // Update the tab's path in the TabManager
      context.read<TabManagerBloc>().add(UpdateTabPath(widget.tabId, ''));
      context.read<TabManagerBloc>().add(AddToTabHistory(widget.tabId, ''));
      context.read<TabManagerBloc>().add(UpdateTabName(widget.tabId, 'Drives'));

      // Don't call FolderListLoad here as the build method will handle showing the drive view
      return false; // Don't exit app, we're navigating to the drives view
    }

    // Check if we can navigate back in the folder hierarchy
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
      final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);
      if (previousPath != null) {
        // Handle empty path case for Windows drive view
        if (previousPath.isEmpty && Platform.isWindows) {
          setState(() {
            _currentPath = '';
            _pathController.text = '';
          });
          // Update the tab name to indicate we're showing drives
          context
              .read<TabManagerBloc>()
              .add(UpdateTabName(widget.tabId, 'Drives'));
          return false; // Don't exit app, we're navigating to drives view
        }

        // Regular path navigation
        setState(() {
          _currentPath = previousPath;
          _pathController.text = previousPath;
        });
        _folderListBloc.add(FolderListLoad(previousPath));
        return false; // Don't exit app, we navigated back
      }
    }

    // If we're at the root, let the system handle back (which might exit the app)
    return true;
  }

  // Centralized method to update path and reload folder contents
  void _updatePath(String newPath) {
    if (_isHandlingPathUpdate) return; // Prevent recursive updates

    _isHandlingPathUpdate = true;

    setState(() {
      _currentPath = newPath;
      _pathController.text = newPath;
    });

    // Clear any search or filter state when navigating
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(ClearSearchAndFilters());
    }

    // Load the folder contents with the new path
    _folderListBloc.add(FolderListLoad(newPath));

    // Save as last accessed folder
    _saveLastAccessedFolder();

    _isHandlingPathUpdate = false;
  }

  @override
  Widget build(BuildContext context) {
    // If path is empty, show drive picker view
    if (_currentPath.isEmpty && Platform.isWindows) {
      return tab_components.DriveView(
        tabId: widget.tabId,
        folderListBloc: _folderListBloc,
        onPathChanged: (String path) {
          setState(() {
            _currentPath = path;
            _pathController.text = path;
          });
        },
        // Add handlers for mouse navigation buttons
        onBackButtonPressed: () => _handleMouseBackButton(),
        onForwardButtonPressed: () => _handleMouseForwardButton(),
      );
    }

    // Add a BlocListener to actively listen for TabManagerBloc state changes
    return BlocListener<TabManagerBloc, TabManagerState>(
      listener: (context, tabManagerState) {
        // Find the current tab data
        final currentTab = tabManagerState.tabs.firstWhere(
          (tab) => tab.id == widget.tabId,
          orElse: () => TabData(id: '', name: '', path: ''),
        );

        // If the tab's path has changed and is different from our current path, update it
        if (currentTab.id.isNotEmpty && currentTab.path != _currentPath) {
          print('Tab path updated from $_currentPath to ${currentTab.path}');
          // Use updatePath method to update our state and folder list
          _updatePath(currentTab.path);
        }
      },
      child: WillPopScope(
        onWillPop: _handleBackNavigation,
        // Wrap with Listener to detect mouse button events
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            // Mouse button 4 is usually the back button (button value is 8)
            if (event.buttons == 8) {
              _handleMouseBackButton();
            }
            // Mouse button 5 is usually the forward button (button value is 16)
            else if (event.buttons == 16) {
              _handleMouseForwardButton();
            }
          },
          child: BlocProvider<FolderListBloc>.value(
            value: _folderListBloc,
            child: BlocBuilder<FolderListBloc, FolderListState>(
              builder: (context, state) {
                _currentSearchTag = state.currentSearchTag;
                _currentFilter = state.currentFilter;

                // Create actions for the app bar
                List<Widget> actions = [];
                actions.addAll(_isSelectionMode
                    ? []
                    : SharedActionBar.buildCommonActions(
                        context: context,
                        onSearchPressed: () => _showSearchTip(context),
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
                          tab_components.showManageTagsDialog(
                              context, state.allTags.toList());
                        },
                        onGallerySelected: (value) {
                          if (value == 'image_gallery') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageGalleryScreen(
                                  path: _currentPath,
                                  recursive: false,
                                ),
                              ),
                            );
                          } else if (value == 'video_gallery') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoGalleryScreen(
                                  path: _currentPath,
                                  recursive: false,
                                ),
                              ),
                            );
                          }
                        },
                        currentPath: _currentPath,
                      ));

                // If we're in selection mode, show a custom app bar
                if (_isSelectionMode) {
                  return Scaffold(
                    appBar: tab_components.SelectionAppBar(
                      selectedCount: _selectedFilePaths.length,
                      onClearSelection: _clearSelection,
                      selectedFilePaths: _selectedFilePaths.toList(),
                      showRemoveTagsDialog: _showRemoveTagsDialog,
                      showManageAllTagsDialog: (context) =>
                          _showManageAllTagsDialog(context),
                      showDeleteConfirmationDialog: (context) =>
                          _showDeleteConfirmationDialog(context),
                    ),
                    body: _buildBody(context, state),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () {
                        tab_components.showBatchAddTagDialog(
                            context, _selectedFilePaths.toList());
                      },
                      child: const Icon(Icons.label),
                    ),
                  );
                }

                // Note: We're not using BaseScreen here since we're already inside a tab
                return Scaffold(
                  appBar: widget.showAppBar
                      ? AppBar(
                          title: _showSearchBar
                              ? tab_components.SearchBar(
                                  currentPath: _currentPath,
                                  onCloseSearch: () {
                                    setState(() {
                                      _showSearchBar = false;
                                    });
                                  },
                                )
                              : tab_components.PathNavigationBar(
                                  tabId: widget.tabId,
                                  pathController: _pathController,
                                  onPathSubmitted: _handlePathSubmit,
                                  currentPath: _currentPath,
                                ),
                          actions: _showSearchBar ? [] : actions,
                        )
                      : null,
                  body: _buildBody(context, state),
                  floatingActionButton: FloatingActionButton(
                    onPressed: _toggleSelectionMode,
                    child: const Icon(Icons.checklist),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _extractFolderName(String path) {
    // Use platform-specific path separator
    final pathParts = path.split(Platform.pathSeparator);
    return pathParts.isEmpty || pathParts.last.isEmpty
        ? 'Root'
        : pathParts.last;
  }

  Widget _buildBody(BuildContext context, FolderListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return tab_components.ErrorView(
        errorMessage: state.error!,
        onRetry: () {
          _folderListBloc.add(FolderListLoad(_currentPath));
        },
        onGoBack: () {
          // Navigate to parent directory or home if this fails
          try {
            final parentPath = Directory(_currentPath).parent.path;
            if (parentPath != _currentPath) {
              _navigateToPath(parentPath);
            } else {
              // If we're at root level, navigate to the drive listing
              _navigateToPath(''); // Empty path triggers drive list
            }
          } catch (e) {
            // If all else fails, go to empty path to show drives
            _navigateToPath('');
          }
        },
      );
    }

    // Hiển thị kết quả tìm kiếm (cả theo tag và theo tên tệp)
    if (state.currentSearchTag != null || state.currentSearchQuery != null) {
      if (state.searchResults.isNotEmpty) {
        return tab_components.SearchResultsView(
          state: state,
          isSelectionMode: _isSelectionMode,
          selectedFiles: _selectedFilePaths.toList(),
          toggleFileSelection: _toggleFileSelection,
          toggleSelectionMode: _toggleSelectionMode,
          showDeleteTagDialog: _showDeleteTagDialog,
          showAddTagToFileDialog: _showAddTagToFileDialog,
          onClearSearch: () {
            _folderListBloc.add(const ClearSearchAndFilters());
            _folderListBloc.add(FolderListLoad(_currentPath));
          },
          onFolderTap:
              _navigateToPath, // Truyền callback để điều hướng trong cùng tab
          onFileTap: _onFileTap, // Truyền callback mở file
          // Add mouse back/forward navigation handlers
          onBackButtonPressed: () => _handleMouseBackButton(),
          onForwardButtonPressed: () => _handleMouseForwardButton(),
        );
      } else {
        // Hiển thị thông báo không tìm thấy kết quả
        return Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    state.currentSearchTag != null
                        ? Icons.local_offer
                        : Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(state.currentSearchTag != null
                        ? 'Không tìm thấy kết quả cho tag "${state.currentSearchTag}"'
                        : 'Không tìm thấy kết quả cho "${state.currentSearchQuery}"'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _folderListBloc.add(const ClearSearchAndFilters());
                      _folderListBloc.add(FolderListLoad(_currentPath));
                    },
                    tooltip: 'Xóa tìm kiếm',
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Không tìm thấy tệp nào phù hợp',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }

    // Show filtered files if a filter is active
    if (_currentFilter != null &&
        _currentFilter!.isNotEmpty &&
        state.filteredFiles.isNotEmpty) {
      return folder_list_components.FileView(
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
      );
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return const Center(
        child: Text('Thư mục trống', style: TextStyle(fontSize: 18)),
      );
    }

    // Default view - folders and files
    return RefreshIndicator(
      onRefresh: () async {
        _folderListBloc.add(FolderListLoad(_currentPath));
      },
      child: _buildFolderAndFileList(state),
    );
  }

  Widget _buildFolderAndFileList(FolderListState state) {
    if (state.viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: state.gridZoomLevel,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: state.folders.length + state.files.length,
        itemBuilder: (context, index) {
          if (index < state.folders.length) {
            // This is a folder
            final folder = state.folders[index] as Directory;
            return tab_components.FolderGridItem(
                folder: folder, onNavigate: _navigateToPath);
          } else {
            // This is a file
            final fileIndex = index - state.folders.length;
            if (fileIndex < state.files.length) {
              final file = state.files[fileIndex] as File;
              return folder_list_components.FileGridItem(
                file: file,
                state: state,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedFilePaths.contains(file.path),
                toggleFileSelection: _toggleFileSelection,
                toggleSelectionMode: _toggleSelectionMode,
                onFileTap: _onFileTap, // Thêm callback để mở file
              );
            }
            return Container(); // Fallback for any index issues
          }
        },
      );
    } else {
      return ListView(
        children: [
          // Folders list
          ...state.folders
              .map((folder) => tab_components.FolderListItem(
                    folder: folder as Directory,
                    onNavigate: _navigateToPath,
                  ))
              .toList(),

          // Files list
          ...state.files
              .map((file) => folder_list_components.FileItem(
                    file: file as File,
                    state: state,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedFilePaths.contains(file.path),
                    toggleFileSelection: _toggleFileSelection,
                    showDeleteTagDialog: _showDeleteTagDialog,
                    showAddTagToFileDialog: _showAddTagToFileDialog,
                    onFileTap: _onFileTap, // Thêm callback để mở file
                  ))
              .toList(),
        ],
      );
    }
  }

  // Helper methods for tag dialog calls
  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    tab_components.showAddTagToFileDialog(context, filePath);
  }

  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    tab_components.showDeleteTagDialog(context, filePath, tags);
  }

  void _showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
    tab_components.showRemoveTagsDialog(context, filePaths);
  }

  void _showManageAllTagsDialog(BuildContext context) {
    tab_components.showManageTagsDialog(
        context, _folderListBloc.state.allTags.toList());
  }

  void _handleGridZoomChange(int zoomLevel) {
    _folderListBloc.add(SetGridZoom(zoomLevel));
    _saveGridZoomSetting(zoomLevel);
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Tag search dialog and handling
  void _showTagSearchDialog(BuildContext context) {
    tab_components.showTagSearchDialog(
      context,
      _currentPath,
      (List<FileSystemEntity> results, String tagName) {
        // Update UI to show search results
        _folderListBloc.add(SetTagSearchResults(results, tagName));
      },
    );
  }

  // Xử lý khi người dùng click vào một file trong kết quả tìm kiếm
  void _onFileTap(File file, bool isVideo) {
    // Mở file theo loại tương ứng
    if (isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          // VideoPlayerFullScreen là class đúng để mở video, không phải viewSingleVideo
          builder: (context) => VideoPlayerFullScreen(file: file),
        ),
      );
    } else {
      // Xử lý các loại file khác
      Navigator.push(
        context,
        MaterialPageRoute(
          // Import đúng FileDetailsScreen từ folder_list
          builder: (context) => FileDetailsScreen(file: file),
        ),
      );
    }
  }

  // Method to handle mouse back button press
  void _handleMouseBackButton() {
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
      // Get previous path
      final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);

      if (previousPath != null) {
        // Handle empty path case for Windows drive view
        if (previousPath.isEmpty && Platform.isWindows) {
          setState(() {
            _currentPath = '';
            _pathController.text = '';
          });
          // Update the tab name to indicate we're showing drives
          context
              .read<TabManagerBloc>()
              .add(UpdateTabName(widget.tabId, 'Drives'));
        } else {
          // Regular path navigation
          setState(() {
            _currentPath = previousPath;
            _pathController.text = previousPath;
          });
        }

        // Pop from tab history in the TabManager
        context.read<TabManagerBloc>().add(PopFromTabHistory(widget.tabId));

        // Load the folder content
        _folderListBloc.add(FolderListLoad(previousPath));
      }
    }
  }

  // Method to handle mouse forward button press
  void _handleMouseForwardButton() {
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateForward(widget.tabId)) {
      // Get next path
      final nextPath = tabManagerBloc.getTabNextPath(widget.tabId);

      if (nextPath != null) {
        // Handle empty path case for Windows drive view
        if (nextPath.isEmpty && Platform.isWindows) {
          setState(() {
            _currentPath = '';
            _pathController.text = '';
          });
          // Update the tab name to indicate we're showing drives
          context
              .read<TabManagerBloc>()
              .add(UpdateTabName(widget.tabId, 'Drives'));
        } else {
          // Regular path navigation
          setState(() {
            _currentPath = nextPath;
            _pathController.text = nextPath;
          });
        }

        // Instead of using GoForwardInTabHistory, directly use the forwardNavigationToPath method
        // This will avoid the unregistered event handler error
        final String? actualPath =
            tabManagerBloc.forwardNavigationToPath(widget.tabId);

        // If navigation was successful, load the folder content
        if (actualPath != null) {
          _folderListBloc.add(FolderListLoad(actualPath));
        }
      }
    }
  }
}
