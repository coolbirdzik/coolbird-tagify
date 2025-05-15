import 'dart:io';
import 'dart:async'; // Add this import for Completer
import 'dart:async' show scheduleMicrotask;
import 'dart:math'; // For math operations with drag selection and min/max functions

import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
// Add this import
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart'; // Import the new ImageViewerScreen
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:flutter/material.dart';
// Add for scheduler bindings
import 'package:flutter/gestures.dart'; // Import for mouse buttons
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart'; // Add import for VideoThumbnailHelper
import 'package:flutter/services.dart'; // Import for keyboard keys
import 'tab_manager.dart';

// Import folder list components with explicit alias
import '../screens/folder_list/folder_list_bloc.dart';
import '../screens/folder_list/folder_list_event.dart';
import '../screens/folder_list/folder_list_state.dart';
import '../screens/folder_list/components/index.dart' as folder_list_components;

// Import our new components with a clear namespace
import 'components/index.dart' as tab_components;
import 'tab_data.dart'; // Import TabData explicitly
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart'; // Import for TrashManager

// Add imports for hardware acceleration
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/scheduler.dart'
    show SchedulerBinding; // For scheduler and timeDilation

// Helper function to determine if we're on desktop
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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
  final Set<String> _selectedFolderPaths = {}; // Add set for selected folders

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

  // Add these properties to store last selected file for shift-selection
  String? _lastSelectedFilePath;

  // Add these variables for ultra-fast selection mode
  Set<String> _pendingFilePaths = {};
  Set<String> _pendingFolderPaths = {};
  bool _selectionUpdatePending = false;

  // Variables for drag selection
  bool _isDragging = false;
  Offset? _dragStartPosition;
  Offset? _dragCurrentPosition;
  Map<String, Rect> _itemPositions = {};

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);

    // Enable hardware acceleration for smoother animations
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;
    // Replace with platform-optimized settings
    RendererBinding.instance.ensureSemantics();

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
    // Restore default settings
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;

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
        final UserPreferences prefs = UserPreferences.instance;
        await prefs.init();
        await prefs.setLastAccessedFolder(_currentPath);
      }
    } catch (e) {
      print('Error saving last accessed folder: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();

      final viewMode = await prefs.getViewMode();
      final sortOption = await prefs.getSortOption();
      final gridZoomLevel = await prefs.getGridZoomLevel();

      if (mounted) {
        setState(() {
          _viewMode = viewMode;
          _sortOption = sortOption;
          _gridZoomLevel = gridZoomLevel;
        });

        _folderListBloc.add(SetViewMode(viewMode));
        _folderListBloc.add(SetSortOption(sortOption));
        _folderListBloc.add(SetGridZoom(gridZoomLevel));
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveViewModeSetting(ViewMode mode) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setViewMode(mode);
    } catch (e) {
      print('Error saving view mode: $e');
    }
  }

  Future<void> _saveSortSetting(SortOption option) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setSortOption(option);
    } catch (e) {
      print('Error saving sort option: $e');
    }
  }

  Future<void> _saveGridZoomSetting(int zoomLevel) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
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
        _selectedFolderPaths.clear();
        _lastSelectedFilePath = null;
      }
    });
  }

  // Completely rewritten selection method to fix issues with both files and folders
  void _toggleItemSelection(String itemPath, bool isFolder,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    if (!shiftSelect) {
      // SINGLE ITEM SELECTION LOGIC
      final isAlreadySelected = isFolder
          ? _selectedFolderPaths.contains(itemPath)
          : _selectedFilePaths.contains(itemPath);

      if (isAlreadySelected && ctrlSelect) {
        // Ctrl+click on selected item should deselect it
        if (isFolder) {
          _selectedFolderPaths.remove(itemPath);
        } else {
          _selectedFilePaths.remove(itemPath);
        }
      } else {
        // Clear previous selections if not Ctrl+click
        if (!ctrlSelect) {
          _selectedFilePaths.clear();
          _selectedFolderPaths.clear();
        }

        // Add new selection (if using Ctrl+click on an already selected item, do nothing)
        if (!isAlreadySelected) {
          if (isFolder) {
            _selectedFolderPaths.add(itemPath);
          } else {
            _selectedFilePaths.add(itemPath);
          }
        }
      }

      // Store as last selected for Shift+click
      _lastSelectedFilePath = itemPath;
    } else if (_lastSelectedFilePath != null) {
      // SHIFT+CLICK RANGE SELECTION LOGIC

      // Create list of all paths in same order as displayed in UI
      final List<String> allFolderPaths =
          _folderListBloc.state.folders.map((f) => f.path).toList();
      final List<String> allFilePaths =
          _folderListBloc.state.files.map((f) => f.path).toList();
      final List<String> allPaths = [...allFolderPaths, ...allFilePaths];

      // Find indices of current and last-selected items
      final int currentIndex = allPaths.indexOf(itemPath);
      final int lastIndex = allPaths.indexOf(_lastSelectedFilePath!);

      if (currentIndex >= 0 && lastIndex >= 0) {
        // Clear previous selections if not Ctrl+click
        if (!ctrlSelect) {
          _selectedFilePaths.clear();
          _selectedFolderPaths.clear();
        }

        // Determine range boundaries (inclusive)
        final int startIndex = min(currentIndex, lastIndex);
        final int endIndex = max(currentIndex, lastIndex);

        // Process all items in range
        for (int i = startIndex; i <= endIndex; i++) {
          final String path = allPaths[i];

          // Determine whether path is a folder or file
          if (allFolderPaths.contains(path)) {
            _selectedFolderPaths.add(path);
          } else {
            _selectedFilePaths.add(path);
          }
        }
      }
    }

    // Update selection mode
    _isSelectionMode =
        _selectedFilePaths.isNotEmpty || _selectedFolderPaths.isNotEmpty;

    // Trigger UI update
    if (!_selectionUpdatePending) {
      _selectionUpdatePending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectionUpdatePending = false;
          });
        }
      });
    }
  }

  // Update file selection to use the unified selection system
  void _toggleFileSelection(String filePath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    _toggleItemSelection(filePath, false,
        shiftSelect: shiftSelect, ctrlSelect: ctrlSelect);
  }

  // Update folder selection to use the unified selection system
  void _toggleFolderSelection(String folderPath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    _toggleItemSelection(folderPath, true,
        shiftSelect: shiftSelect, ctrlSelect: ctrlSelect);
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFilePaths.clear();
      _selectedFolderPaths.clear();
      _lastSelectedFilePath = null;
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
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang làm mới thumbnails...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Đặt cờ để đánh dấu đang trong quá trình refresh
    bool isRefreshing = true;

    // Xóa cache hình ảnh của Flutter
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Xóa cache thumbnail và cache hệ thống
    VideoThumbnailHelper.clearCache();

    // Reload thư mục với forceRegenerateThumbnails để đảm bảo thumbnail được tạo mới
    _folderListBloc
        .add(FolderListRefresh(_currentPath, forceRegenerateThumbnails: true));

    // Thiết lập thời gian chờ cố định 3 giây (đủ để đảm bảo hoàn tất các thao tác trên UI)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && isRefreshing) {
        isRefreshing = false;
        // Thông báo hoàn tất làm mới
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã làm mới xong!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });

    // Thiết lập timeout dài hơn để đảm bảo không bị kẹt
    Future.delayed(const Duration(seconds: 15), () {
      // Đảm bảo không hiển thị thông báo hai lần
      if (mounted && isRefreshing) {
        isRefreshing = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Đã hoàn tất làm mới. Một số thumbnail có thể cần thời gian để cập nhật.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
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
    final UserPreferences prefs = UserPreferences.instance;
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
                    leading: Icon(EvaIcons.search),
                    title: Text('Tìm kiếm theo tên'),
                    subtitle: Text('Gõ từ khóa để tìm tệp theo tên'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(EvaIcons.shoppingBag),
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
    // Stop any ongoing thumbnail processing to prevent UI lag
    VideoThumbnailHelper.stopAllProcessing();

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

  // Handle back button press for Android
  Future<bool> _handleBackButton() async {
    // Stop any ongoing thumbnail processing when navigating
    VideoThumbnailHelper.stopAllProcessing();

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

    // Stop any ongoing thumbnail processing to prevent UI lag
    VideoThumbnailHelper.stopAllProcessing();

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
        onWillPop: _handleBackButton,
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
                          tab_components.showManageTagsDialog(context,
                              state.allTags.toList(), state.currentPath.path);
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
                      selectedCount: _selectedFilePaths.length +
                          _selectedFolderPaths.length,
                      onClearSelection: _clearSelection,
                      selectedFilePaths: _selectedFilePaths.toList(),
                      selectedFolderPaths: _selectedFolderPaths.toList(),
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
                      child: const Icon(EvaIcons.shoppingBag),
                    ),
                  );
                }

                // Note: We're not using BaseScreen here since we're already inside a tab
                return Scaffold(
                  appBar: widget.showAppBar
                      ? AppBar(
                          automaticallyImplyLeading:
                              false, // Tắt nút back tự động
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
                    child: const Icon(EvaIcons.checkmarkSquare2Outline),
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
    // Apply frame timing optimization before heavy UI operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

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
                        ? EvaIcons.shoppingBag
                        : EvaIcons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(state.currentSearchTag != null
                        ? 'Không tìm thấy kết quả cho tag "${state.currentSearchTag}"'
                        : 'Không tìm thấy kết quả cho "${state.currentSearchQuery}"'),
                  ),
                  IconButton(
                    icon: const Icon(EvaIcons.close),
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
                    Icon(EvaIcons.search, size: 64, color: Colors.grey),
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
        // Create the completer first
        final completer = Completer<void>();

        // Create the subscription variable
        late StreamSubscription subscription;

        // Now set up the listener
        subscription = _folderListBloc.stream.listen((state) {
          // When loading is done (changed from true to false), complete the Future
          if (!state.isLoading) {
            completer.complete();
            subscription.cancel();
          }
        });

        // Use FolderListRefresh instead of FolderListLoad to force thumbnail regeneration
        VideoThumbnailHelper.trimCache();
        _folderListBloc.add(
            FolderListRefresh(_currentPath, forceRegenerateThumbnails: true));

        // Wait for the loading to complete before returning
        return completer.future;
      },
      child: _buildFolderAndFileList(state),
    );
  }

  Widget _buildFolderAndFileList(FolderListState state) {
    // Apply frame timing optimizations before heavy list/grid operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    if (state.viewMode == ViewMode.grid) {
      return Stack(
        children: [
          GestureDetector(
            // Exit selection mode when tapping background
            onTap: () {
              if (_isSelectionMode) {
                _clearSelection();
              }
            },
            // Handle drag selection
            onPanStart: (details) {
              _startDragSelection(details.localPosition);
            },
            onPanUpdate: (details) {
              _updateDragSelection(details.localPosition);
            },
            onPanEnd: (details) {
              _endDragSelection();
            },
            behavior: HitTestBehavior.translucent,
            child: Listener(
              onPointerSignal: (PointerSignalEvent event) {
                // Chỉ xử lý khi ở chế độ lưới
                if (state.viewMode != ViewMode.grid) return;

                // Xử lý sự kiện cuộn chuột kết hợp với phím Ctrl
                if (event is PointerScrollEvent) {
                  // Kiểm tra xem phím Ctrl có được nhấn không
                  if (RawKeyboard.instance.keysPressed
                          .contains(LogicalKeyboardKey.controlLeft) ||
                      RawKeyboard.instance.keysPressed
                          .contains(LogicalKeyboardKey.controlRight)) {
                    // Xác định hướng cuộn (lên = -1, xuống = 1)
                    final int direction = event.scrollDelta.dy > 0 ? 1 : -1;

                    // Gọi phương thức để thay đổi mức zoom
                    _handleZoomLevelChange(direction);

                    // Ngăn chặn sự kiện mặc định
                    GestureBinding.instance.pointerSignalResolver
                        .resolve(event);
                  }
                }
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(8.0),
                // Add physics for better scrolling performance
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // Add caching for better scroll performance
                cacheExtent: 1000,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: state.gridZoomLevel,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: state.folders.length + state.files.length,
                itemBuilder: (context, index) {
                  // Get path for this item
                  final String itemPath = index < state.folders.length
                      ? state.folders[index].path
                      : state.files[index - state.folders.length].path;

                  // Wrap with LayoutBuilder to capture item positions
                  return LayoutBuilder(builder:
                      (BuildContext context, BoxConstraints constraints) {
                    // Perform post-layout callback to store item position
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final RenderBox? renderBox =
                          context.findRenderObject() as RenderBox?;
                      if (renderBox != null && renderBox.hasSize) {
                        final position = renderBox.localToGlobal(Offset.zero);
                        _registerItemPosition(
                            itemPath,
                            Rect.fromLTWH(position.dx, position.dy,
                                renderBox.size.width, renderBox.size.height));
                      }
                    });

                    // Build the actual item
                    return RepaintBoundary(
                      child: index < state.folders.length
                          ? tab_components.FolderGridItem(
                              folder: state.folders[index] as Directory,
                              onNavigate: _navigateToPath,
                              isSelected: _selectedFolderPaths
                                  .contains(state.folders[index].path),
                              toggleFolderSelection: _toggleFolderSelection,
                              isDesktopMode: isDesktopPlatform,
                              lastSelectedPath: _lastSelectedFilePath,
                            )
                          : folder_list_components.FileGridItem(
                              file: state.files[index - state.folders.length]
                                  as File,
                              state: state,
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedFilePaths.contains(state
                                  .files[index - state.folders.length].path),
                              toggleFileSelection: _toggleFileSelection,
                              toggleSelectionMode: _toggleSelectionMode,
                              onFileTap: _onFileTap,
                              // Add tag management callbacks to enable context menu functionality
                              showAddTagToFileDialog: _showAddTagToFileDialog,
                              showDeleteTagDialog: _showDeleteTagDialog,
                              isDesktopMode: isDesktopPlatform,
                              lastSelectedPath: _lastSelectedFilePath,
                            ),
                    );
                  });
                },
              ),
            ),
          ),
          // Add the selection rectangle overlay
          _buildDragSelectionOverlay(),
        ],
      );
    } else {
      return Stack(
        children: [
          GestureDetector(
            // Exit selection mode when tapping background
            onTap: () {
              if (_isSelectionMode) {
                _clearSelection();
              }
            },
            // Handle drag selection
            onPanStart: (details) {
              _startDragSelection(details.localPosition);
            },
            onPanUpdate: (details) {
              _updateDragSelection(details.localPosition);
            },
            onPanEnd: (details) {
              _endDragSelection();
            },
            behavior: HitTestBehavior.translucent,
            child: ListView.builder(
              // Add physics for better scrolling performance
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              // Add caching for better scroll performance
              cacheExtent: 500,
              itemCount: state.folders.length + state.files.length,
              itemBuilder: (context, index) {
                // Get path for this item
                final String itemPath = index < state.folders.length
                    ? state.folders[index].path
                    : state.files[index - state.folders.length].path;

                // Wrap with LayoutBuilder to capture item positions
                return LayoutBuilder(builder:
                    (BuildContext context, BoxConstraints constraints) {
                  // Perform post-layout callback to store item position
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final RenderBox? renderBox =
                        context.findRenderObject() as RenderBox?;
                    if (renderBox != null && renderBox.hasSize) {
                      final position = renderBox.localToGlobal(Offset.zero);
                      _registerItemPosition(
                          itemPath,
                          Rect.fromLTWH(position.dx, position.dy,
                              renderBox.size.width, renderBox.size.height));
                    }
                  });

                  // Build the actual item
                  return RepaintBoundary(
                    child: index < state.folders.length
                        ? tab_components.FolderListItem(
                            folder: state.folders[index] as Directory,
                            onNavigate: _navigateToPath,
                            isSelected: _selectedFolderPaths
                                .contains(state.folders[index].path),
                            toggleFolderSelection: _toggleFolderSelection,
                            isDesktopMode: isDesktopPlatform,
                            lastSelectedPath: _lastSelectedFilePath,
                          )
                        : folder_list_components.FileItem(
                            file: state.files[index - state.folders.length]
                                as File,
                            state: state,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedFilePaths.contains(
                                state.files[index - state.folders.length].path),
                            toggleFileSelection: _toggleFileSelection,
                            showDeleteTagDialog: _showDeleteTagDialog,
                            showAddTagToFileDialog: _showAddTagToFileDialog,
                            onFileTap: _onFileTap,
                            isDesktopMode: isDesktopPlatform,
                            lastSelectedPath: _lastSelectedFilePath,
                          ),
                  );
                });
              },
            ),
          ),
          // Add the selection rectangle overlay
          _buildDragSelectionOverlay(),
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
    // Nếu đang ở chế độ chọn file và có file được chọn,
    // truyền danh sách file đã chọn vào dialog quản lý tag
    if (_isSelectionMode && _selectedFilePaths.isNotEmpty) {
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _currentPath,
        selectedFiles: _selectedFilePaths.toList(),
      );
    } else {
      // Nếu không trong chế độ chọn file, hoặc không có file nào được chọn,
      // sử dụng phương thức cũ
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _currentPath,
      );
    }
  }

  void _handleGridZoomChange(int zoomLevel) {
    _folderListBloc.add(SetGridZoom(zoomLevel));
    _saveGridZoomSetting(zoomLevel);
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final int fileCount = _selectedFilePaths.length;
    final int folderCount = _selectedFolderPaths.length;
    final int totalCount = fileCount + folderCount;
    final String itemType = fileCount > 0 && folderCount > 0
        ? 'items'
        : fileCount > 0
            ? 'files'
            : 'folders';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move $totalCount $itemType to trash?'),
        content: const Text(
            'These items will be moved to the trash bin. You can restore them later if needed.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Delete files
              if (fileCount > 0) {
                BlocProvider.of<FolderListBloc>(context)
                    .add(FolderListDeleteFiles(_selectedFilePaths.toList()));
              }

              // Delete folders
              if (folderCount > 0) {
                // For now, handle folder deletion as multiple file deletions
                // In the future, implement a specific event for folder deletion
                for (final folderPath in _selectedFolderPaths) {
                  final folder = Directory(folderPath);
                  try {
                    // Check if folder exists and move to trash
                    if (folder.existsSync()) {
                      final trashManager = TrashManager();
                      trashManager.moveToTrash(folderPath);
                    }
                  } catch (e) {
                    print('Error moving folder to trash: $e');
                  }
                }

                // Refresh the folder list after deletion
                _folderListBloc.add(FolderListLoad(_currentPath));
              }

              Navigator.of(context).pop();
              _clearSelection();
            },
            child: const Text(
              'MOVE TO TRASH',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Tag search dialog and handling

  // Xử lý khi người dùng click vào một file trong kết quả tìm kiếm
  void _onFileTap(File file, bool isVideo) {
    // Stop any ongoing thumbnail processing when opening a file
    VideoThumbnailHelper.stopAllProcessing();

    // Get file extension
    String extension = file.path.split('.').last.toLowerCase();

    // Use lists to check file types
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v'];
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final isVideo = videoExtensions.contains(extension);

    // Open file based on file type
    if (isVideo) {
      // Open video in video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerFullScreen(file: file),
        ),
      );
    } else if (imageExtensions.contains(extension)) {
      // Get all image files in the same directory for gallery navigation
      List<File> imageFiles = [];
      int initialIndex = 0;

      // Only process this if we're showing the folder contents (not search results)
      if (_currentFilter == null &&
          _currentSearchTag == null &&
          _folderListBloc.state.files.isNotEmpty) {
        imageFiles = _folderListBloc.state.files.whereType<File>().where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return imageExtensions.contains(ext);
        }).toList();

        // Find the index of the current file in the imageFiles list
        initialIndex = imageFiles.indexWhere((f) => f.path == file.path);
        if (initialIndex < 0) initialIndex = 0;
      }

      // Open image in our enhanced image viewer with gallery support
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            file: file,
            imageFiles: imageFiles.isNotEmpty ? imageFiles : null,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else {
      // For other file types, open with external app
      // First try to open with the default app
      ExternalAppHelper.openFileWithApp(file.path, 'shell_open')
          .then((success) {
        if (!success) {
          // If that fails, show the open with dialog
          showDialog(
            context: context,
            builder: (context) => OpenWithDialog(filePath: file.path),
          );
        }
      });
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

        // Use direct method call instead of BLoC event
        final String? actualPath =
            tabManagerBloc.backNavigationToPath(widget.tabId);

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

  // Phương thức xử lý thay đổi mức zoom bằng cuộn chuột
  void _handleZoomLevelChange(int direction) {
    // Đảo ngược chiều: tăng zoom khi cuộn xuống (direction > 0), giảm zoom khi cuộn lên (direction < 0)
    final currentZoom = _gridZoomLevel;
    final newZoom = (currentZoom + direction).clamp(
      UserPreferences.minGridZoomLevel,
      UserPreferences.maxGridZoomLevel,
    );

    if (newZoom != currentZoom) {
      _folderListBloc.add(SetGridZoom(newZoom));
      _saveGridZoomSetting(newZoom);
    }
  }

  // Add this method to handle drag selection
  void _startDragSelection(Offset position) {
    if (_isDragging) return;

    setState(() {
      _isDragging = true;
      _dragStartPosition = position;
      _dragCurrentPosition = position;
    });
  }

  void _updateDragSelection(Offset position) {
    if (!_isDragging) return;

    setState(() {
      _dragCurrentPosition = position;
    });

    // Calculate selection rectangle
    final selectionRect =
        Rect.fromPoints(_dragStartPosition!, _dragCurrentPosition!);

    // Check which items are inside the selection rect
    _selectItemsInRect(selectionRect);
  }

  void _endDragSelection() {
    setState(() {
      _isDragging = false;
      _dragStartPosition = null;
      _dragCurrentPosition = null;
    });
  }

  void _selectItemsInRect(Rect selectionRect) {
    // Get keyboard state for modifiers
    final RawKeyboard keyboard = RawKeyboard.instance;
    final bool isCtrlPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.control) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlRight) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.meta) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaRight);

    final bool isShiftPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.shift) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftRight);

    // Create sets for newly selected items
    final Set<String> newSelectedFolderPaths = {};
    final Set<String> newSelectedFilePaths = {};

    // Check which items are inside the selection rect
    _itemPositions.forEach((path, itemRect) {
      if (selectionRect.overlaps(itemRect)) {
        // Check if it's a folder or file
        if (_folderListBloc.state.folders
            .any((folder) => folder.path == path)) {
          newSelectedFolderPaths.add(path);
        } else {
          newSelectedFilePaths.add(path);
        }
      }
    });

    // Handle selection based on keyboard modifiers
    if (isShiftPressed && _lastSelectedFilePath != null) {
      // With Shift, maintain existing selection and add the current range
      // Only clear previous selection if Ctrl is not pressed
      if (!isCtrlPressed) {
        _selectedFilePaths.clear();
        _selectedFolderPaths.clear();
      }

      // If we have a last selected path, try to add range selection logic
      // We'll need a list of all paths in UI order
      final List<String> allFolderPaths =
          _folderListBloc.state.folders.map((f) => f.path).toList();
      final List<String> allFilePaths =
          _folderListBloc.state.files.map((f) => f.path).toList();
      final List<String> allPaths = [...allFolderPaths, ...allFilePaths];

      // Find indices
      final int lastIndex = allPaths.indexOf(_lastSelectedFilePath!);

      // For each item in the drag selection, find the range between it and last selected
      if (lastIndex >= 0) {
        // For each selected item, find its index and select the range
        final Set<String> pathsToSelect = {};

        for (final String path in [
          ...newSelectedFolderPaths,
          ...newSelectedFilePaths
        ]) {
          final int currentIndex = allPaths.indexOf(path);
          if (currentIndex >= 0) {
            // Determine range boundaries (inclusive)
            final int startIndex = min(currentIndex, lastIndex);
            final int endIndex = max(currentIndex, lastIndex);

            // Add all paths in range
            for (int i = startIndex; i <= endIndex; i++) {
              pathsToSelect.add(allPaths[i]);
            }
          }
        }

        // Add all paths from the range to the appropriate collections
        for (final String path in pathsToSelect) {
          if (allFolderPaths.contains(path)) {
            _selectedFolderPaths.add(path);
          } else {
            _selectedFilePaths.add(path);
          }
        }
      }
    } else {
      // Normal selection behavior (no Shift key)
      if (!isCtrlPressed) {
        // If not holding Ctrl, clear previous selection
        _selectedFilePaths.clear();
        _selectedFolderPaths.clear();
      }

      // Update selection sets
      _selectedFolderPaths.addAll(newSelectedFolderPaths);
      _selectedFilePaths.addAll(newSelectedFilePaths);

      // If something was selected, update last selected path
      if (newSelectedFilePaths.isNotEmpty) {
        _lastSelectedFilePath = newSelectedFilePaths.last;
      } else if (newSelectedFolderPaths.isNotEmpty) {
        _lastSelectedFilePath = newSelectedFolderPaths.last;
      }
    }

    // Update selection mode
    _isSelectionMode =
        _selectedFilePaths.isNotEmpty || _selectedFolderPaths.isNotEmpty;

    // Force UI update
    if (!_selectionUpdatePending) {
      _selectionUpdatePending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectionUpdatePending = false;
          });
        }
      });
    }
  }

  // Method to store item positions for drag selection
  void _registerItemPosition(String path, Rect position) {
    _itemPositions[path] = position;
  }

  // Method for building the drag selection rectangle overlay
  Widget _buildDragSelectionOverlay() {
    if (!_isDragging ||
        _dragStartPosition == null ||
        _dragCurrentPosition == null) {
      return const SizedBox.shrink();
    }

    final selectionRect =
        Rect.fromPoints(_dragStartPosition!, _dragCurrentPosition!);

    return Positioned.fromRect(
      rect: selectionRect,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
