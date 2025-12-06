import 'dart:io';
import 'dart:async'; // Add this import for Completer
import 'dart:math'; // For math operations with drag selection and min/max functions

import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
// Add this import
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart'; // Import the new ImageViewerScreen
import '../../components/common/shared_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add for HapticFeedback and keyboard keys
// Add for scheduler bindings
import 'package:flutter/gestures.dart'; // Import for mouse buttons
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart'; // Add import for VideoThumbnailHelper
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart'; // Add import for ThumbnailLoader
import 'package:cb_file_manager/ui/widgets/loading_skeleton.dart';
import 'package:cb_file_manager/ui/widgets/app_progress_indicator.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import 'tab_manager.dart';
import 'package:cb_file_manager/ui/utils/fluent_background.dart'; // Import the Fluent Design background

// Import folder list components with explicit alias
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';
import '../../screens/folder_list/folder_list_state.dart';
import '../../screens/folder_list/components/index.dart'
    as folder_list_components;

// Import selection bloc
import 'package:cb_file_manager/bloc/selection/selection.dart';

// Import our new components with a clear namespace
import '../components/index.dart' as tab_components;
import '../components/address_bar_menu.dart';
import 'tab_data.dart'; // Import TabData explicitly
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/files/external_app_helper.dart';
import 'package:cb_file_manager/helpers/files/trash_manager.dart'; // Import for TrashManager
import 'package:cb_file_manager/ui/screens/system_screen_router.dart'; // Import SystemScreenRouter

// Add imports for hardware acceleration
// For scheduler and timeDilation
// Add import for value listenable builder
import 'package:flutter/foundation.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/files/folder_sort_manager.dart'; // Import for FolderSortManager
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import '../../components/common/screen_scaffold.dart';
import '../../utils/route.dart';
import '../mobile/mobile_file_actions_controller.dart';

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

  // Add flag for lazy loading drives
  bool _isLazyLoadingDrives = false;

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
  late bool _showFileTags;

  // Refresh state
  bool _isRefreshing = false;

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

  // Keyboard navigation state (desktop)
  final FocusNode _keyboardFocusNode =
      FocusNode(debugLabel: 'folder-list-keyboard');
  String? _focusedPath;

  // Flag to track if there are background thumbnail tasks
  bool _hasPendingThumbnails = false;
  bool _hasAnyContentLoaded =
      false; // Track if any content has been shown to avoid empty flicker

  // Add a method to check if there are any video/image files in the current state
  bool _hasVideoOrImageFiles(FolderListState state) {
    return state.files.any((file) => FileTypeUtils.isMediaFile(file.path));
  }

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;
    _searchController = TextEditingController();
    _tagController = TextEditingController();
    _pathController = TextEditingController(text: _currentPath);

    // If this is a new tab with empty path (drive view), enable lazy loading
    if (_currentPath.isEmpty && Platform.isWindows) {
      _isLazyLoadingDrives = true;
      // Schedule drive loading after UI is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startLazyLoadingDrives();
      });
    }

    // Set current search tag if provided

    // Listen for thumbnail loading changes
    ThumbnailLoader.onPendingTasksChanged.listen((count) {
      final hasBackgroundTasks = count > 0;
      if (_hasPendingThumbnails != hasBackgroundTasks) {
        setState(() {
          _hasPendingThumbnails = hasBackgroundTasks;
        });
      }
    });
    _currentSearchTag = widget.searchTag;

    // Set global search flag if specified
    isGlobalSearch = widget.globalTagSearch;

    // Enable hardware acceleration for smoother animations
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;
    // Avoid forcing semantics here to prevent render/semantics assertions on mobile

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
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_folderListBloc.isClosed) {
            // Global tag search should be performed without loading a directory first
            _folderListBloc.add(SearchByTagGlobally(widget.searchTag!));

            // Set tag controller text for search bar
            _tagController.text = widget.searchTag!;
          }
        });
      } else {
        // Local tag search within current directory
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_folderListBloc.isClosed) {
            _folderListBloc
                .add(FolderListLoad(widget.path)); // First load the directory
            _folderListBloc
                .add(SearchByTag(widget.searchTag!)); // Then search within it
          }
        });

        // Set tag controller text for search bar
        _tagController.text = widget.searchTag!;
      }
    } else if (widget.path.startsWith('#search?tag=')) {
      // Handle search path with tag parameter
      final tag = widget.path.split('tag=')[1];
      debugPrint('TabbedFolderListScreen: Handling search path with tag: $tag');

      // Set tag controller text for search bar
      _tagController.text = tag;

      // Set search mode to global tag search
      isGlobalSearch = true;
      _currentSearchTag = tag;

      // Perform global tag search
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_folderListBloc.isClosed) {
          _folderListBloc.add(SearchByTagGlobally(tag));
        }
      });
    } else {
      // Normal directory loading - clear any existing filters first
      _folderListBloc.add(const ClearSearchAndFilters());
      _folderListBloc.add(FolderListLoad(widget.path));
    }

    // Initialize selection bloc
    _selectionBloc = SelectionBloc();

    _saveLastAccessedFolder();

    // Load preferences
    _loadPreferences();

    // Register mobile file actions controller for mobile UI
    if (Platform.isAndroid || Platform.isIOS) {
      _registerMobileActionsController();
    }
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
              currentState.searchResults.isEmpty &&
              !currentState.isLoading &&
              !_currentPath.startsWith('#search?tag='));

      if (shouldReload) {
        // Add a small delay to ensure proper state synchronization
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            debugPrint(
                'Tab ${widget.tabId} became active, reloading content for path: $_currentPath');

            // Don't try to load search paths as directories
            if (_currentPath.startsWith('#search?tag=')) {
              debugPrint(
                  'Skipping directory load for search path: $_currentPath');
              return;
            }

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
    _keyboardFocusNode.dispose();

    // Restore default settings
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = true;

    // Remove mobile actions controller
    if (Platform.isAndroid || Platform.isIOS) {
      MobileFileActionsController.removeTab(widget.tabId);
    }

    super.dispose();
  }

  // Register mobile actions controller to connect mobile action buttons with this screen
  void _registerMobileActionsController() {
    final controller = MobileFileActionsController.forTab(widget.tabId);

    // Register callbacks
    controller.onSearchPressed = () => _showSearchTip(context);
    controller.onSearchSubmitted = (query) => _handleMobileSearch(query);
    controller.onSortOptionSelected = (option) {
      _folderListBloc.add(SetSortOption(option));
      _saveSortSetting(option);
    };
    controller.onViewModeToggled = _setViewMode;
    controller.onRefresh = _refreshFileList;
    controller.onGridSizePressed = () => SharedActionBar.showGridSizeDialog(
          context,
          currentGridSize: _folderListBloc.state.gridZoomLevel,
          onApply: _handleGridZoomChange,
        );
    controller.onSelectionModeToggled = _toggleSelectionMode;
    controller.onManageTagsPressed = () {
      tab_components.showManageTagsDialog(
        context,
        _folderListBloc.state.allTags.toList(),
        _folderListBloc.state.currentPath.path,
      );
    };
    controller.onGallerySelected = (value) {
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
    };

    // Set initial state
    controller.currentSortOption = _folderListBloc.state.sortOption;
    controller.currentViewMode = _folderListBloc.state.viewMode;
    controller.currentGridSize = _folderListBloc.state.gridZoomLevel;
    controller.currentPath = _currentPath;

    // Update controller state when bloc state changes
    _folderListBloc.stream.listen((state) {
      controller.currentSortOption = state.sortOption;
      controller.currentViewMode = state.viewMode;
      controller.currentGridSize = state.gridZoomLevel;
      controller.currentPath = state.currentPath.path;
    });
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
      final showFileTags = await prefs.getShowFileTags();

      if (mounted) {
        setState(() {
          _viewMode = viewMode;
          _gridZoomLevel = gridZoomLevel;
          _columnVisibility = columnVisibility;
          _showFileTags = showFileTags;
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
    _focusedPath = null;
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

    // Update mobile controller state
    final controller = MobileFileActionsController.forTab(widget.tabId);
    controller.currentViewMode = mode;
  }

  void _refreshFileList() {
    setState(() {
      _isRefreshing = true;
    });

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
      } else if (_currentPath.startsWith('#network/')) {
        // Network special paths (#network/TYPE/...) – clear widget cache and reload
        SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);

        // Force TabManager to re-set the same path to trigger rebuild
        context
            .read<TabManagerBloc>()
            .add(UpdateTabPath(widget.tabId, _currentPath));

        // If this screen still uses FolderList, trigger bloc refresh to regenerate thumbnails
        _folderListBloc.add(
            FolderListRefresh(_currentPath, forceRegenerateThumbnails: true));
      }
    } else {
      // For regular paths, reload with thumbnail regeneration
      _folderListBloc.add(FolderListRefresh(_currentPath));
    }

    // Thiết lập thời gian chờ cố định 3 giây (đủ để đảm bảo hoàn tất các thao tác trên UI)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && isRefreshing) {
        isRefreshing = false;
        setState(() {
          _isRefreshing = false;
        });
      }
    });

    // Thiết lập timeout dài hơn để đảm bảo không bị kẹt
    Future.delayed(const Duration(seconds: 15), () {
      // Đảm bảo không hiển thị thông báo hai lần
      if (mounted && isRefreshing) {
        isRefreshing = false;
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  // Handle mobile inline search
  void _handleMobileSearch(String? query) {
    if (query == null || query.isEmpty) {
      // Clear search
      _folderListBloc.add(const ClearSearchAndFilters());
      return;
    }

    // Get recursive setting from controller
    final controller = MobileFileActionsController.forTab(widget.tabId);
    final isRecursive = controller.isRecursiveSearch;

    // Check if it's a tag search (contains # character)
    if (query.contains('#')) {
      // Extract tags from query
      final tags = query
          .split(' ')
          .where((word) => word.startsWith('#'))
          .map((tag) => tag.substring(1).trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (tags.isEmpty) return;

      // Search by tag (local only for mobile, no recursive for tags)
      if (tags.length == 1) {
        _folderListBloc.add(SearchByTag(tags.first));
      } else {
        _folderListBloc.add(SearchByMultipleTags(tags));
      }
    } else {
      // Search by filename with recursive option
      _folderListBloc.add(SearchByFileName(query, recursive: isRecursive));
    }
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
                    leading: Icon(remix.Remix.search_line),
                    title: Text('Tìm kiếm theo tên'),
                    subtitle: Text('Gõ từ khóa để tìm tệp theo tên'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(remix.Remix.shopping_bag_3_line),
                    title: Text('Tìm kiếm theo tag'),
                    subtitle: Text('Gõ # và tên tag (ví dụ: #important)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    RouteUtils.safePopDialog(context);
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
      _focusedPath = null;
    });

    // Clear any search or filter state when navigating
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(const ClearSearchAndFilters());
    }

    // Update the tab's path in the TabManager
    // This will automatically handle navigation history through updatePath() method
    context.read<TabManagerBloc>().add(UpdateTabPath(widget.tabId, path));

    debugPrint('Navigating to path: $path');
    debugPrint('Tab ID: ${widget.tabId}');

    // Debug: Check navigation history after adding
    final tabManagerBloc = context.read<TabManagerBloc>();
    final updatedTab = tabManagerBloc.state.tabs.firstWhere(
      (tab) => tab.id == widget.tabId,
      orElse: () => TabData(id: '', name: '', path: ''),
    );
    debugPrint(
        'Navigation history after adding: ${updatedTab.navigationHistory}');
    debugPrint(
        'Navigation history length: ${updatedTab.navigationHistory.length}');

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

  // Handle result from gallery screens (Video/Image Gallery)
  void _handleGalleryResult(dynamic result) {
    if (result != null && result is Map<String, dynamic>) {
      if (result['action'] == 'openFolder') {
        final folderPath = result['folderPath'] as String;
        final highlightedFileName = result['highlightedFileName'] as String?;
        debugPrint('Gallery returned openFolder request: $folderPath');

        // Open new tab with the folder
        TabNavigator.openTab(
          context,
          folderPath,
          title: 'Screenshots',
          highlightedFileName: highlightedFileName,
        );
      }
    }
  }

  // Handle back button press for Android
  Future<bool> _handleBackButton() async {
    try {
      debugPrint('=== _handleBackButton called ===');
      debugPrint('Hardware back button pressed!');
      debugPrint('Back button pressed - current path: $_currentPath');

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
      final currentTab = tabManagerBloc.state.tabs.firstWhere(
        (tab) => tab.id == widget.tabId,
        orElse: () => TabData(id: '', name: '', path: ''),
      );

      debugPrint('Current tab path: ${currentTab.path}');
      debugPrint('Navigation history: ${currentTab.navigationHistory}');
      debugPrint(
          'Navigation history length: ${currentTab.navigationHistory.length}');
      debugPrint(
          'Can navigate back: ${tabManagerBloc.canTabNavigateBack(widget.tabId)}');
      if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
        final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);
        debugPrint('Previous path: $previousPath');
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

          // Regular path navigation - use the bloc method
          final newPath = tabManagerBloc.backNavigationToPath(widget.tabId);
          debugPrint('Back navigation result: $newPath');
          if (newPath != null) {
            debugPrint('Successfully navigating back to: $newPath');
            setState(() {
              _currentPath = newPath;
              _pathController.text = newPath;
            });
            _folderListBloc.add(FolderListLoad(newPath));
            debugPrint('=== Back navigation completed successfully ===');
            return false; // Don't exit app, we navigated back
          } else {
            debugPrint('Back navigation failed - newPath is null');
          }
        }
      }

      // For mobile, if we're at root directory, show exit confirmation
      if (Platform.isAndroid || Platform.isIOS) {
        if (_currentPath.isEmpty ||
            _currentPath == '/storage/emulated/0' ||
            _currentPath == '/storage/self/primary') {
          // Show exit confirmation dialog
          debugPrint('At root directory on mobile - showing exit confirmation');
          final shouldExit = await _showExitConfirmation();
          debugPrint('Exit confirmation result: $shouldExit');
          return shouldExit;
        }
      }

      // If we can't navigate back in tab, check if we can pop the navigator
      if (Navigator.of(context).canPop()) {
        debugPrint('Popping navigator route');
        Navigator.of(context).pop();
        return false; // Don't exit app
      }

      // If we're at the root and can't navigate back, don't allow back
      debugPrint('At root directory - preventing back navigation');
      return false; // Don't exit app, just prevent back navigation
    } catch (e) {
      debugPrint('Error in _handleBackButton: $e');
      return false; // Don't exit app on error, just prevent back navigation
    }
  }

  // Show exit confirmation dialog for mobile
  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát ứng dụng?'),
        content: const Text('Bạn có chắc chắn muốn thoát ứng dụng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return result ?? false;
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

    // If navigating to a hash-based tag search, don't clear search
    // and don't try to load it as a directory. The screen handles it.
    if (newPath.startsWith('#search?tag=')) {
      _isHandlingPathUpdate = false;
      return;
    }

    // Clear any search or filter state when navigating to a normal path
    if (_currentFilter != null || _currentSearchTag != null) {
      _folderListBloc.add(const ClearSearchAndFilters());
    }

    // Load the folder contents with the new path
    _folderListBloc.add(FolderListLoad(newPath));

    // Save as last accessed folder
    _saveLastAccessedFolder();

    _isHandlingPathUpdate = false;
  }

  // New method to handle lazy loading of drives
  void _startLazyLoadingDrives() {
    // Small delay to ensure UI is responsive first
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // Load drives in the background
        _folderListBloc.add(const FolderListLoadDrives());

        // After a reasonable time for drives to load, update UI
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isLazyLoadingDrives = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always listen for tab path changes so we can switch between system and folder screens
    return BlocProvider.value(
      value: _selectionBloc,
      child: BlocListener<TabManagerBloc, TabManagerState>(
        listener: (context, tabManagerState) {
          final currentTab = tabManagerState.tabs.firstWhere(
            (tab) => tab.id == widget.tabId,
            orElse: () => TabData(id: '', name: '', path: ''),
          );

          if (currentTab.id.isNotEmpty && currentTab.path != _currentPath) {
            debugPrint(
                'Tab path updated from $_currentPath to ${currentTab.path}');
            _updatePath(currentTab.path);
          }
        },
        child: _buildContentForCurrentPath(context),
      ),
    );
  }

  // Build appropriate content depending on current path. This keeps the tab listening
  // active even when showing system screens like #tags.
  Widget _buildContentForCurrentPath(BuildContext context) {
    // Drive view (Windows only)
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
        onBackButtonPressed: () => _handleMouseBackButton(),
        onForwardButtonPressed: () => _handleMouseForwardButton(),
        isLazyLoading: _isLazyLoadingDrives,
      );
    }

    // Route system paths except the special inline tag-search variant
    if (_currentPath.startsWith('#') &&
        !_currentPath.startsWith('#search?tag=')) {
      final systemWidget = SystemScreenRouter.routeSystemPath(
          context, _currentPath, widget.tabId);
      if (systemWidget != null) {
        return systemWidget;
      }
    }

    // Folder/browser UI (default and for #search?tag=...)
    final bool isNetworkPath = _currentPath.startsWith('#network/');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        debugPrint(
            'TabbedFolderListScreen PopScope onPopInvokedWithResult: didPop=$didPop, result=$result');
        if (!didPop) {
          debugPrint('Gesture navigation detected - calling _handleBackButton');
          await _handleBackButton();
        }
      },
      // Wrap with Listener to detect mouse button events
      child: Focus(
        autofocus: isDesktopPlatform,
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            if (isDesktopPlatform) {
              _keyboardFocusNode.requestFocus();
            }
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
            child: BlocListener<FolderListBloc, FolderListState>(
              listener: (context, folderState) {
                // Check if there are any video/image files in the current directory
                final hasVideoOrImageFiles = _hasVideoOrImageFiles(folderState);

                // If no video/image files and we have pending thumbnails, reset the count
                if (!hasVideoOrImageFiles && _hasPendingThumbnails) {
                  debugPrint(
                      "TabbedFolderListScreen: No video/image files found, resetting pending thumbnail count");
                  ThumbnailLoader.resetPendingCount();
                  _hasPendingThumbnails = false;
                }

                // Only show tab loading when there are actual thumbnail tasks
                // Folder loading should not show in tab loading indicator
                final isLoading = _hasPendingThumbnails;

                context.read<TabManagerBloc>().add(
                      UpdateTabLoading(widget.tabId, isLoading),
                    );
              },
              child: BlocBuilder<FolderListBloc, FolderListState>(
                builder: (context, state) {
                  _currentSearchTag = state.currentSearchTag;
                  _currentFilter = state.currentFilter;

                  // Debug: Log filter state
                  if (_currentFilter != null) {
                    debugPrint('DEBUG: Filter is active: $_currentFilter');
                    debugPrint('DEBUG: Total files: ${state.files.length}');
                    debugPrint(
                        'DEBUG: Filtered files: ${state.filteredFiles.length}');
                  }

                  // Debug: Log all files in state
                  debugPrint('DEBUG: All files in state:');
                  for (int i = 0; i < state.files.length; i++) {
                    debugPrint('DEBUG: File $i: ${state.files[i].path}');
                  }

                  // Debug: Log search state
                  debugPrint(
                      'DEBUG: currentSearchTag: ${state.currentSearchTag}');
                  debugPrint(
                      'DEBUG: searchResults.length: ${state.searchResults.length}');
                  debugPrint('DEBUG: isGlobalSearch: $isGlobalSearch');
                  debugPrint('DEBUG: _currentSearchTag: $_currentSearchTag');

                  return _buildWithSelectionState(
                      context, state, isNetworkPath);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New helper method that builds the UI with selection state from BLoC
  Widget _buildWithSelectionState(BuildContext context,
      FolderListState folderListState, bool isNetworkPath) {
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
              onGallerySelected: isNetworkPath
                  ? null
                  : (value) {
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
                        ).then(_handleGalleryResult);
                      }
                    },
              currentPath: _currentPath,
            )
          : []);

      return ScreenScaffold(
        selectionState: selectionState,
        body:
            _buildBody(context, folderListState, selectionState, isNetworkPath),
        isNetworkPath: isNetworkPath,
        onClearSelection: _clearSelection,
        showRemoveTagsDialog: _showRemoveTagsDialog,
        showManageAllTagsDialog: (context) => _showManageAllTagsDialog(context),
        showDeleteConfirmationDialog: (context) =>
            _showDeleteConfirmationDialog(context),
        isDesktop: isDesktopPlatform,
        selectionModeFloatingActionButton: isNetworkPath
            ? null
            : FloatingActionButton(
                onPressed: () {
                  tab_components.showBatchAddTagDialog(
                      context, selectionState.selectedFilePaths.toList());
                },
                child: const Icon(remix.Remix.shopping_bag_3_line),
              ),
        showAppBar: widget.showAppBar,
        showSearchBar: _showSearchBar,
        searchBar: tab_components.SearchBar(
          currentPath: _currentPath,
          tabId: widget.tabId,
          onCloseSearch: () {
            setState(() {
              _showSearchBar = false;
            });
          },
        ),
        pathNavigationBar: tab_components.PathNavigationBar(
          tabId: widget.tabId,
          pathController: _pathController,
          onPathSubmitted: _handlePathSubmit,
          currentPath: _currentPath,
          isNetworkPath: isNetworkPath, // Pass network flag
        ),
        actions: [...actions, ..._getAppBarActions()],
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleSelectionMode,
          child: const Icon(remix.Remix.checkbox_line),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, FolderListState state,
      SelectionState selectionState, bool isNetworkPath) {
    // Apply frame timing optimization before heavy UI operations
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    if (isDesktopPlatform) {
      _syncFocusedPath(selectionState);
    }

    // Decide whether to show skeletons
    final bool shouldShowSkeleton = state.isLoading ||
        (!_hasAnyContentLoaded &&
            state.error == null &&
            state.folders.isEmpty &&
            state.files.isEmpty &&
            state.searchResults.isEmpty &&
            state.currentSearchTag == null &&
            state.currentSearchQuery == null);

    return Column(
      children: [
        // Top progress bar when loading, refreshing, or while initial content is being prepared
        if (state.isLoading || shouldShowSkeleton || _isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: AppProgressIndicatorBeautiful(),
          ),
        Expanded(
          child: FluentBackground.container(
            context: context,
            enableBlur: isDesktopPlatform,
            child: shouldShowSkeleton
                ? const SizedBox.shrink() // Show an empty space while loading
                : _buildMainContent(
                    context, state, selectionState, isNetworkPath),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, FolderListState state,
      SelectionState selectionState, bool isNetworkPath) {
    if (state.error != null) {
      return FluentBackground.container(
        context: context,
        enableBlur: isDesktopPlatform,
        padding: const EdgeInsets.all(24.0),
        blurAmount: 5.0,
        child: tab_components.ErrorView(
          errorMessage: state.error!,
          isNetworkPath: isNetworkPath,
          onRetry: () {
            _folderListBloc.add(FolderListLoad(_currentPath));
          },
          onGoBack: () {
            if (isNetworkPath) {
              final parts = _currentPath.split('/');
              if (parts.length > 3) {
                final parentPath = parts.sublist(0, parts.length - 1).join('/');
                _navigateToPath(parentPath);
              } else {
                final tabBloc =
                    BlocProvider.of<TabManagerBloc>(context, listen: false);
                tabBloc.add(CloseTab(widget.tabId));
              }
            } else {
              try {
                final parentPath = Directory(_currentPath).parent.path;
                if (parentPath != _currentPath) {
                  _navigateToPath(parentPath);
                } else {
                  _navigateToPath('');
                }
              } catch (e) {
                debugPrint('Error navigating back: $e');
              }
            }
          },
        ),
      );
    }

    // Show files/folders even while loading (progressive loading)
    return _buildFolderAndFileListContent(
        context, state, selectionState, isNetworkPath);
  }

  Widget _buildFolderAndFileListContent(
      BuildContext context,
      FolderListState state,
      SelectionState selectionState,
      bool isNetworkPath) {
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
            // If this is a search tag tab, close it instead of clearing search
            if (_currentPath.startsWith('#search?tag=')) {
              final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);
              tabManagerBloc.add(CloseTab(widget.tabId));
              return;
            }

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
            FluentBackground(
              blurAmount: 8.0,
              opacity: 0.7,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.7),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      state.currentSearchTag != null
                          ? remix.Remix.shopping_bag_3_line
                          : remix.Remix.search_line,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(state.currentSearchTag != null
                          ? 'Không tìm thấy kết quả cho tag "${state.currentSearchTag}"'
                          : 'Không tìm thấy kết quả cho "${state.currentSearchQuery}"'),
                    ),
                    IconButton(
                      icon: const Icon(remix.Remix.close_line),
                      onPressed: () {
                        // If this is a search tag tab, close it instead of clearing search
                        if (_currentPath.startsWith('#search?tag=')) {
                          final tabManagerBloc =
                              BlocProvider.of<TabManagerBloc>(context);
                          tabManagerBloc.add(CloseTab(widget.tabId));
                          return;
                        }

                        _folderListBloc.add(const ClearSearchAndFilters());
                        _folderListBloc.add(FolderListLoad(_currentPath));
                      },
                      tooltip: 'Xóa tìm kiếm',
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(remix.Remix.search_line, size: 64, color: Colors.grey),
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
    if (_currentFilter != null && _currentFilter!.isNotEmpty) {
      return Column(
        children: [
          // Filter indicator with clear button
          Container(
            padding: const EdgeInsets.all(8.0),
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Icon(remix.Remix.filter_3_line, size: 16),
                const SizedBox(width: 8),
                Text('Filtered by: $_currentFilter'),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _folderListBloc.add(const ClearSearchAndFilters());
                  },
                  child: const Text('Clear Filter'),
                ),
              ],
            ),
          ),
          // Show filtered files or empty message
          Expanded(
            child: state.filteredFiles.isNotEmpty
                ? folder_list_components.FileView(
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
                    showFileTags: _showFileTags,
                  )
                : Center(
                    child: Text('No files match the filter "$_currentFilter"'),
                  ),
          ),
        ],
      );
    }

    // Empty directory check
    if (state.folders.isEmpty && state.files.isEmpty) {
      return FluentBackground.container(
        context: context,
        enableBlur: isDesktopPlatform,
        child: Center(
          child: Text(AppLocalizations.of(context)!.emptyFolder,
              style: TextStyle(fontSize: 18)),
        ),
      );
    }

    // Mark that we have content at least once to prevent future flicker
    _hasAnyContentLoaded = true;

    // Default view - folders and files
    return RefreshIndicator(
      // Improve mobile experience with better colors and behavior
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      strokeWidth: 2.0,
      displacement: Platform.isAndroid || Platform.isIOS ? 40.0 : 60.0,
      onRefresh: () async {
        // Add haptic feedback for mobile
        if (Platform.isAndroid || Platform.isIOS) {
          HapticFeedback.lightImpact();
        }

        setState(() {
          _isRefreshing = true;
        });

        // Create the completer first
        final completer = Completer<void>();

        // Create the subscription variable
        late StreamSubscription subscription;

        // Now set up the listener
        subscription = _folderListBloc.stream.listen((state) {
          // When loading is done (changed from true to false), complete the Future
          if (!state.isLoading) {
            // Add success haptic feedback for mobile
            if (Platform.isAndroid || Platform.isIOS) {
              HapticFeedback.selectionClick();
            }
            setState(() {
              _isRefreshing = false;
            });
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
          } else if (_currentPath.startsWith('#network/')) {
            // Network special paths (#network/TYPE/...) – clear widget cache and reload
            SystemScreenRouter.refreshSystemPath(_currentPath, widget.tabId);

            // Force TabManager to re-set the same path to trigger rebuild
            context
                .read<TabManagerBloc>()
                .add(UpdateTabPath(widget.tabId, _currentPath));

            // If this screen still uses FolderList, trigger bloc refresh to regenerate thumbnails
            _folderListBloc.add(FolderListRefresh(_currentPath,
                forceRegenerateThumbnails: true));
          }
        } else {
          // Use FolderListRefresh instead of FolderListLoad to force thumbnail regeneration
          VideoThumbnailHelper.trimCache();
          _folderListBloc.add(
              FolderListRefresh(_currentPath, forceRegenerateThumbnails: true));
        }

        // Wait for the loading to complete before returning
        // Add timeout to prevent infinite waiting
        return completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Refresh timeout - completing anyway');
            subscription.cancel();
          },
        );
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
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2, // Very subtle background effect
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
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
                // Handle drag selection (desktop only)
                onPanStart: isDesktopPlatform
                    ? (details) {
                        _startDragSelection(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        _updateDragSelection(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        _endDragSelection();
                      }
                    : null,
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
                      // Optimized physics for smoother mobile scrolling
                      physics: const ClampingScrollPhysics(),
                      // Enhanced caching for better scroll performance
                      cacheExtent: 1500,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
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
                          if (isDesktopPlatform) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              try {
                                final RenderBox? renderBox =
                                    context.findRenderObject() as RenderBox?;
                                if (renderBox != null &&
                                    renderBox.hasSize &&
                                    renderBox.attached) {
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
                              } catch (e) {
                                // Silently ignore layout errors to prevent crashes
                                debugPrint('Layout error in grid view: $e');
                              }
                            });
                          }

                          if (index < state.folders.length) {
                            final folder = state.folders[index] as Directory;
                            return KeyedSubtree(
                              key: ValueKey('folder-grid-${folder.path}'),
                              child: RepaintBoundary(
                                child: FluentBackground.container(
                                  context: context,
                                  enableBlur: isDesktopPlatform,
                                  padding: EdgeInsets.zero,
                                  blurAmount: 5.0,
                                  opacity: isSelected ? 0.8 : 0.6,
                                  backgroundColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.6)
                                      : Theme.of(context)
                                          .cardColor
                                          .withOpacity(0.4),
                                  child: folder_list_components.FolderGridItem(
                                    key: ValueKey(
                                        'folder-grid-item-${folder.path}'),
                                    folder: folder,
                                    onNavigate: _navigateToPath,
                                    isSelected: isSelected,
                                    toggleFolderSelection:
                                        _toggleFolderSelection,
                                    isDesktopMode: isDesktopPlatform,
                                    lastSelectedPath:
                                        selectionState.lastSelectedPath,
                                    clearSelectionMode: _clearSelection,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            final file = state
                                .files[index - state.folders.length] as File;
                            return KeyedSubtree(
                              key: ValueKey('file-grid-${file.path}'),
                              child: RepaintBoundary(
                                child: FluentBackground.container(
                                  context: context,
                                  enableBlur: isDesktopPlatform,
                                  padding: EdgeInsets.zero,
                                  blurAmount: 5.0,
                                  opacity: isSelected ? 0.8 : 0.6,
                                  backgroundColor: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.6)
                                      : Theme.of(context)
                                          .cardColor
                                          .withOpacity(0.4),
                                  child: folder_list_components.FileGridItem(
                                    key:
                                        ValueKey('file-grid-item-${file.path}'),
                                    file: file,
                                    state: state,
                                    isSelectionMode:
                                        selectionState.isSelectionMode,
                                    isSelected: isSelected,
                                    toggleFileSelection: _toggleFileSelection,
                                    toggleSelectionMode: _toggleSelectionMode,
                                    onFileTap: _onFileTap,
                                    isDesktopMode: isDesktopPlatform,
                                    lastSelectedPath:
                                        selectionState.lastSelectedPath,
                                    showFileTags: _showFileTags,
                                  ),
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
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2, // Very subtle background effect
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
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
                // Handle drag selection (desktop only)
                onPanStart: isDesktopPlatform
                    ? (details) {
                        _startDragSelection(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        _updateDragSelection(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        _endDragSelection();
                      }
                    : null,
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
                    showFileTags: _showFileTags,
                  ),
                ),
              );
            },
          ),
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
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2, // Very subtle background effect
          enableBlur: isDesktopPlatform,
          child: BlocBuilder<SelectionBloc, SelectionState>(
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
                // Handle drag selection (desktop only)
                onPanStart: isDesktopPlatform
                    ? (details) {
                        _startDragSelection(details.localPosition);
                      }
                    : null,
                onPanUpdate: isDesktopPlatform
                    ? (details) {
                        _updateDragSelection(details.localPosition);
                      }
                    : null,
                onPanEnd: isDesktopPlatform
                    ? (details) {
                        _endDragSelection();
                      }
                    : null,
                behavior: HitTestBehavior.translucent,
                child: RepaintBoundary(
                  child: ListView.builder(
                    // Optimized physics for smoother mobile scrolling
                    physics: const ClampingScrollPhysics(),
                    // Enhanced caching for better scroll performance
                    cacheExtent: 800,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
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
                        if (isDesktopPlatform) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              final RenderBox? renderBox =
                                  context.findRenderObject() as RenderBox?;
                              if (renderBox != null &&
                                  renderBox.hasSize &&
                                  renderBox.attached) {
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
                            } catch (e) {
                              // Silently ignore layout errors to prevent crashes
                              debugPrint('Layout error in grid view: $e');
                            }
                          });
                        }

                        if (index < state.folders.length) {
                          final folder = state.folders[index] as Directory;
                          return KeyedSubtree(
                            key: ValueKey("folder-${folder.path}"),
                            child: FluentBackground(
                              enableBlur: isDesktopPlatform,
                              blurAmount: 3.0,
                              opacity: isSelected
                                  ? 0.7
                                  : 0.0, // Only show background when selected
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              child: RepaintBoundary(
                                child: folder_list_components.FolderItem(
                                  key: ValueKey("folder-item-${folder.path}"),
                                  folder: folder,
                                  onTap: _navigateToPath,
                                  isSelected: isSelected,
                                  toggleFolderSelection: _toggleFolderSelection,
                                  isDesktopMode: isDesktopPlatform,
                                  lastSelectedPath:
                                      selectionState.lastSelectedPath,
                                ),
                              ),
                            ),
                          );
                        } else {
                          final file =
                              state.files[index - state.folders.length] as File;
                          return KeyedSubtree(
                            key: ValueKey("file-${file.path}"),
                            child: FluentBackground(
                              enableBlur: isDesktopPlatform,
                              blurAmount: 3.0,
                              opacity: isSelected
                                  ? 0.7
                                  : 0.0, // Only show background when selected
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              child: RepaintBoundary(
                                child: folder_list_components.FileItem(
                                  key: ValueKey("file-item-${file.path}"),
                                  file: file,
                                  state: state,
                                  isSelectionMode:
                                      selectionState.isSelectionMode,
                                  isSelected: isSelected,
                                  toggleFileSelection: _toggleFileSelection,
                                  showDeleteTagDialog: _showDeleteTagDialog,
                                  showAddTagToFileDialog:
                                      _showAddTagToFileDialog,
                                  onFileTap: _onFileTap,
                                  isDesktopMode: isDesktopPlatform,
                                  lastSelectedPath:
                                      selectionState.lastSelectedPath,
                                ),
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

  void _showRemoveTagsDialog(BuildContext context) {
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
              RouteUtils.safePopDialog(context);
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

              RouteUtils.safePopDialog(context);
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

    // Check file type using utility
    final isVideo = FileTypeUtils.isVideoFile(file.path);
    final isImage = FileTypeUtils.isImageFile(file.path);

    // Open file based on file type
    if (isVideo) {
      // Open video in video player (fullscreen route on root navigator)
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => VideoPlayerFullScreen(file: file),
        ),
      );
    } else if (isImage) {
      // Get all image files in the same directory for gallery navigation
      List<File> imageFiles = [];
      int initialIndex = 0;

      // Only process this if we're showing the folder contents (not search results)
      if (_currentFilter == null &&
          _currentSearchTag == null &&
          _folderListBloc.state.files.isNotEmpty) {
        imageFiles = _folderListBloc.state.files.whereType<File>().where((f) {
          return FileTypeUtils.isImageFile(f.path);
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

  // Tạo menu items cho address bar dựa trên loại màn hình
  List<AddressBarMenuItem> _getAddressBarMenuItems() {
    // Nếu đang ở màn hình tags, trả về menu items cho tag management
    if (_currentPath == '#tags') {
      return _createTagManagementMenuItems();
    }

    // Nếu đang ở màn hình tag cụ thể (ví dụ: #tag:tagname)
    if (_currentPath.startsWith('#tag:')) {
      return _createTagViewMenuItems();
    }

    // Mặc định không có menu items
    return [];
  }

  // Tạo menu items cho tag management screen
  List<AddressBarMenuItem> _createTagManagementMenuItems() {
    return [
      AddressBarMenuItem(
        icon: remix.Remix.search_line,
        title: 'Tìm kiếm',
        onTap: () {
          // Trigger search mode in TagManagementScreen
          // This will be handled by the TagManagementScreen itself
          _triggerTagSearch();
        },
      ),
      AddressBarMenuItem(
        icon: remix.Remix.information_line,
        title: 'Thông tin',
        onTap: () {
          _showTagManagementInfo();
        },
      ),
      AddressBarMenuItem(
        icon: remix.Remix.refresh_line,
        title: 'Làm mới',
        onTap: () {
          _refreshTagManagement();
        },
      ),
      AddressBarMenuItem(
        icon: remix.Remix.settings_3_line,
        title: 'Sắp xếp',
        onTap: () {
          _showTagSortOptions();
        },
      ),
    ];
  }

  // Tạo menu items cho tag view screen
  List<AddressBarMenuItem> _createTagViewMenuItems() {
    return [
      AddressBarMenuItem(
        icon: remix.Remix.search_line,
        title: 'Tìm kiếm',
        onTap: () {
          // TODO: Implement search functionality
        },
      ),
      AddressBarMenuItem(
        icon: remix.Remix.refresh_line,
        title: 'Làm mới',
        onTap: () {
          // TODO: Force reload files
        },
      ),
      AddressBarMenuItem(
        icon: remix.Remix.settings_3_line,
        title: 'Sắp xếp',
        onTap: () {
          // TODO: Show sort options
        },
      ),
    ];
  }

  // Tạo action widgets cho AppBar từ menu items (cho mobile)
  List<Widget> _getAppBarActions() {
    // Không cần menu ba chấm riêng nữa vì đã chuyển vào menu quản lý tab
    // Menu quản lý tab sẽ hiển thị các chức năng tag management khi ở màn hình #tags
    return [];
  }

  // Các method xử lý cho tag management menu
  void _triggerTagSearch() {
    // Trigger search mode - this will be handled by TagManagementScreen
    // We can use a simple approach by showing a search dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm kiếm thẻ'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Nhập tên thẻ...',
            prefixIcon: Icon(remix.Remix.search_line),
          ),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            // TODO: Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showTagManagementInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông tin quản lý thẻ'),
        content: const Text(
          'Màn hình này cho phép bạn quản lý các thẻ (tags) của file và thư mục.\n\n'
          '• Xem danh sách tất cả thẻ\n'
          '• Tìm kiếm thẻ\n'
          '• Sắp xếp thẻ theo tên, độ phổ biến\n'
          '• Xem file được gắn thẻ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _refreshTagManagement() {
    // Force reload tags by triggering a refresh
    // This will be handled by the TagManagementScreen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.tagListRefreshing),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showTagSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sắp xếp thẻ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Theo tên (A-Z)'),
              leading: Icon(remix.Remix.sort_asc),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sắp xếp theo tên A-Z')),
                );
              },
            ),
            ListTile(
              title: const Text('Theo độ phổ biến'),
              leading: Icon(remix.Remix.line_chart_line),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sắp xếp theo độ phổ biến')),
                );
              },
            ),
            ListTile(
              title: const Text('Theo thời gian gần đây'),
              leading: Icon(remix.Remix.history_line),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sắp xếp theo thời gian gần đây')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
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

  void _syncFocusedPath(SelectionState selectionState) {
    final String? lastPath = selectionState.lastSelectedPath;
    if (lastPath != null && lastPath != _focusedPath) {
      _focusedPath = lastPath;
    } else if (lastPath == null &&
        selectionState.selectedFilePaths.isEmpty &&
        selectionState.selectedFolderPaths.isEmpty) {
      _focusedPath = null;
    }
  }

  List<FileSystemEntity> _getNavigableItems(FolderListState state) {
    if (state.currentSearchTag != null || state.currentSearchQuery != null) {
      return List<FileSystemEntity>.from(state.searchResults);
    }

    if (_currentFilter != null && _currentFilter!.isNotEmpty) {
      return List<FileSystemEntity>.from(state.filteredFiles);
    }

    return [
      ...state.folders.whereType<FileSystemEntity>(),
      ...state.files.whereType<FileSystemEntity>(),
    ];
  }

  void _focusItemAtIndex(List<FileSystemEntity> items, int index) {
    if (index < 0 || index >= items.length) return;

    final FileSystemEntity target = items[index];
    _focusedPath = target.path;

    if (target is Directory) {
      _toggleFolderSelection(target.path,
          shiftSelect: false, ctrlSelect: false);
    } else if (target is File) {
      _toggleFileSelection(target.path, shiftSelect: false, ctrlSelect: false);
    }
  }

  void _activateItem(FileSystemEntity entity) {
    if (entity is Directory) {
      _navigateToPath(entity.path);
    } else if (entity is File) {
      _onFileTap(entity, FileTypeUtils.isVideoFile(entity.path));
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!isDesktopPlatform) return KeyEventResult.ignored;

    final bool isKeyPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (!isKeyPress) return KeyEventResult.ignored;

    final FolderListState state = _folderListBloc.state;
    final List<FileSystemEntity> items = _getNavigableItems(state);
    if (items.isEmpty) return KeyEventResult.ignored;

    final bool isGridLayout = state.viewMode == ViewMode.grid;
    final int crossAxisCount = isGridLayout ? max(1, state.gridZoomLevel) : 1;
    final SelectionState selectionState = _selectionBloc.state;

    int currentIndex = -1;
    if (_focusedPath != null) {
      currentIndex = items
          .indexWhere((FileSystemEntity item) => item.path == _focusedPath);
    }
    if (currentIndex == -1 && selectionState.lastSelectedPath != null) {
      currentIndex = items.indexWhere((FileSystemEntity item) =>
          item.path == selectionState.lastSelectedPath);
    }
    if (currentIndex == -1) {
      currentIndex = 0;
    }

    final bool hasExistingFocus =
        _focusedPath != null || selectionState.lastSelectedPath != null;
    final LogicalKeyboardKey key = event.logicalKey;
    int? targetIndex;

    if (key == LogicalKeyboardKey.arrowDown) {
      targetIndex = currentIndex + (isGridLayout ? crossAxisCount : 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      targetIndex = currentIndex - (isGridLayout ? crossAxisCount : 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      targetIndex = currentIndex + 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      targetIndex = currentIndex - 1;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!hasExistingFocus) {
        _focusItemAtIndex(items, currentIndex);
        return KeyEventResult.handled;
      }
      _activateItem(items[currentIndex]);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }

    if (targetIndex != null) {
      final int newIndex = targetIndex.clamp(0, items.length - 1).toInt();
      _focusItemAtIndex(items, newIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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

    // Create a gradient border paint for more modern look
    final Gradient borderGradient = LinearGradient(
      colors: [
        borderColor.withOpacity(0.8),
        borderColor.withOpacity(0.6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final Paint borderPaint = Paint()
      ..shader = borderGradient.createShader(selectionRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Make border slightly thicker for better visibility

    // Add slight rounded corners for fluent design feel
    final RRect roundedRect = RRect.fromRectAndRadius(
      selectionRect,
      const Radius.circular(4.0),
    );

    // Draw the fill with rounded corners
    canvas.drawRRect(roundedRect, fillPaint);

    // Draw the border with rounded corners
    canvas.drawRRect(roundedRect, borderPaint);

    // Add subtle inner highlight for depth
    final Rect innerHighlight = selectionRect.deflate(2.0);
    if (innerHighlight.width > 0 && innerHighlight.height > 0) {
      final RRect innerRRect = RRect.fromRectAndRadius(
        innerHighlight,
        const Radius.circular(2.0),
      );

      final Paint highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawRRect(innerRRect, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(SelectionRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
