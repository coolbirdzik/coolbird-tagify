import 'dart:io';
import 'dart:async'; // Add this import for Completer
import 'dart:math'; // For math operations with drag selection and min/max functions

import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Import for mouse buttons
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/services.dart'; // Import for keyboard keys
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/ui/utils/fluent_background.dart'; // Import the Fluent Design background

// Import network browsing components
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_bloc.dart';
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_event.dart';
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_state.dart';

// Import folder list state for models
import '../folder_list/folder_list_state.dart';
import '../folder_list/components/index.dart' as folder_list_components;

// Import selection bloc
import 'package:cb_file_manager/bloc/selection/selection.dart';

// Import tab manager components
import 'package:cb_file_manager/ui/tab_manager/components/index.dart'
    as tab_components;
import 'package:cb_file_manager/ui/tab_manager/tab_data.dart'; // Import TabData explicitly

// Add imports for hardware acceleration
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/foundation.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/ui/components/screen_scaffold.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/components/network_folder_context_menu.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/ui/components/video_player/custom_video_player.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';

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

/// A screen for browsing network locations, with a UI consistent with TabbedFolderListScreen
class NetworkBrowserScreen extends StatefulWidget {
  final String path;
  final String tabId;
  final bool showAppBar;

  const NetworkBrowserScreen({
    Key? key,
    required this.path,
    required this.tabId,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<NetworkBrowserScreen> createState() => _NetworkBrowserScreenState();
}

class _NetworkBrowserScreenState extends State<NetworkBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TextEditingController _pathController;

  late SelectionBloc _selectionBloc;
  bool _showSearchBar = false;
  String _currentPath = '';

  // View and sort preferences
  ViewMode _viewMode = ViewMode.list;
  SortOption _sortOption = SortOption.nameAsc;
  int _gridZoomLevel = 3;
  ColumnVisibility _columnVisibility = const ColumnVisibility();
  bool _arePreferencesLoading = true;

  // Network browsing BLoC
  late NetworkBrowsingBloc _networkBrowsingBloc;

  // Flag to track if we're handling a path update to avoid duplicate loads
  bool _isHandlingPathUpdate = false;

  // Flag to prevent multiple loads
  bool _isLoadingStarted = false;

  // Variables for drag selection
  final Map<String, Rect> _itemPositions = {};
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
    _pathController = TextEditingController(text: _currentPath);

    // Enable hardware acceleration for smoother animations
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;
    RendererBinding.instance.ensureSemantics();

    // Initialize the blocs
    _networkBrowsingBloc = context.read<NetworkBrowsingBloc>();
    _selectionBloc = SelectionBloc();

    // Load preferences
    _loadPreferences();

    // Load initial directory
    // Add a post-frame callback to ensure the BLoC provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoadingStarted) {
        _loadNetworkDirectory();
      }
    });

    // Add listener to search controller to update UI when text changes
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          // Force UI update when search text changes
        });
      }
    });

    // Add listener to path controller to update current path when text changes
    _pathController.addListener(() {
      // Don't trigger path changes while user is editing
      if (_pathController.text != _currentPath && !_isHandlingPathUpdate) {
        debugPrint("Path controller updated to: ${_pathController.text}");
      }
    });
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
      _updatePath(activeTab.path);
    }
  }

  @override
  void didUpdateWidget(NetworkBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.path != oldWidget.path && widget.path != _currentPath) {
      _updatePath(widget.path);
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _searchController.dispose();
    _pathController.dispose();
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
          _sortOption = sortOption;
          _gridZoomLevel = gridZoomLevel;
          _columnVisibility = columnVisibility;
          _arePreferencesLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _arePreferencesLoading = false;
        });
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

  Future<void> _saveSortSetting(SortOption option) async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      await prefs.setSortOption(option);
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
    _selectionBloc.add(ToggleSelectionMode(forceValue: forceValue));
  }

  void _toggleFileSelection(String filePath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    // This logic would need the combined file/folder list from NetworkBrowsingState
    // For now, implement simple toggle
    _selectionBloc.add(ToggleFileSelection(
      filePath,
      shiftSelect: false,
      ctrlSelect: ctrlSelect,
    ));
  }

  void _toggleFolderSelection(String folderPath,
      {bool shiftSelect = false, bool ctrlSelect = false}) {
    // This logic would need the combined file/folder list from NetworkBrowsingState
    // For now, implement simple toggle
    _selectionBloc.add(ToggleFolderSelection(
      folderPath,
      shiftSelect: false,
      ctrlSelect: ctrlSelect,
    ));
  }

  void _clearSelection() {
    _selectionBloc.add(ClearSelection());
  }

  void _toggleViewMode() {
    setState(() {
      if (_viewMode == ViewMode.list) {
        _viewMode = ViewMode.grid;
      } else if (_viewMode == ViewMode.grid) {
        _viewMode = ViewMode.details;
      } else {
        _viewMode = ViewMode.list;
      }
    });
    _saveViewModeSetting(_viewMode);
  }

  void _setViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
    _saveViewModeSetting(_viewMode);
  }

  void _refreshFileList() {
    _loadNetworkDirectory();
  }

  void _loadNetworkDirectory() {
    if (mounted && !_isLoadingStarted) {
      setState(() {
        _isLoadingStarted = true;
      });
      _networkBrowsingBloc.add(NetworkDirectoryRequested(_currentPath));
    }
  }

  void _showSearchTip(BuildContext context) {
    setState(() {
      _showSearchBar = true;
    });
  }

  void _navigateToPath(String path) {
    setState(() {
      _currentPath = path;
      _pathController.text = path;
      _isLoadingStarted = false; // Reset loading flag for new path
    });

    // Ensure path controller is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pathController.text != path) {
        _pathController.text = path;
      }
    });

    context.read<TabManagerBloc>().add(UpdateTabPath(widget.tabId, path));
    context.read<TabManagerBloc>().add(AddToTabHistory(widget.tabId, path));

    _loadNetworkDirectory();

    final pathParts = path.split('/');
    final lastPart =
        pathParts.lastWhere((part) => part.isNotEmpty, orElse: () => 'Network');
    final tabName = lastPart.isEmpty ? 'Network' : lastPart;

    context.read<TabManagerBloc>().add(UpdateTabName(widget.tabId, tabName));
  }

  void _handlePathSubmit(String path) {
    _navigateToPath(path);
  }

  Future<bool> _handleBackButton() async {
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
      final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);
      if (previousPath != null) {
        _navigateToPath(previousPath);
        return false; // Don't exit app, we navigated back
      }
    }
    return true; // If we're at the root, let the system handle back
  }

  void _updatePath(String newPath) {
    if (_isHandlingPathUpdate) return;

    _isHandlingPathUpdate = true;
    _navigateToPath(newPath);
    _isHandlingPathUpdate = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_arePreferencesLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocProvider.value(
      value: _selectionBloc,
      child: BlocListener<TabManagerBloc, TabManagerState>(
        listener: (context, tabManagerState) {
          final currentTab = tabManagerState.tabs.firstWhere(
            (tab) => tab.id == widget.tabId,
            orElse: () => TabData(id: '', name: '', path: ''),
          );

          if (currentTab.id.isNotEmpty && currentTab.path != _currentPath) {
            _updatePath(currentTab.path);
          }
        },
        child: WillPopScope(
          onWillPop: _handleBackButton,
          child: Listener(
            onPointerDown: (PointerDownEvent event) {
              if (event.buttons == 8) {
                _handleMouseBackButton();
              } else if (event.buttons == 16) {
                _handleMouseForwardButton();
              }
            },
            child: BlocConsumer<NetworkBrowsingBloc, NetworkBrowsingState>(
                listener: (context, state) {
              debugPrint(
                  "NetworkBrowserScreen: BlocConsumer listener triggered");
              debugPrint("  - state.isLoading: ${state.isLoading}");
              debugPrint("  - state.hasDirectories: ${state.hasDirectories}");
              debugPrint("  - state.hasFiles: ${state.hasFiles}");
              debugPrint("  - state.hasContent: ${state.hasContent}");

              if (!state.isLoading) {
                setState(() {
                  _isLoadingStarted = false;
                });

                // Force rebuild to make sure UI updates with the latest state
                if (state.hasContent) {
                  debugPrint(
                      "NetworkBrowserScreen: Content detected, forcing rebuild");
                  setState(() {});
                }
              }
            }, builder: (context, state) {
              debugPrint(
                  "NetworkBrowserScreen: BlocConsumer builder triggered");
              debugPrint("  - state.isLoading: ${state.isLoading}");
              debugPrint(
                  "  - state.directories: ${state.directories?.length ?? 0}");
              debugPrint("  - state.files: ${state.files?.length ?? 0}");

              return _buildWithSelectionState(context, state);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildWithSelectionState(
      BuildContext context, NetworkBrowsingState networkState) {
    return BlocBuilder<SelectionBloc, SelectionState>(
        builder: (context, selectionState) {
      List<Widget> actions = [];

      actions.addAll(!selectionState.isSelectionMode
          ? SharedActionBar.buildCommonActions(
              context: context,
              onSearchPressed: () => _showSearchTip(context),
              onSortOptionSelected: (SortOption option) {
                setState(() {
                  _sortOption = option;
                });
                _saveSortSetting(option);
                // Refresh the list with the new sort option
                _refreshFileList();
              },
              currentSortOption: _sortOption,
              viewMode: _viewMode,
              onViewModeToggled: _toggleViewMode,
              onViewModeSelected: _setViewMode,
              onRefresh: _refreshFileList,
              onGridSizePressed: _viewMode == ViewMode.grid
                  ? () => SharedActionBar.showGridSizeDialog(
                        context,
                        currentGridSize: _gridZoomLevel,
                        onApply: _handleGridZoomChange,
                      )
                  : null,
              onColumnSettingsPressed: _viewMode == ViewMode.details
                  ? () {
                      _showColumnVisibilityDialog(context);
                    }
                  : null,
              onSelectionModeToggled: _toggleSelectionMode,
              onManageTagsPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Tags are not supported for network locations.')),
                );
              },
              onGallerySelected: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Gallery mode is not supported for network locations.')),
                );
              },
              currentPath: _currentPath,
            )
          : []);

      return ScreenScaffold(
        selectionState: selectionState,
        body: _buildBody(context, networkState, selectionState),
        isNetworkPath: true,
        onClearSelection: _clearSelection,
        showRemoveTagsDialog: (context) {
          // Not supported for network, provide empty implementation
        },
        showManageAllTagsDialog: (context) {
          // Not supported for network, provide empty implementation
        },
        showDeleteConfirmationDialog: (context) =>
            _showDeleteConfirmationDialog(context),
        selectionModeFloatingActionButton: null,
        showAppBar: widget.showAppBar,
        showSearchBar: _showSearchBar,
        searchBar: tab_components.SearchBar(
          currentPath: _currentPath,
          tabId: widget.tabId,
          onCloseSearch: () {
            setState(() {
              _showSearchBar = false;
              _searchController.clear(); // Clear the search query
            });
            // Refresh the file list when search is closed
            _refreshFileList();
          },
        ),
        pathNavigationBar: tab_components.PathNavigationBar(
          tabId: widget.tabId,
          pathController: _pathController,
          onPathSubmitted: _handlePathSubmit,
          currentPath: _currentPath,
          isNetworkPath: true,
        ),
        actions: actions,
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleSelectionMode,
          child: const Icon(EvaIcons.checkmarkSquare2Outline),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, NetworkBrowsingState state,
      SelectionState selectionState) {
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    // Log debug information
    debugPrint(
        "\n\n==================== NETWORK BROWSER DEBUG ====================");
    debugPrint("NetworkBrowserScreen: Building body for path: $_currentPath");
    debugPrint("NetworkBrowserScreen: Loading state: ${state.isLoading}");
    debugPrint("NetworkBrowserScreen: Error state: ${state.hasError}");
    if (state.hasError) {
      debugPrint("NetworkBrowserScreen: Error message: ${state.errorMessage}");
    }

    // Critical debug
    debugPrint(
        "NetworkBrowserScreen: Directories: ${state.directories?.length ?? 0}");
    if (state.directories != null && state.directories!.isNotEmpty) {
      for (var dir in state.directories!) {
        debugPrint("  - Directory: ${dir.path}");
      }
    }
    debugPrint("NetworkBrowserScreen: Files: ${state.files?.length ?? 0}");
    if (state.files != null && state.files!.isNotEmpty) {
      for (var file in state.files!) {
        debugPrint("  - File: ${file.path}");
      }
    }

    if (state.isLoading && state.directories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError) {
      return FluentBackground.container(
        context: context,
        padding: const EdgeInsets.all(24.0),
        blurAmount: 5.0,
        child: tab_components.ErrorView(
          errorMessage: state.errorMessage ?? "An unknown error occurred.",
          isNetworkPath: true,
          onRetry: () {
            _loadNetworkDirectory();
          },
          onGoBack: () {
            _handleBackButton();
          },
        ),
      );
    }

    // Get folders and files from state
    List<FileSystemEntity> folders = List.from(state.directories ?? []);
    List<FileSystemEntity> files = List.from(state.files ?? []);

    if (folders.isEmpty && files.isEmpty) {
      return FluentBackground.container(
        context: context,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.emptyFolder,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
                onPressed: _refreshFileList,
              ),
            ],
          ),
        ),
      );
    }

    // Determine view mode based on user preference
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FluentBackground(
          blurAmount: 8.0,
          opacity: 0.2,
          enableBlur: true,
          child: GestureDetector(
            onTap: () {
              if (selectionState.isSelectionMode) {
                _clearSelection();
              }
            },
            onSecondaryTapUp: (details) {
              _showContextMenu(context, details.globalPosition, null);
            },
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
            child: _viewMode == ViewMode.grid
                ? _buildGridView(folders, files, selectionState)
                : _viewMode == ViewMode.details
                    ? _buildDetailsView(folders, files, selectionState)
                    : _buildListView(folders, files, selectionState),
          ),
        ),
        _buildDragSelectionOverlay(),
      ],
    );
  }

  // Build grid view
  Widget _buildGridView(List<FileSystemEntity> folders,
      List<FileSystemEntity> files, SelectionState selectionState) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      cacheExtent: 1000,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridZoomLevel,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        final String itemPath = index < folders.length
            ? folders[index].path
            : files[index - folders.length].path;
        final bool isSelected = selectionState.isPathSelected(itemPath);

        return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final RenderBox? renderBox =
                context.findRenderObject() as RenderBox?;
            if (renderBox != null && renderBox.hasSize) {
              final position = renderBox.localToGlobal(Offset.zero);
              _registerItemPosition(
                  itemPath,
                  Rect.fromLTWH(position.dx, position.dy, renderBox.size.width,
                      renderBox.size.height));
            }
          });

          if (index < folders.length) {
            final folder = folders[index] as Directory;
            return Stack(
              children: [
                KeyedSubtree(
                  key: ValueKey('folder-grid-${folder.path}'),
                  child: RepaintBoundary(
                    child: FluentBackground.container(
                      context: context,
                      padding: EdgeInsets.zero,
                      blurAmount: 5.0,
                      opacity: isSelected ? 0.8 : 0.6,
                      backgroundColor: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.6)
                          : Theme.of(context).cardColor.withOpacity(0.4),
                      child: folder_list_components.FolderGridItem(
                        key: ValueKey('folder-grid-item-${folder.path}'),
                        folder: folder,
                        onNavigate: (path) {
                          // Show loading indicator before navigating
                          setState(() {
                            _isLoadingStarted = true;
                          });
                          _navigateToPath(path);
                        },
                        isSelected: isSelected,
                        toggleFolderSelection: _toggleFolderSelection,
                        isDesktopMode: true,
                        lastSelectedPath: selectionState.lastSelectedPath,
                        clearSelectionMode: _clearSelection,
                      ),
                    ),
                  ),
                ),
                // Overlay loading indicator for this specific folder if it's being loaded
                if (_isLoadingStarted && _currentPath == folder.path)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            final file = files[index - folders.length] as File;
            return KeyedSubtree(
              key: ValueKey('file-grid-${file.path}'),
              child: RepaintBoundary(
                child: FluentBackground.container(
                  context: context,
                  padding: EdgeInsets.zero,
                  blurAmount: 5.0,
                  opacity: isSelected ? 0.8 : 0.6,
                  backgroundColor: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.6)
                      : Theme.of(context).cardColor.withOpacity(0.4),
                  child: folder_list_components.FileGridItem(
                    key: ValueKey('file-grid-item-${file.path}'),
                    file: file,
                    state: FolderListState(_currentPath),
                    isSelectionMode: selectionState.isSelectionMode,
                    isSelected: isSelected,
                    toggleFileSelection: _toggleFileSelection,
                    toggleSelectionMode: _toggleSelectionMode,
                    onFileTap: (file, isVideo) {
                      // Show loading indicator before opening file
                      setState(() {
                        _isLoadingStarted = true;
                      });
                      _onFileTap(file, isVideo);
                      // Reset loading state after a short delay
                      Future.delayed(Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _isLoadingStarted = false;
                          });
                        }
                      });
                    },
                    isDesktopMode: true,
                    lastSelectedPath: selectionState.lastSelectedPath,
                  ),
                ),
              ),
            );
          }
        });
      },
    );
  }

  // Build details view
  Widget _buildDetailsView(List<FileSystemEntity> folders,
      List<FileSystemEntity> files, SelectionState selectionState) {
    return folder_list_components.FileView(
      files: files.whereType<File>().toList(),
      folders: folders.whereType<Directory>().toList(),
      state: FolderListState(_currentPath),
      isSelectionMode: selectionState.isSelectionMode,
      isGridView: false,
      selectedFiles: selectionState.allSelectedPaths,
      toggleFileSelection: _toggleFileSelection,
      toggleSelectionMode: _toggleSelectionMode,
      showDeleteTagDialog: _showDeleteTagDialog,
      showAddTagToFileDialog: _showAddTagToFileDialog,
      onFolderTap: _navigateToPath,
      onFileTap: _onFileTap,
      isDesktopMode: true,
      lastSelectedPath: selectionState.lastSelectedPath,
      columnVisibility: _columnVisibility,
    );
  }

  // Build list view
  Widget _buildListView(List<FileSystemEntity> folders,
      List<FileSystemEntity> files, SelectionState selectionState) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      cacheExtent: 500,
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        final String itemPath = index < folders.length
            ? folders[index].path
            : files[index - folders.length].path;
        final bool isSelected = selectionState.isPathSelected(itemPath);

        return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final RenderBox? renderBox =
                context.findRenderObject() as RenderBox?;
            if (renderBox != null && renderBox.hasSize) {
              final position = renderBox.localToGlobal(Offset.zero);
              _registerItemPosition(
                  itemPath,
                  Rect.fromLTWH(position.dx, position.dy, renderBox.size.width,
                      renderBox.size.height));
            }
          });

          if (index < folders.length) {
            final folder = folders[index] as Directory;
            return Stack(
              children: [
                KeyedSubtree(
                  key: ValueKey("folder-${folder.path}"),
                  child: FluentBackground(
                    blurAmount: 3.0,
                    opacity: isSelected ? 0.7 : 0.0,
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
                        onTap: (path) {
                          // Show loading indicator before navigating
                          setState(() {
                            _isLoadingStarted = true;
                          });
                          _navigateToPath(path);
                        },
                        isSelected: isSelected,
                        toggleFolderSelection: _toggleFolderSelection,
                        isDesktopMode: true,
                        lastSelectedPath: selectionState.lastSelectedPath,
                      ),
                    ),
                  ),
                ),
                // Overlay loading indicator for this specific folder if it's being loaded
                if (_isLoadingStarted && _currentPath == folder.path)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            final file = files[index - folders.length] as File;
            return KeyedSubtree(
              key: ValueKey("file-${file.path}"),
              child: FluentBackground(
                blurAmount: 3.0,
                opacity: isSelected ? 0.7 : 0.0,
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
                    state: FolderListState(_currentPath),
                    isSelectionMode: selectionState.isSelectionMode,
                    isSelected: isSelected,
                    toggleFileSelection: _toggleFileSelection,
                    showDeleteTagDialog: _showDeleteTagDialog,
                    showAddTagToFileDialog: _showAddTagToFileDialog,
                    onFileTap: (file, isVideo) {
                      // Show loading indicator before opening file
                      setState(() {
                        _isLoadingStarted = true;
                      });
                      _onFileTap(file, isVideo);
                      // Reset loading state after a short delay
                      Future.delayed(Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _isLoadingStarted = false;
                          });
                        }
                      });
                    },
                    isDesktopMode: true,
                    lastSelectedPath: selectionState.lastSelectedPath,
                  ),
                ),
              ),
            );
          }
        });
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final selectionState = context.read<SelectionBloc>().state;
    final int totalCount = selectionState.selectedCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $totalCount network items?'),
        content: const Text(
            'These items will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Network delete logic here
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delete not implemented yet.')));
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

  void _handleGridZoomChange(int zoomLevel) {
    _saveGridZoomSetting(zoomLevel);
  }

  void _onFileTap(File file, bool isVideo) {
    // Stop any ongoing thumbnail processing when opening a file
    VideoThumbnailHelper.stopAllProcessing();

    // For network files, we download instead of directly opening
    if (_currentPath.startsWith('#network/')) {
      _downloadFile(context, file.path);
      return;
    }

    // For local files, use the original behavior...
    // Get file extension
    String extension = file.path.split('.').last.toLowerCase();

    // Use lists to check file types
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v'];
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    final isVideoFile = videoExtensions.contains(extension);

    // Open file based on file type
    if (isVideoFile) {
      // Open video in video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomVideoPlayer(file: file),
        ),
      );
    } else if (imageExtensions.contains(extension)) {
      // Open image in image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            file: file,
          ),
        ),
      );
    } else {
      // For other file types, try to open with default app
      ExternalAppHelper.openFileWithApp(file.path, 'shell_open');
    }
  }

  void _handleMouseBackButton() {
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateBack(widget.tabId)) {
      final previousPath = tabManagerBloc.getTabPreviousPath(widget.tabId);
      if (previousPath != null) {
        tabManagerBloc.backNavigationToPath(widget.tabId);
        _navigateToPath(previousPath);
      }
    }
  }

  void _showContextMenu(
      BuildContext context, Offset position, String? itemPath) {
    final List<PopupMenuEntry<String>> menuItems = [];

    // Basic operations for all contexts
    menuItems.add(
      PopupMenuItem<String>(
        value: 'refresh',
        child: ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(AppLocalizations.of(context)?.refresh ?? 'Refresh'),
        ),
      ),
    );

    // File specific operations
    if (itemPath != null && itemPath.isNotEmpty) {
      final isFolder = !itemPath.contains('.');

      if (!isFolder) {
        // Download file option
        menuItems.add(
          PopupMenuItem<String>(
            value: 'download_$itemPath',
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(AppLocalizations.of(context)?.download ?? 'Download'),
            ),
          ),
        );
      }
    }

    // Add upload option for current directory
    menuItems.add(
      PopupMenuItem<String>(
        value: 'upload',
        child: ListTile(
          leading: const Icon(Icons.upload),
          title: Text(AppLocalizations.of(context)?.upload ?? 'Upload File'),
        ),
      ),
    );

    // Add new folder option
    menuItems.add(
      PopupMenuItem<String>(
        value: 'new_folder',
        child: ListTile(
          leading: const Icon(Icons.create_new_folder),
          title: Text(AppLocalizations.of(context)?.newFolder ?? 'New Folder'),
        ),
      ),
    );

    // Show popup menu
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: menuItems,
    ).then((value) {
      if (value == null) return;

      if (value == 'refresh') {
        _refreshFileList();
      } else if (value == 'upload') {
        _showUploadDialog(context);
      } else if (value == 'new_folder') {
        _showCreateFolderDialog(context);
      } else if (value.startsWith('download_')) {
        final path = value.substring('download_'.length);
        _downloadFile(context, path);
      }
    });
  }

  void _handleMouseForwardButton() {
    final tabManagerBloc = context.read<TabManagerBloc>();
    if (tabManagerBloc.canTabNavigateForward(widget.tabId)) {
      final nextPath = tabManagerBloc.getTabNextPath(widget.tabId);
      if (nextPath != null) {
        final String? actualPath =
            tabManagerBloc.forwardNavigationToPath(widget.tabId);
        if (actualPath != null) {
          _navigateToPath(actualPath);
        }
      }
    }
  }

  void _handleZoomLevelChange(int direction) {
    final currentZoom = _gridZoomLevel;
    final newZoom = (currentZoom + direction).clamp(
      UserPreferences.minGridZoomLevel,
      UserPreferences.maxGridZoomLevel,
    );

    if (newZoom != currentZoom) {
      _saveGridZoomSetting(newZoom);
    }
  }

  void _startDragSelection(Offset position) {
    if (_isDraggingNotifier.value) return;
    _isDraggingNotifier.value = true;
    _dragStartPositionNotifier.value = position;
    _dragCurrentPositionNotifier.value = position;
  }

  void _updateDragSelection(Offset position) {
    if (!_isDraggingNotifier.value) return;
    _dragCurrentPositionNotifier.value = position;
    if (_dragStartPositionNotifier.value != null) {
      final selectionRect = Rect.fromPoints(_dragStartPositionNotifier.value!,
          _dragCurrentPositionNotifier.value!);
      _selectItemsInRect(selectionRect);
    }
  }

  void _endDragSelection() {
    _isDraggingNotifier.value = false;
    _dragStartPositionNotifier.value = null;
    _dragCurrentPositionNotifier.value = null;
  }

  void _registerItemPosition(String path, Rect position) {
    _itemPositions[path] = position;
  }

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
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SelectionRectanglePainter(
                selectionRect: selectionRect,
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

  void _selectItemsInRect(Rect selectionRect) {
    if (!_isDraggingNotifier.value) return;

    final RawKeyboard keyboard = RawKeyboard.instance;
    final bool isCtrlPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlRight);
    final bool isShiftPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftRight);

    final Set<String> selectedFoldersInDrag = {};
    final Set<String> selectedFilesInDrag = {};

    final networkState = _networkBrowsingBloc.state;
    final allItems = [
      ...(networkState.directories ?? []),
      ...(networkState.files ?? [])
    ];

    _itemPositions.forEach((path, itemRect) {
      if (selectionRect.overlaps(itemRect)) {
        if (networkState.directories?.any((folder) => folder.path == path) ??
            false) {
          selectedFoldersInDrag.add(path);
        } else {
          selectedFilesInDrag.add(path);
        }
      }
    });

    _selectionBloc.add(SelectItemsInRect(
      folderPaths: selectedFoldersInDrag,
      filePaths: selectedFilesInDrag,
      isCtrlPressed: isCtrlPressed,
      isShiftPressed: isShiftPressed,
    ));
  }

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.uploadFile ?? 'Upload File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)?.selectFileToUpload ??
                'Select file to upload:'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Use file picker to select file to upload
                final result = await FilePicker.platform.pickFiles();

                if (result != null &&
                    result.files.single.path != null &&
                    mounted) {
                  final filePath = result.files.single.path!;
                  final fileName = result.files.single.name;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Uploading $fileName...')),
                  );

                  // Start upload
                  _startFileUpload(filePath, '$_currentPath/$fileName');
                }
              },
              child: Text(AppLocalizations.of(context)?.browse ?? 'Browse...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  // Method to start file upload
  void _startFileUpload(String localPath, String remotePath) {
    // Show loading indicator
    setState(() {
      _isLoadingStarted = true;
    });

    // Create a progress indicator dialog
    final progressDialogKey = GlobalKey<State>();
    double uploadProgress = 0.0;
    bool isIndeterminate = false;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          key: progressDialogKey,
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                  AppLocalizations.of(context)?.uploadFile ?? 'Uploading File'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Uploading file...'),
                  const SizedBox(height: 20),
                  isIndeterminate
                      ? const LinearProgressIndicator()
                      : LinearProgressIndicator(value: uploadProgress),
                  const SizedBox(height: 10),
                  Text('${(uploadProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            );
          },
        );
      },
    );

    // Get service from registry
    final service = _networkBrowsingBloc.state.currentService;
    if (service == null) {
      setState(() {
        _isLoadingStarted = false;
      });
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No network service available')),
      );
      return;
    }

    // Progress callback
    void onProgress(double progress) {
      debugPrint("NetworkBrowser: Upload progress update: $progress");
      final dialogState = progressDialogKey.currentState;
      if (dialogState != null && dialogState.mounted) {
        dialogState.setState(() {
          if (progress < 0) {
            isIndeterminate = true;
          } else {
            isIndeterminate = false;
            uploadProgress = progress;
          }
        });
      }
    }

    // Start upload with progress
    service
        .putFileWithProgress(localPath, remotePath, onProgress)
        .then((success) {
      if (mounted) {
        setState(() {
          _isLoadingStarted = false;
        });
        Navigator.of(context).pop(); // Close progress dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully')),
          );

          // Refresh directory
          _refreshFileList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error uploading file')),
          );
        }
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoadingStarted = false;
        });
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $error')),
        );
      }
    });
  }

  // Method to show create folder dialog
  void _showCreateFolderDialog(BuildContext context) {
    final TextEditingController folderNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.newFolder ?? 'New Folder'),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText:
                AppLocalizations.of(context)?.folderName ?? 'Folder Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final folderName = folderNameController.text.trim();
              if (folderName.isEmpty) return;

              Navigator.pop(context);
              _createFolder('$_currentPath/$folderName');
            },
            child: Text(AppLocalizations.of(context)?.create ?? 'Create'),
          ),
        ],
      ),
    );
  }

  // Method to create a folder
  void _createFolder(String path) {
    // Show loading indicator
    setState(() {
      _isLoadingStarted = true;
    });

    // Get service from registry
    final service = _networkBrowsingBloc.state.currentService;
    if (service == null) {
      setState(() {
        _isLoadingStarted = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No network service available')),
      );
      return;
    }

    // Create folder
    service.createDirectory(path).then((_) {
      if (mounted) {
        setState(() {
          _isLoadingStarted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder created successfully')),
        );

        // Refresh directory
        _refreshFileList();
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoadingStarted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating folder: $error')),
        );
      }
    });
  }

  // Method to handle file downloading
  void _downloadFile(BuildContext screenContext, String filePath) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext)?.downloadFile ??
            'Download File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(dialogContext)?.selectDownloadLocation ??
                'Select location to save the file:'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // Pop the current dialog.
                Navigator.pop(dialogContext);

                // Now, we use the screenContext for anything that happens outside the dialog.
                // It's safer to capture these before an async gap.
                final localizations = AppLocalizations.of(screenContext);
                final scaffoldMessenger = ScaffoldMessenger.of(screenContext);

                final String? result =
                    await FilePicker.platform.getDirectoryPath(
                  dialogTitle: localizations?.selectFolder ?? 'Select folder',
                );

                // After an async operation, always check if the widget is still in the tree.
                if (!mounted) return;

                if (result != null) {
                  final fileName = filePath.split('/').last;
                  final localPath = '$result${Platform.pathSeparator}$fileName';

                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Downloading $fileName...')),
                  );

                  _startFileDownload(filePath, localPath);
                }
              },
              child: Text(
                  AppLocalizations.of(dialogContext)?.browse ?? 'Browse...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(dialogContext)?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  // Method to start file download
  void _startFileDownload(String remotePath, String localPath) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Please select a folder to save the file',
      );

      if (selectedDirectory != null) {
        final String fileName = path.basename(remotePath);
        final String localPath = path.join(selectedDirectory, fileName);

        // Show loading indicator
        setState(() {
          _isLoadingStarted = true;
        });

        debugPrint(
            "NetworkBrowser: Starting file download: $remotePath -> $localPath");

        // Create a progress indicator dialog
        final progressDialogKey = GlobalKey<State>();
        double downloadProgress = 0.0;
        bool isIndeterminate = false;

        // Show progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(
              key: progressDialogKey,
              builder: (context, setState) {
                return AlertDialog(
                  title: Text(AppLocalizations.of(context)?.downloadFile ??
                      'Downloading File'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Downloading file...'),
                      const SizedBox(height: 20),
                      isIndeterminate
                          ? const LinearProgressIndicator()
                          : LinearProgressIndicator(value: downloadProgress),
                      const SizedBox(height: 10),
                      Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                );
              },
            );
          },
        );

        // Get service from registry
        final service = _networkBrowsingBloc.state.currentService;
        debugPrint("NetworkBrowser: Using service: ${service?.serviceName}");

        if (service == null) {
          setState(() {
            _isLoadingStarted = false;
          });
          Navigator.of(context).pop(); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No network service available')),
          );
          return;
        }

        // Progress callback
        void onProgress(double progress) {
          debugPrint("NetworkBrowser: Download progress update: $progress");
          final dialogState = progressDialogKey.currentState;
          if (dialogState != null && dialogState.mounted) {
            dialogState.setState(() {
              if (progress < 0) {
                isIndeterminate = true;
              } else {
                isIndeterminate = false;
                downloadProgress = progress;
              }
            });
          }
        }

        debugPrint("NetworkBrowser: Calling getFileWithProgress...");

        // Start download with progress
        service
            .getFileWithProgress(remotePath, localPath, onProgress)
            .then((file) {
          debugPrint(
              "NetworkBrowser: Download completed successfully: ${file.path}");
          if (mounted) {
            setState(() {
              _isLoadingStarted = false;
            });
            Navigator.of(context).pop(); // Close progress dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('File downloaded successfully to $localPath')),
            );
          }
        }).catchError((error, stackTrace) {
          debugPrint("NetworkBrowser: Download failed with error: $error");
          debugPrint("NetworkBrowser: Stack trace: $stackTrace");
          if (mounted) {
            setState(() {
              _isLoadingStarted = false;
            });
            Navigator.of(context).pop(); // Close progress dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error downloading file: $error')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("NetworkBrowser: Error picking directory: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting folder: $e')),
      );
    }
  }

  // Helper methods for tag dialog calls
  void _showDeleteTagDialog(
      BuildContext context, String filePath, List<String> tags) {
    // Hiển thị thông báo tạm thời rằng tính năng chưa được hỗ trợ cho network locations
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Tags are not supported for network locations')),
    );
  }

  void _showAddTagToFileDialog(BuildContext context, String filePath) {
    // Hiển thị thông báo tạm thời rằng tính năng chưa được hỗ trợ cho network locations
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Tags are not supported for network locations')),
    );
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
      ..strokeWidth = 1.5;

    final RRect roundedRect = RRect.fromRectAndRadius(
      selectionRect,
      const Radius.circular(4.0),
    );

    canvas.drawRRect(roundedRect, fillPaint);
    canvas.drawRRect(roundedRect, borderPaint);

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
