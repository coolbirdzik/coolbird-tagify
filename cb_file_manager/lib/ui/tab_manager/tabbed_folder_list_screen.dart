import 'dart:io';
import 'dart:async'; // Add this import for Completer
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

// Import selection bloc
import 'package:cb_file_manager/bloc/selection/selection.dart';

// Import our new components with a clear namespace
import 'components/index.dart' as tab_components;
import 'tab_data.dart'; // Import TabData explicitly
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart'; // Import for TrashManager
import 'package:cb_file_manager/ui/screens/system_screen_router.dart'; // Import SystemScreenRouter

// Add imports for hardware acceleration
import 'package:flutter/rendering.dart' show RendererBinding;
// For scheduler and timeDilation
// Add import for value listenable builder
import 'package:flutter/foundation.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/folder_sort_manager.dart'; // Import for FolderSortManager
import 'package:cb_file_manager/helpers/tag_manager.dart';

// Add this class to cache thumbnails
class ThumbnailCache {
  static final ThumbnailCache _instance = ThumbnailCache._internal();

  factory ThumbnailCache() {
    return _instance;
  }

  ThumbnailCache._internal();

  final Map<String, Image> _cache = {};

  Image? getFromCache(String path) {
    return _cache[path];
  }

  void addToCache(String path, Image image) {
    _cache[path] = image;
  }

  void clearCache() {
    _cache.clear();
  }
}

// Helper class to listen to multiple ValueNotifiers
class ValueListenableBuilder3<A, B, C> extends StatelessWidget {
  final ValueListenable<A> valueListenable1;
  final ValueListenable<B> valueListenable2;
  final ValueListenable<C> valueListenable3;
  final Widget Function(
          BuildContext context, A value1, B value2, C value3, Widget? child)
      builder;
  final Widget? child;

  const ValueListenableBuilder3({
    Key? key,
    required this.valueListenable1,
    required this.valueListenable2,
    required this.valueListenable3,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: valueListenable1,
      builder: (context, value1, _) {
        return ValueListenableBuilder<B>(
          valueListenable: valueListenable2,
          builder: (context, value2, _) {
            return ValueListenableBuilder<C>(
              valueListenable: valueListenable3,
              builder: (context, value3, _) {
                return builder(context, value1, value2, value3, child);
              },
            );
          },
        );
      },
    );
  }
}

// Helper function to determine if we're on desktop
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// A modified version of FolderListScreen that works with the tab system
class TabbedFolderListScreen extends StatefulWidget {
  final String path;
  final String tabId;
  final bool showAppBar; // Thêm tham số để kiểm soát việc hiển thị AppBar
  final String? searchTag; // Add parameter for tag search
  final bool globalTagSearch; // Add parameter to control global vs local search

  const TabbedFolderListScreen({
    Key? key,
    required this.path,
    required this.tabId,
    this.showAppBar = true, // Mặc định là hiển thị AppBar
    this.searchTag, // Optional tag to search for
    this.globalTagSearch = false, // Default to local search
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

  // Replace ValueNotifier with SelectionBloc
  late SelectionBloc _selectionBloc;

  // Trạng thái hiển thị thanh tìm kiếm
  bool _showSearchBar = false;

  // Current path displayed in this tab
  String _currentPath = '';
  // Flag to indicate whether we're in path editing mode

  // View and sort preferences
  late ViewMode _viewMode;
  late int _gridZoomLevel;
  late ColumnVisibility _columnVisibility;

  // Create the bloc instance at the class level
  late FolderListBloc _folderListBloc;

  // Global search toggle for tag search
  bool isGlobalSearch = false;

  // Flag to track if we're handling a path update to avoid duplicate loads
  bool _isHandlingPathUpdate = false;

  // Variables for drag selection
  final Map<String, Rect> _itemPositions = {};

  // Use ValueNotifier for drag selection state to avoid rebuilding the whole screen
  final ValueNotifier<bool> _isDraggingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Offset?> _dragStartPositionNotifier =
      ValueNotifier<Offset?>(null);
  final ValueNotifier<Offset?> _dragCurrentPositionNotifier =
      ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);

    // Set current search tag if provided
    _currentSearchTag = widget.searchTag;

    // Set global search flag if specified
    isGlobalSearch = widget.globalTagSearch;

    // Enable hardware acceleration for smoother animations
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;
    // Replace with platform-optimized settings
    RendererBinding.instance.ensureSemantics();

    // Initialize the blocs
    _folderListBloc = FolderListBloc();

    // Clear cache to ensure fresh results
    TagManager.clearCache();

    // Handle tag search initialization
    if (widget.searchTag != null) {
      debugPrint(
          'TabbedFolderListScreen: Initializing with tag search for "${widget.searchTag}"');
      debugPrint('Global search mode: ${widget.globalTagSearch}');

      // Initialize with tag search
      if (widget.globalTagSearch) {
        // Global tag search - force delay to ensure bloc is properly initialized
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            // Global tag search should be performed without loading a directory first
            _folderListBloc.add(SearchByTagGlobally(widget.searchTag!));

            // Set tag controller text for search bar
            _tagController.text = widget.searchTag!;
          }
        });
      } else {
        // Local tag search within current directory
        _folderListBloc
            .add(FolderListLoad(widget.path)); // First load the directory
        _folderListBloc
            .add(SearchByTag(widget.searchTag!)); // Then search within it

        // Set tag controller text for search bar
        _tagController.text = widget.searchTag!;
      }
    } else {
      // Normal directory loading
      _folderListBloc.add(FolderListLoad(widget.path));
    }

    // Initialize selection bloc
    _selectionBloc = SelectionBloc();

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

    // Only reload if the tab is active AND content is actually missing or outdated
    if (activeTab != null && activeTab.id == widget.tabId) {
      // Check if we actually need to reload
      final currentState = _folderListBloc.state;
      final shouldReload = currentState.currentPath.path != _currentPath ||
          (currentState.folders.isEmpty &&
              currentState.files.isEmpty &&
              !currentState.isLoading);

      if (shouldReload) {
        // Add a small delay to ensure proper state synchronization
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            debugPrint(
                'Tab ${widget.tabId} became active, reloading content for path: $_currentPath');
            _folderListBloc.add(FolderListLoad(_currentPath));
          }
        });
      }
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
    // Clean up resources
    _searchController.dispose();
    _tagController.dispose();
    _pathController.dispose();
    _folderListBloc.close();
    _selectionBloc.close();

    // Dispose of ValueNotifiers
    _isDraggingNotifier.dispose();
    _dragStartPositionNotifier.dispose();
    _dragCurrentPositionNotifier.dispose();

    // Restore default settings
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;

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
      debugPrint('Error saving last accessed folder: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();

      final viewMode = await prefs.getViewMode();
      final sortOption = await prefs.getSortOption();
      final gridZoomLevel = await prefs.getGridZoomLevel();
      final columnVisibility = await prefs.getColumnVisibility();

      if (mounted) {
        setState(() {
          _viewMode = viewMode;
          _gridZoomLevel = gridZoomLevel;
          _columnVisibility = columnVisibility;
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
      debugPrint('Error saving view mode: $e');
    }
  }

  Future<void> _saveSortSetting(SortOption option) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setSortOption(option);
      final folderSortManager = FolderSortManager();
      await folderSortManager.saveFolderSortOption(_currentPath, option);
    } catch (e) {
      debugPrint('Error saving sort option: $e');
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
      debugPrint('Error saving grid zoom level: $e');
    }
  }

  void _toggleSelectionMode({bool? forceValue}) {
    // Use the SelectionBloc
    _selectionBloc.add(ToggleSelectionMode(forceValue: forceValue));
  }

  // Replace the old toggle file selection method
  void _toggleFileSelection(String filePath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    if (!shiftSelect) {
      // Simple selection, use the SelectionBloc directly
      _selectionBloc.add(ToggleFileSelection(
        filePath,
        shiftSelect: shiftSelect,
        ctrlSelect: ctrlSelect,
      ));
    } else {
      // Range selection requires knowledge of all items in current view
      // Get the current selection state
      final selectionState = _selectionBloc.state;

      // If no last selected path, treat as normal selection
      if (selectionState.lastSelectedPath == null) {
        _selectionBloc.add(ToggleFileSelection(
          filePath,
          shiftSelect: false,
          ctrlSelect: ctrlSelect,
        ));
        return;
      }

      // Get lists of all paths for selection range
      final List<String> allFolderPaths =
          _folderListBloc.state.folders.map((f) => f.path).toList();
      final List<String> allFilePaths =
          _folderListBloc.state.files.map((f) => f.path).toList();
      final List<String> allPaths = [...allFolderPaths, ...allFilePaths];

      // Find indices
      final int currentIndex = allPaths.indexOf(filePath);
      final int lastIndex = allPaths.indexOf(selectionState.lastSelectedPath!);

      if (currentIndex != -1 && lastIndex != -1) {
        // Calculate the range
        final Set<String> filesToSelect = {};
        final Set<String> foldersToSelect = {};

        final int startIndex = min(currentIndex, lastIndex);
        final int endIndex = max(currentIndex, lastIndex);

        // Add all items in the range to appropriate sets
        for (int i = startIndex; i <= endIndex; i++) {
          final String pathInRange = allPaths[i];
          if (allFolderPaths.contains(pathInRange)) {
            foldersToSelect.add(pathInRange);
          } else {
            filesToSelect.add(pathInRange);
          }
        }

        // Send bulk selection event
        _selectionBloc.add(SelectItemsInRect(
          folderPaths: foldersToSelect,
          filePaths: filesToSelect,
          isCtrlPressed: ctrlSelect,
          isShiftPressed: true,
        ));
      }
    }
  }

  // Replace the old toggle folder selection method
  void _toggleFolderSelection(String folderPath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    if (!shiftSelect) {
      // Simple selection, use the SelectionBloc directly
      _selectionBloc.add(ToggleFolderSelection(
        folderPath,
        shiftSelect: shiftSelect,
        ctrlSelect: ctrlSelect,
      ));
    } else {
      // Range selection requires knowledge of all items in current view
      // Get the current selection state
      final selectionState = _selectionBloc.state;

      // If no last selected path, treat as normal selection
      if (selectionState.lastSelectedPath == null) {
        _selectionBloc.add(ToggleFolderSelection(
          folderPath,
          shiftSelect: false,
          ctrlSelect: ctrlSelect,
        ));
        return;
      }

      // Get lists of all paths for selection range
      final List<String> allFolderPaths =
          _folderListBloc.state.folders.map((f) => f.path).toList();
      final List<String> allFilePaths =
          _folderListBloc.state.files.map((f) => f.path).toList();
      final List<String> allPaths = [...allFolderPaths, ...allFilePaths];

      // Find indices
      final int currentIndex = allPaths.indexOf(folderPath);
      final int lastIndex = allPaths.indexOf(selectionState.lastSelectedPath!);

      if (currentIndex != -1 && lastIndex != -1) {
        // Calculate the range
        final Set<String> filesToSelect = {};
        final Set<String> foldersToSelect = {};

        final int startIndex = min(currentIndex, lastIndex);
        final int endIndex = max(currentIndex, lastIndex);

        // Add all items in the range to appropriate sets
        for (int i = startIndex; i <= endIndex; i++) {
          final String pathInRange = allPaths[i];
          if (allFolderPaths.contains(pathInRange)) {
            foldersToSelect.add(pathInRange);
          } else {
            filesToSelect.add(pathInRange);
          }
        }

        // Send bulk selection event
        _selectionBloc.add(SelectItemsInRect(
          folderPaths: foldersToSelect,
          filePaths: filesToSelect,
          isCtrlPressed: ctrlSelect,
          isShiftPressed: true,
        ));
      }
    }
  }

  // Replace the old clear selection method
  void _clearSelection() {
    // Use the SelectionBloc
    _selectionBloc.add(ClearSelection());
  }

  void _toggleViewMode() {
    setState(() {
      // Cycle through view modes: list -> grid -> details -> list
      if (_viewMode == ViewMode.list) {
        _viewMode = ViewMode.grid;
      } else if (_viewMode == ViewMode.grid) {
        _viewMode = ViewMode.details;
      } else {
        _viewMode = ViewMode.list;
      }
    });

    _folderListBloc.add(SetViewMode(_viewMode));
    _saveViewModeSetting(_viewMode);
  }

  // Add new method to switch directly to a specific view mode
  void _setViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
    });

    _folderListBloc.add(SetViewMode(_viewMode));
    _saveViewModeSetting(_viewMode);
  }

  void _refreshFileList() {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang làm mới...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Đặt cờ để đánh dấu đang trong quá trình refresh
    bool isRefreshing = true;

    // Xóa cache hình ảnh của Flutter
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Check if this is a system path (starts with #)
    if (_currentPath.startsWith('#')) {
      // For system paths, we need special handling
      if (_currentPath == '#tags') {
        // For tag management screen
        TagManager.clearCache();
        // Clear the system screen router cache for this path
        SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);
        // Reload tag management data (will be handled by the component)
      } else if (_currentPath.startsWith('#tag:')) {
        // For tag search screens, extract the tag and re-run the search
        final tag = _currentPath.substring(5); // Remove "#tag:" prefix
        TagManager.clearCache();
        // Clear the system screen router cache for this path
        SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);
        _folderListBloc.add(SearchByTagGlobally(tag));
      }
    } else {
      // For regular paths, reload with thumbnail regeneration
      _folderListBloc.add(FolderListRefresh(_currentPath));
    }

    // Thiết lập thời gian chờ cố định 3 giây (đủ để đảm bảo hoàn tất các thao tác trên UI)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && isRefreshing) {
        isRefreshing = false;
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
                'Đã hoàn tất làm mới. Một số dữ liệu có thể cần thời gian để cập nhật.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
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
      _folderListBloc.add(const ClearSearchAndFilters());
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
      });
      return;
    }

    // Check if path exists
    final directory = Directory(path);
    directory.exists().then((exists) {
      if (exists) {
        _navigateToPath(path);
        setState(() {});
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

    // First check if we're currently showing search results
    final folderListState = _folderListBloc.state;
    if (folderListState.isSearchActive) {
      // Clear search results and reload current directory
      _folderListBloc.add(const ClearSearchAndFilters());
      _folderListBloc.add(FolderListLoad(_currentPath));
      return false; // Don't exit app, we cleared the search
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

    // Stop any ongoing thumbnail processing to prevent UI lag
    VideoThumbnailHelper.stopAllProcessing();

    _isHandlingPathUpdate = true;

    setState(() {
      _currentPath = newPath;
      _pathController.text = newPath;
    });

    // Clear any search or filter state when navigating
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(const ClearSearchAndFilters());
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
    return BlocProvider.value(
      value: _selectionBloc,
      child: BlocListener<TabManagerBloc, TabManagerState>(
        listener: (context, tabManagerState) {
          // Find the current tab data
          final currentTab = tabManagerState.tabs.firstWhere(
            (tab) => tab.id == widget.tabId,
            orElse: () => TabData(id: '', name: '', path: ''),
          );

          // If the tab's path has changed and is different from our current path, update it
          if (currentTab.id.isNotEmpty && currentTab.path != _currentPath) {
            debugPrint(
                'Tab path updated from $_currentPath to ${currentTab.path}');
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

                return _buildWithSelectionState(context, state);
              }),
            ),
          ),
        ),
      ),
    );
  }

  // New helper method that builds the UI with selection state from BLoC
  Widget _buildWithSelectionState(
      BuildContext context, FolderListState folderListState) {
    return BlocBuilder<SelectionBloc, SelectionState>(
        builder: (context, selectionState) {
      // Create actions for the app bar
      List<Widget> actions = [];
      actions.addAll(!selectionState.isSelectionMode
          ? SharedActionBar.buildCommonActions(
              context: context,
              onSearchPressed: () => _showSearchTip(context),
              onSortOptionSelected: (SortOption option) {
                _folderListBloc.add(SetSortOption(option));
                _saveSortSetting(option);
              },
              currentSortOption: folderListState.sortOption,
              viewMode: folderListState.viewMode,
              onViewModeToggled: _toggleViewMode,
              onViewModeSelected: _setViewMode,
              onRefresh: _refreshFileList,
              onGridSizePressed: folderListState.viewMode == ViewMode.grid
                  ? () => SharedActionBar.showGridSizeDialog(
                        context,
                        currentGridSize: folderListState.gridZoomLevel,
                        onApply: _handleGridZoomChange,
                      )
                  : null,
              onColumnSettingsPressed:
                  folderListState.viewMode == ViewMode.details
                      ? () {
                          _showColumnVisibilityDialog(context);
                        }
                      : null,
              onSelectionModeToggled: _toggleSelectionMode,
              onManageTagsPressed: () {
                tab_components.showManageTagsDialog(
                    context,
                    folderListState.allTags.toList(),
                    folderListState.currentPath.path);
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
            )
          : []);

      // If we're in selection mode, show a custom app bar
      if (selectionState.isSelectionMode) {
        return Scaffold(
          appBar: tab_components.SelectionAppBar(
            // Pass the explicit count to ensure consistency
            selectedCount: selectionState.selectedCount,
            // Pass detailed counts for better information
            selectedFileCount: selectionState.selectedFilePaths.length,
            selectedFolderCount: selectionState.selectedFolderPaths.length,
            onClearSelection: _clearSelection,
            selectedFilePaths: selectionState.selectedFilePaths.toList(),
            selectedFolderPaths: selectionState.selectedFolderPaths.toList(),
            showRemoveTagsDialog: _showRemoveTagsDialog,
            showManageAllTagsDialog: (context) =>
                _showManageAllTagsDialog(context),
            showDeleteConfirmationDialog: (context) =>
                _showDeleteConfirmationDialog(context),
          ),
          body: _buildBody(context, folderListState, selectionState),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              tab_components.showBatchAddTagDialog(
                  context, selectionState.selectedFilePaths.toList());
            },
            child: const Icon(EvaIcons.shoppingBag),
          ),
        );
      }

      // Note: We're not using BaseScreen here since we're already inside a tab
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                automaticallyImplyLeading: false, // Tắt nút back tự động
                title: _showSearchBar
                    ? tab_components.SearchBar(
                        currentPath: _currentPath,
                        tabId: widget.tabId,
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
        body: _buildBody(context, folderListState, selectionState),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleSelectionMode,
          child: const Icon(EvaIcons.checkmarkSquare2Outline),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, FolderListState state,
      SelectionState selectionState) {
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
          isSelectionMode: selectionState.isSelectionMode,
          selectedFiles: selectionState.selectedFilePaths.toList(),
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(EvaIcons.search, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.emptyFolder,
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
        folders: const [], // No folders in filtered view
        state: state,
        isSelectionMode: selectionState.isSelectionMode,
        isGridView: state.viewMode == ViewMode.grid,
        selectedFiles: selectionState.selectedFilePaths.toList(),
        toggleFileSelection: _toggleFileSelection,
        toggleSelectionMode: _toggleSelectionMode,
        showDeleteTagDialog: _showDeleteTagDialog,
        showAddTagToFileDialog: _showAddTagToFileDialog,
      );
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.emptyFolder,
            style: TextStyle(fontSize: 18)),
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

        // Check if this is a system path (starts with #)
        if (_currentPath.startsWith('#')) {
          // For system paths, we need special handling
          if (_currentPath == '#tags') {
            // For tag management screen
            TagManager.clearCache();
            // Clear the system screen router cache for this path
            SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);
            // Notify completion after a short delay since there's no explicit loading state
            Future.delayed(const Duration(milliseconds: 500), () {
              completer.complete();
            });
          } else if (_currentPath.startsWith('#tag:')) {
            // For tag search screens, extract the tag and re-run the search
            final tag = _currentPath.substring(5); // Remove "#tag:" prefix
            TagManager.clearCache();
            // Clear the system screen router cache for this path
            SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);
            _folderListBloc.add(SearchByTagGlobally(tag));
            // Completion will be triggered by the listener above
          }
        } else {
          // Use FolderListRefresh instead of FolderListLoad to force thumbnail regeneration
          VideoThumbnailHelper.trimCache();
          _folderListBloc.add(
              FolderListRefresh(_currentPath, forceRegenerateThumbnails: true));
        }

        // Wait for the loading to complete before returning
        return completer.future;
      },
      child: _buildFolderAndFileList(state),
    );
  }

  Widget _buildFolderAndFileList(FolderListState state) {
    // Apply frame timing optimizations before heavy list/grid operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    // Use separate builders for each view type to prevent complete tree rebuilds
    if (state.viewMode == ViewMode.grid) {
      return _buildGridView(state);
    } else if (state.viewMode == ViewMode.details) {
      return _buildDetailsView(state);
    } else {
      return _buildListView(state);
    }
  }

  // Separated grid view builder for better isolation
  Widget _buildGridView(FolderListState state) {
    return Stack(
      // Use clipBehavior to ensure the selection rectangle is properly contained
      clipBehavior: Clip.none,
      children: [
        BlocBuilder<SelectionBloc, SelectionState>(
          builder: (context, selectionState) {
            // Access selection state directly from BLoC
            return GestureDetector(
              // Exit selection mode when tapping background
              onTap: () {
                if (selectionState.isSelectionMode) {
                  _clearSelection();
                }
              },
              // Handle right-click for context menu
              onSecondaryTapUp: (details) {
                _showContextMenu(context, details.globalPosition);
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
                child: RepaintBoundary(
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
                      childAspectRatio: 0.8,
                    ),
                    itemCount: state.folders.length + state.files.length,
                    itemBuilder: (context, index) {
                      // Get path for this item
                      final String itemPath = index < state.folders.length
                          ? state.folders[index].path
                          : state.files[index - state.folders.length].path;

                      // Determine selection state once
                      final bool isSelected =
                          selectionState.isPathSelected(itemPath);

                      // Wrap with LayoutBuilder to capture item positions
                      return LayoutBuilder(builder:
                          (BuildContext context, BoxConstraints constraints) {
                        // Register item position code...
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final RenderBox? renderBox =
                              context.findRenderObject() as RenderBox?;
                          if (renderBox != null && renderBox.hasSize) {
                            final position =
                                renderBox.localToGlobal(Offset.zero);
                            _registerItemPosition(
                                itemPath,
                                Rect.fromLTWH(
                                    position.dx,
                                    position.dy,
                                    renderBox.size.width,
                                    renderBox.size.height));
                          }
                        });

                        if (index < state.folders.length) {
                          final folder = state.folders[index] as Directory;
                          return KeyedSubtree(
                            key: ValueKey('folder-grid-${folder.path}'),
                            child: RepaintBoundary(
                              child: folder_list_components.FolderGridItem(
                                key:
                                    ValueKey('folder-grid-item-${folder.path}'),
                                folder: folder,
                                onNavigate: _navigateToPath,
                                isSelected: isSelected,
                                toggleFolderSelection: _toggleFolderSelection,
                                isDesktopMode: isDesktopPlatform,
                                lastSelectedPath:
                                    selectionState.lastSelectedPath,
                                clearSelectionMode: _clearSelection,
                              ),
                            ),
                          );
                        } else {
                          final file =
                              state.files[index - state.folders.length] as File;
                          return KeyedSubtree(
                            key: ValueKey('file-grid-${file.path}'),
                            child: RepaintBoundary(
                              child: folder_list_components.FileGridItem(
                                key: ValueKey('file-grid-item-${file.path}'),
                                file: file,
                                state: state,
                                isSelectionMode: selectionState.isSelectionMode,
                                isSelected: isSelected,
                                toggleFileSelection: _toggleFileSelection,
                                toggleSelectionMode: _toggleSelectionMode,
                                onFileTap: _onFileTap,
                                isDesktopMode: isDesktopPlatform,
                                lastSelectedPath:
                                    selectionState.lastSelectedPath,
                              ),
                            ),
                          );
                        }
                      });
                    },
                  ),
                ),
              ),
            );
          },
        ),
        // Add the selection rectangle overlay
        _buildDragSelectionOverlay(),
      ],
    );
  }

  // Separated details view builder for better isolation
  Widget _buildDetailsView(FolderListState state) {
    return Stack(
      // Use clipBehavior to ensure the selection rectangle is properly contained
      clipBehavior: Clip.none,
      children: [
        BlocBuilder<SelectionBloc, SelectionState>(
          builder: (context, selectionState) {
            return GestureDetector(
              // Exit selection mode when tapping background
              onTap: () {
                if (selectionState.isSelectionMode) {
                  _clearSelection();
                }
              },
              // Handle right-click for context menu
              onSecondaryTapUp: (details) {
                _showContextMenu(context, details.globalPosition);
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
              child: RepaintBoundary(
                child: folder_list_components.FileView(
                  files: state.files.whereType<File>().toList(),
                  folders: state.folders.whereType<Directory>().toList(),
                  state: state,
                  isSelectionMode: selectionState.isSelectionMode,
                  isGridView: false, // Not grid view
                  selectedFiles: selectionState.allSelectedPaths,
                  toggleFileSelection: _toggleFileSelection,
                  toggleSelectionMode: _toggleSelectionMode,
                  showDeleteTagDialog: _showDeleteTagDialog,
                  showAddTagToFileDialog: _showAddTagToFileDialog,
                  onFolderTap: _navigateToPath,
                  onFileTap: _onFileTap,
                  isDesktopMode: isDesktopPlatform,
                  lastSelectedPath: selectionState.lastSelectedPath,
                  columnVisibility: _columnVisibility,
                ),
              ),
            );
          },
        ),
        // Add the selection rectangle overlay
        _buildDragSelectionOverlay(),
      ],
    );
  }

  // Separated list view builder for better isolation
  Widget _buildListView(FolderListState state) {
    return Stack(
      // Use clipBehavior to ensure the selection rectangle is properly contained
      clipBehavior: Clip.none,
      children: [
        BlocBuilder<SelectionBloc, SelectionState>(
          builder: (context, selectionState) {
            return GestureDetector(
              // Exit selection mode when tapping background
              onTap: () {
                if (selectionState.isSelectionMode) {
                  _clearSelection();
                }
              },
              // Handle right-click for context menu
              onSecondaryTapUp: (details) {
                _showContextMenu(context, details.globalPosition);
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
              child: RepaintBoundary(
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

                    // Determine selection state once
                    final bool isSelected =
                        selectionState.isPathSelected(itemPath);

                    // Wrap with LayoutBuilder to capture item positions
                    return LayoutBuilder(builder:
                        (BuildContext context, BoxConstraints constraints) {
                      // Register item position code...
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

                      if (index < state.folders.length) {
                        final folder = state.folders[index] as Directory;
                        return KeyedSubtree(
                          key: ValueKey("folder-${folder.path}"),
                          child: RepaintBoundary(
                            child: folder_list_components.FolderItem(
                              key: ValueKey("folder-item-${folder.path}"),
                              folder: folder,
                              onTap: _navigateToPath,
                              isSelected: isSelected,
                              toggleFolderSelection: _toggleFolderSelection,
                              isDesktopMode: isDesktopPlatform,
                              lastSelectedPath: selectionState.lastSelectedPath,
                            ),
                          ),
                        );
                      } else {
                        final file =
                            state.files[index - state.folders.length] as File;
                        return KeyedSubtree(
                          key: ValueKey("file-${file.path}"),
                          child: RepaintBoundary(
                            child: folder_list_components.FileItem(
                              key: ValueKey("file-item-${file.path}"),
                              file: file,
                              state: state,
                              isSelectionMode: selectionState.isSelectionMode,
                              isSelected: isSelected,
                              toggleFileSelection: _toggleFileSelection,
                              showDeleteTagDialog: _showDeleteTagDialog,
                              showAddTagToFileDialog: _showAddTagToFileDialog,
                              onFileTap: _onFileTap,
                              isDesktopMode: isDesktopPlatform,
                              lastSelectedPath: selectionState.lastSelectedPath,
                            ),
                          ),
                        );
                      }
                    });
                  },
                ),
              ),
            );
          },
        ),
        // Add the selection rectangle overlay
        _buildDragSelectionOverlay(),
      ],
    );
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
    // Use the SelectionBloc to get current selection state
    final selectionState = context.read<SelectionBloc>().state;

    // Use the selected file paths from the SelectionBloc state
    tab_components.showRemoveTagsDialog(
        context, selectionState.selectedFilePaths.toList());
  }

  void _showManageAllTagsDialog(BuildContext context) {
    // Use the SelectionBloc to get current selection state
    final selectionState = context.read<SelectionBloc>().state;

    if (selectionState.isSelectionMode &&
        selectionState.selectedFilePaths.isNotEmpty) {
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _currentPath,
        selectedFiles: selectionState.selectedFilePaths.toList(),
      );
    } else {
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _currentPath,
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    // Use the SelectionBloc to get current selection state
    final selectionState = context.read<SelectionBloc>().state;

    final int fileCount = selectionState.selectedFilePaths.length;
    final int folderCount = selectionState.selectedFolderPaths.length;
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
                BlocProvider.of<FolderListBloc>(context).add(
                    FolderListDeleteFiles(
                        selectionState.selectedFilePaths.toList()));
              }

              // Delete folders
              if (folderCount > 0) {
                for (final folderPath in selectionState.selectedFolderPaths) {
                  final folder = Directory(folderPath);
                  try {
                    // Check if folder exists and move to trash
                    if (folder.existsSync()) {
                      final trashManager = TrashManager();
                      trashManager.moveToTrash(folderPath);
                    }
                  } catch (e) {
                    debugPrint('Error moving folder to trash: $e');
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

  void _handleGridZoomChange(int zoomLevel) {
    _folderListBloc.add(SetGridZoom(zoomLevel));
    _saveGridZoomSetting(zoomLevel);
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
    // First check if we're currently showing search results
    final folderListState = _folderListBloc.state;
    if (folderListState.isSearchActive) {
      // Clear search results and reload current directory
      _folderListBloc.add(const ClearSearchAndFilters());
      _folderListBloc.add(FolderListLoad(_currentPath));
      return; // Don't navigate back, we're just clearing the search
    }

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
        tabManagerBloc.backNavigationToPath(widget.tabId);

        // Load the folder content
        _folderListBloc.add(FolderListLoad(previousPath));
      }
    }
  }

  // Show context menu for the folder
  void _showContextMenu(BuildContext context, Offset position) {
    tab_components.FolderContextMenu.show(
      context: context,
      globalPosition: position, // Pass the global position
      folderListBloc: _folderListBloc,
      currentPath: _currentPath,
      currentViewMode: _folderListBloc.state.viewMode,
      currentSortOption: _folderListBloc.state.sortOption,
      onViewModeChanged: _setViewMode,
      onRefresh: _refreshFileList,
      onCreateFolder: (String folderName) async {
        final String newFolderPath =
            '$_currentPath${Platform.pathSeparator}$folderName';

        final directory = Directory(newFolderPath);
        try {
          await directory.create();
          _folderListBloc.add(FolderListLoad(_currentPath));
        } catch (error) {
          if (mounted) {
            // Check if the widget is still in the tree
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating folder: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onSortOptionSaved:
          _saveSortSetting, // Pass the existing save sort setting method
    );
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

  // Methods for drag selection
  void _startDragSelection(Offset position) {
    if (_isDraggingNotifier.value) return;

    _isDraggingNotifier.value = true;
    _dragStartPositionNotifier.value = position;
    _dragCurrentPositionNotifier.value = position;
  }

  void _updateDragSelection(Offset position) {
    if (!_isDraggingNotifier.value) return;

    _dragCurrentPositionNotifier.value = position;

    // Calculate selection rectangle
    if (_dragStartPositionNotifier.value != null) {
      final selectionRect = Rect.fromPoints(_dragStartPositionNotifier.value!,
          _dragCurrentPositionNotifier.value!);

      // Select items in the rectangle using SelectionBloc
      _selectItemsInRect(selectionRect);
    }
  }

  void _endDragSelection() {
    _isDraggingNotifier.value = false;
    _dragStartPositionNotifier.value = null;
    _dragCurrentPositionNotifier.value = null;
  }

  // Method to store item positions for drag selection
  void _registerItemPosition(String path, Rect position) {
    _itemPositions[path] = position;
  }

  // Method for building the drag selection rectangle overlay using ValueListenableBuilder
  Widget _buildDragSelectionOverlay() {
    return ValueListenableBuilder3<bool, Offset?, Offset?>(
      valueListenable1: _isDraggingNotifier,
      valueListenable2: _dragStartPositionNotifier,
      valueListenable3: _dragCurrentPositionNotifier,
      builder: (context, isDragging, startPosition, currentPosition, _) {
        if (!isDragging || startPosition == null || currentPosition == null) {
          return const SizedBox.shrink();
        }

        final selectionRect = Rect.fromPoints(startPosition, currentPosition);

        // Use CustomPaint with our selection painter to draw the rectangle
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SelectionRectanglePainter(
                selectionRect: selectionRect,
                // Use the same color as folder selection (primaryContainer with 0.7 opacity)
                fillColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.4),
                borderColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  // Method to show column visibility dialog
  void _showColumnVisibilityDialog(BuildContext context) {
    SharedActionBar.showColumnVisibilityDialog(
      context,
      currentVisibility: _columnVisibility,
      onApply: (ColumnVisibility visibility) async {
        setState(() {
          _columnVisibility = visibility;
        });

        try {
          final UserPreferences prefs = UserPreferences.instance;
          await prefs.init();
          await prefs.setColumnVisibility(visibility);
        } catch (e) {
          debugPrint('Error saving column visibility: $e');
        }
      },
    );
  }

  // Helper method for drag selection - uses SelectionBloc
  void _selectItemsInRect(Rect selectionRect) {
    if (!_isDraggingNotifier.value) return;

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

    // Create temporary sets for selection
    final Set<String> selectedFoldersInDrag = {};
    final Set<String> selectedFilesInDrag = {};

    // Find items in the rectangle
    _itemPositions.forEach((path, itemRect) {
      if (selectionRect.overlaps(itemRect)) {
        if (_folderListBloc.state.folders
            .any((folder) => folder.path == path)) {
          selectedFoldersInDrag.add(path);
        } else {
          selectedFilesInDrag.add(path);
        }
      }
    });

    // Use SelectionBloc to update selection state
    _selectionBloc.add(SelectItemsInRect(
      folderPaths: selectedFoldersInDrag,
      filePaths: selectedFilesInDrag,
      isCtrlPressed: isCtrlPressed,
      isShiftPressed: isShiftPressed,
    ));
  }
}

// Add a custom painter for the selection rectangle
class SelectionRectanglePainter extends CustomPainter {
  final Rect selectionRect;
  final Color fillColor;
  final Color borderColor;

  SelectionRectanglePainter({
    required this.selectionRect,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Make border slightly thicker for better visibility

    // Draw the fill
    canvas.drawRect(selectionRect, fillPaint);

    // Draw the border
    canvas.drawRect(selectionRect, borderPaint);
  }

  @override
  bool shouldRepaint(SelectionRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
