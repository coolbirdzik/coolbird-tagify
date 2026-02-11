import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Import for keyboard shortcuts
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/helpers/ui/frame_timing_optimizer.dart';
import 'tab_manager.dart';
import '../../drawer.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'tabbed_folder/tabbed_folder_list_screen.dart';
import '../../screens/settings/settings_screen.dart';
import 'package:flutter/gestures.dart'; // Import for mouse scrolling
import '../desktop/scrollable_tab_bar.dart'; // Import our custom ScrollableTabBar
import '../mobile/mobile_tab_view.dart'; // Import giao diện mobile kiểu Chrome
import 'package:cb_file_manager/config/languages/app_localizations.dart'; // Import AppLocalizations
import 'package:cb_file_manager/config/translation_helper.dart'; // Import translation helper
import 'package:cb_file_manager/ui/screens/system_screen_router.dart'; // Import system screen router
// import 'package:cb_file_manager/widgets/test_native_streaming.dart'; // Test widget removed
import '../../utils/route.dart';
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart'; // Import filesystem utils
import '../../screens/home/home_screen.dart'; // Import home screen

// Create a custom scroll behavior that supports mouse wheel scrolling
class TabBarMouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        ...super.dragDevices,
      };
}

/// A screen that manages and displays tabbed content
class TabScreen extends StatefulWidget {
  const TabScreen({Key? key}) : super(key: key);

  @override
  State<TabScreen> createState() => _TabScreenState();
}

// Create a new tab action for keyboard shortcuts
class CreateNewTabIntent extends Intent {
  const CreateNewTabIntent();
}

// Create a close tab action for keyboard shortcuts
class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

// Create actions for switching to specific tabs
class SwitchToTabIntent extends Intent {
  final int tabIndex;
  const SwitchToTabIntent(this.tabIndex);
}

class _TabScreenState extends State<TabScreen> with TickerProviderStateMixin {
  // Drawer state variables
  bool _isDrawerPinned = false;

  // Key for the scaffold to control drawer programmatically
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controller cho TabBar tích hợp
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize with a temporary controller. It will be properly set in postFrameCallback.
    _tabController = TabController(length: 0, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrawerPreferences();
      if (mounted) {
        final initialState = context.read<TabManagerBloc>().state;
        // _updateTabController will create the controller with the correct length
        // and set its initialIndex based on the initialState from BLoC.
        _updateTabController(initialState.tabs.length);
      }
    });
  }

  @override
  void didUpdateWidget(TabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Content removed: BlocBuilder now handles all TabController updates
    // based on TabManagerBloc state.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabController(int tabCount) {
    final oldController = _tabController;

    // Determine the initialIndex for the new TabController based on current BLoC state.
    int newInitialIndex = 0;
    if (mounted) {
      // Ensure context is valid for reading BLoC
      final currentState = context.read<TabManagerBloc>().state;
      if (currentState.activeTabId != null && tabCount > 0) {
        final activeIndexFromBloc = currentState.tabs
            .indexWhere((tab) => tab.id == currentState.activeTabId);
        if (activeIndexFromBloc >= 0 && activeIndexFromBloc < tabCount) {
          newInitialIndex = activeIndexFromBloc;
        } else if (tabCount > 0) {
          // Fallback if activeId is somehow invalid
          newInitialIndex =
              (oldController.index < tabCount && oldController.index >= 0)
                  ? oldController.index
                  : tabCount - 1;
        }
      } else if (tabCount > 0) {
        // No activeTabId, but tabs exist
        newInitialIndex =
            (oldController.index < tabCount && oldController.index >= 0)
                ? oldController.index
                : 0;
      }
    } else if (tabCount > 0) {
      // Fallback if not mounted (less ideal)
      newInitialIndex =
          (oldController.index < tabCount && oldController.index >= 0)
              ? oldController.index
              : 0;
    }

    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: newInitialIndex, // Set based on BLoC's active tab
    );
    oldController.dispose();

    if (mounted) {
      // This setState is crucial for the UI to pick up the new _tabController instance
      setState(() {});
    }
  }

  // Load drawer preferences from storage
  Future<void> _loadDrawerPreferences() async {
    try {
      // Get the UserPreferences singleton instance without reinitializing
      final UserPreferences prefs = UserPreferences.instance;
      final drawerPinned = await prefs.getDrawerPinned();

      if (mounted) {
        setState(() {
          // Only set drawer to pinned if not on a small screen
          final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
          _isDrawerPinned = isSmallScreen ? false : drawerPinned;
        });
      }
    } catch (e) {
      debugPrint('Error loading drawer preferences: $e');
    }
  }

  // Save drawer pinned state
  Future<void> _saveDrawerPinned(bool isPinned) async {
    try {
      // Get the UserPreferences singleton instance without reinitializing
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.setDrawerPinned(isPinned);
    } catch (e) {
      debugPrint('Error saving drawer pinned state: $e');
    }
  }

  // Toggle drawer pin state
  void _toggleDrawerPin() {
    // Check if we're on a small screen
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    setState(() {
      // Only allow pinning on larger screens
      if (!isSmallScreen) {
        _isDrawerPinned = !_isDrawerPinned;
        _saveDrawerPinned(_isDrawerPinned);
      } else {
        // Force unpinned on small screens and show a message
        _isDrawerPinned = false;
        _saveDrawerPinned(false);

        // Show a message explaining why pinning isn't available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.menuPinningOnlyLargeScreens),
              duration: const Duration(seconds: 2),
            ),
          );
        });
      }
    });
  }

  // Xác định thiết bị là tablet hay điện thoại dựa trên kích thước màn hình
  bool _isTablet(BuildContext context) {
    // Coi rộng > 600dp là tablet, theo Material Design guidelines
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  // Method to close the current active tab
  void _handleCloseCurrentTab() {
    final state = context.read<TabManagerBloc>().state;
    final activeTab = state.activeTab;
    if (activeTab != null) {
      context.read<TabManagerBloc>().add(CloseTab(activeTab.id));
    }
  }

  // Method to switch to a specific tab by index
  void _handleSwitchToTab(int tabIndex) {
    final state = context.read<TabManagerBloc>().state;
    // Check if the tab index is valid
    if (tabIndex >= 0 && tabIndex < state.tabs.length) {
      // Switch to the tab
      context.read<TabManagerBloc>().add(SwitchToTab(state.tabs[tabIndex].id));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply frame timing optimization before building the tabbed interface
    // This helps prevent the "Reported frame time is older than the last one" error
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    // Xác định xem thiết bị có phải là tablet hay không
    final isTablet = _isTablet(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return BlocBuilder<TabManagerBloc, TabManagerState>(
      builder: (context, state) {
        // 1. Handle TabController LENGTH update (if needed)
        if (isTablet && _tabController.length != state.tabs.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Re-read latest state to ensure consistency for the update.
              final latestStateForLengthUpdate =
                  context.read<TabManagerBloc>().state;
              if (_tabController.length !=
                  latestStateForLengthUpdate.tabs.length) {
                // _updateTabController now sets the correct initialIndex from BLoC state
                _updateTabController(latestStateForLengthUpdate.tabs.length);
              }
            }
          });
        }
        // 2. Handle TabController INDEX synchronization if length is already correct.
        // This covers cases where the active tab changes without a change in tab count.
        // If _updateTabController was just called, the new controller it created
        // should already have the correct initialIndex, making this animation redundant for that specific frame.
        // However, this handles clicks on tabs that don't change the tab count.
        else if (isTablet &&
            state.activeTabId != null &&
            state.tabs.isNotEmpty) {
          final activeIndexFromBloc =
              state.tabs.indexWhere((tab) => tab.id == state.activeTabId);
          if (activeIndexFromBloc >= 0 &&
              activeIndexFromBloc < _tabController.length) {
            if (_tabController.index != activeIndexFromBloc) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Re-read state to ensure we're acting on the most current information.
                  final latestStateForSync =
                      context.read<TabManagerBloc>().state;
                  if (latestStateForSync.activeTabId != null &&
                      latestStateForSync.tabs.isNotEmpty &&
                      _tabController.length == latestStateForSync.tabs.length) {
                    // Check length again

                    final latestActiveIndex = latestStateForSync.tabs
                        .indexWhere(
                            (tab) => tab.id == latestStateForSync.activeTabId);
                    if (latestActiveIndex >= 0 &&
                        latestActiveIndex < _tabController.length) {
                      if (_tabController.index != latestActiveIndex) {
                        _tabController.animateTo(latestActiveIndex);
                      }
                    }
                  }
                }
              });
            }
          }
        }

        // Define keyboard shortcuts and actions
        final Map<ShortcutActivator, Intent> shortcuts = {
          // Create new tab with Ctrl+T
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT):
              const CreateNewTabIntent(),
          // Close current tab with Ctrl+W
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
              const CloseTabIntent(),
          // Switch to tabs 1-9 with Ctrl+1, Ctrl+2, etc.
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
              const SwitchToTabIntent(0),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2):
              const SwitchToTabIntent(1),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3):
              const SwitchToTabIntent(2),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4):
              const SwitchToTabIntent(3),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit5):
              const SwitchToTabIntent(4),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit6):
              const SwitchToTabIntent(5),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit7):
              const SwitchToTabIntent(6),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit8):
              const SwitchToTabIntent(7),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit9):
              const SwitchToTabIntent(8),
        };

        final Map<Type, Action<Intent>> actions = {
          CreateNewTabIntent: CallbackAction<CreateNewTabIntent>(
            onInvoke: (CreateNewTabIntent intent) {
              // Use HapticFeedback for better user experience
              HapticFeedback.mediumImpact();
              // Force create new tab with FocusScope to ensure keyboard events are captured properly
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _handleAddNewTab();
              });
              return null;
            },
          ),
          CloseTabIntent: CallbackAction<CloseTabIntent>(
            onInvoke: (CloseTabIntent intent) => _handleCloseCurrentTab(),
          ),
          SwitchToTabIntent: CallbackAction<SwitchToTabIntent>(
            onInvoke: (SwitchToTabIntent intent) =>
                _handleSwitchToTab(intent.tabIndex),
          ),
        };

        return Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: actions,
            child: FocusScope(
              autofocus: true,
              child: Builder(
                builder: (popContext) {
                  return PopScope(
                    canPop: false, // Always intercept back button
                    onPopInvokedWithResult: (didPop, result) async {
                      if (!didPop) {
                        try {
                          // First, check if there are any screens pushed on the active tab's navigator
                          // (like video player, image viewer, etc.)
                          final activeTab = state.activeTab;

                          if (activeTab != null) {
                            final tabNavigatorState =
                                activeTab.navigatorKey.currentState;
                            if (tabNavigatorState != null &&
                                tabNavigatorState.canPop()) {
                              tabNavigatorState.pop();
                              return;
                            }
                          }

                          // Then check main navigator
                          final mainNavigator = Navigator.of(popContext);
                          if (mainNavigator.canPop()) {
                            mainNavigator.pop();
                            return;
                          }

                          // Handle tab navigation history
                          if (activeTab != null) {
                            // Check if the active tab can navigate back
                            if (activeTab.navigationHistory.length > 1) {
                              // Use the proper backNavigationToPath method
                              final tabManagerBloc =
                                  context.read<TabManagerBloc>();
                              tabManagerBloc.backNavigationToPath(activeTab.id);
                              return;
                            }
                          }

                          // If we're at the root (no history), exit app
                          SystemNavigator.pop();
                        } catch (e) {
                          debugPrint('Error in TabScreen PopScope: $e');
                        }
                      }
                    },
                    child: Scaffold(
                      key: _scaffoldKey,
                      // Modern AppBar, always present on tablet/desktop for custom title bar
                      appBar: isTablet
                          ? AppBar(
                              elevation: 0,
                              backgroundColor: theme.scaffoldBackgroundColor,
                              // Always show ScrollableTabBar in the title for Windows (isTablet)
                              // It handles its own content (tabs or add button) and window controls.
                              title: ScrollConfiguration(
                                behavior: TabBarMouseScrollBehavior(),
                                child: ScrollableTabBar(
                                  controller:
                                      _tabController, // Ensure this controller has the correct length
                                  onTap: (index) {
                                    // Only handle tab switching for valid tabs
                                    if (index < state.tabs.length) {
                                      // Dispatch event to change active tab
                                      context.read<TabManagerBloc>().add(
                                          SwitchToTab(state.tabs[index].id));
                                    }
                                  },
                                  // Add tab close callback
                                  onTabClose: (index) {
                                    if (index < state.tabs.length) {
                                      context
                                          .read<TabManagerBloc>()
                                          .add(CloseTab(state.tabs[index].id));
                                    }
                                  },
                                  // Keep the add tab button functionality
                                  onAddTabPressed: _handleAddNewTab,
                                  tabs: [
                                    // Generate modern-style tabs from state.tabs
                                    ...state.tabs.map((tab) {
                                      return Tab(
                                        height: 38,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (tab.isLoading) ...[
                                                const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Icon(
                                                tab.isPinned
                                                    ? remix.Remix.pushpin_fill
                                                    : tab.icon ??
                                                        remix.Remix
                                                            .folder_3_line,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  tab.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                              actions: [
                                // Modern menu button
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: IconButton(
                                    icon: Icon(
                                      remix.Remix.more_2_line,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : theme.colorScheme.primary,
                                      size: 22,
                                    ),
                                    style: IconButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      backgroundColor: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.03)
                                          : theme.colorScheme.primary
                                              .withValues(alpha: 0.05),
                                    ),
                                    onPressed: () => _showTabOptions(context),
                                  ),
                                ),
                              ],
                            )
                          : null, // No AppBar for mobile interface
                      drawer: !_isDrawerPinned
                          ? CBDrawer(
                              context,
                              isPinned: _isDrawerPinned,
                              onPinStateChanged: (isPinned) {
                                _toggleDrawerPin();
                              },
                            )
                          : null,
                      body: Row(
                        children: [
                          // Pinned drawer (if enabled)
                          if (_isDrawerPinned)
                            SizedBox(
                              width: 280,
                              child: CBDrawer(
                                context,
                                isPinned: _isDrawerPinned,
                                onPinStateChanged: (isPinned) {
                                  _toggleDrawerPin();
                                },
                              ),
                            ),
                          // Main content area with subtle container styling
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: _buildContent(context, state, isTablet),
                              ),
                            ),
                          ),
                        ],
                      ),
                      floatingActionButton: state.tabs.isEmpty
                          ? FloatingActionButton(
                              heroTag:
                                  null, // Disable hero animation to avoid conflicts
                              onPressed: _handleAddNewTab,
                              tooltip: context.tr.newFolder,
                              elevation: 2,
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                remix.Remix.add_line,
                                size: 24,
                              ),
                            )
                          : null,
                    ), // Scaffold
                  ); // PopScope
                }, // builder function
              ), // Builder
            ), // FocusScope
          ), // Actions
        ); // Shortcuts
      }, // BlocBuilder builder function
    ); // BlocBuilder
  }

  // Phương thức mới để xây dựng nội dung dựa trên loại thiết bị
  Widget _buildContent(
      BuildContext context, TabManagerState state, bool isTablet) {
    // Giao diện cho tablet sử dụng UI hiện tại
    if (isTablet) {
      if (state.tabs.isEmpty) {
        return const HomeScreen(
          tabId: 'home', // Use a special ID for home screen
        );
      }
      return _buildTabContent(state);
    }
    // Giao diện cho mobile luôn sử dụng kiểu Chrome, ngay cả khi không có tab
    else {
      // On mobile, ensure we always have a home tab for navigation history
      if (state.tabs.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<TabManagerBloc>().add(AddTab(
                  path: '#home',
                  name: 'Home',
                  switchToTab: true,
                ));
          }
        });
      }
      return MobileTabView(
        onAddNewTab: _handleAddNewTab,
      );
    }
  }

  // ...existing code...

  Widget _buildTabContent(TabManagerState state) {
    if (state.tabs.isEmpty) return Container();

    final activeTabId = state.activeTabId;
    final activeIndex = activeTabId == null
        ? 0
        : state.tabs.indexWhere((tab) => tab.id == activeTabId);

    final safeActiveIndex =
        activeIndex >= 0 && activeIndex < state.tabs.length ? activeIndex : 0;

    final children = state.tabs.map((tab) {
      Widget content;

      if (tab.path.startsWith('#')) {
        content =
            SystemScreenRouter.routeSystemPath(context, tab.path, tab.id) ??
                Container();
      } else {
        content = TabbedFolderListScreen(
          key: ValueKey(tab.id),
          path: tab.path,
          tabId: tab.id,
        );
      }

      return KeyedSubtree(
        key: ValueKey(tab.id),
        child: RepaintBoundary(
          key: tab.repaintBoundaryKey,
          child: content,
        ),
      );
    }).toList();

    return IndexedStack(
      index: safeActiveIndex,
      children: children,
    );
  }

  Future<void> _handleAddNewTab() async {
    // Always create new tab with home page
    if (mounted) {
      context.read<TabManagerBloc>().add(AddTab(path: '#home', name: context.tr.homeTab));
    }
  }

  /// Helper method to create fallback tab
  void _createFallbackTab() {
    if (mounted) {
      try {
        context.read<TabManagerBloc>().add(AddTab(path: '#home', name: context.tr.homeTab));
      } catch (e) {
        debugPrint("Failed to create fallback tab: $e");
      }
    }
  }

  /// Helper method to get display name for storage path
  String _getStorageDisplayName(String path) {
    if (path.isEmpty) return 'Drives';

    // For Android, try to extract meaningful name
    if (Platform.isAndroid) {
      if (path.contains('/storage/emulated/0')) {
        return 'Internal Storage';
      } else if (path.contains('/storage/')) {
        // Extract UUID or storage identifier
        final parts = path.split('/');
        if (parts.length >= 3) {
          final storageId = parts[2];
          if (storageId.isNotEmpty && storageId != 'emulated') {
            return 'Storage $storageId';
          }
        }
      }
    }

    // For iOS or other cases, use the last part of the path
    final parts = path.split('/');
    final lastPart =
        parts.lastWhere((part) => part.isNotEmpty, orElse: () => '');
    return lastPart.isEmpty ? 'Root' : lastPart;
  }

  void _showTabOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? theme.colorScheme.surface : theme.colorScheme.surface;
    final textColor = isDarkMode
        ? theme.textTheme.bodyMedium?.color
        : theme.textTheme.bodyMedium?.color;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: backgroundColor,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog title
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                child: Row(
                  children: [
                    Text(
                      'Tab options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        remix.Remix.close_line,
                        size: 20,
                        color: textColor?.withValues(alpha: 0.7),
                      ),
                      onPressed: () => RouteUtils.safePopDialog(context),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Option items
              _buildOptionItem(
                context,
                icon: remix.Remix.add_circle_line,
                text: 'New tab',
                onTap: () {
                  RouteUtils.safePopDialog(context);
                  _handleAddNewTab();
                },
              ),
              _buildOptionItem(
                context,
                icon: remix.Remix.close_line,
                text: 'Close current tab',
                onTap: () {
                  RouteUtils.safePopDialog(context);
                  _handleCloseCurrentTab();
                },
              ),
              // Removed SMB Network and Network browsing entries.
              // Add 'Close all tabs' option
              _buildOptionItem(
                context,
                icon: remix.Remix.close_circle_line,
                text: 'Close all tabs',
                onTap: () {
                  RouteUtils.safePopDialog(context);
                  _handleCloseAllTabs();
                },
              ),
              _buildOptionItem(
                context,
                icon: remix.Remix.settings_3_line,
                text: 'Settings',
                onTap: () {
                  RouteUtils.safePopDialog(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              // Native Streaming Test removed - using flutter_vlc_player now
            ],
          ),
        ),
      ),
    );
  }

  // Close all open tabs
  void _handleCloseAllTabs() {
    try {
      final state = context.read<TabManagerBloc>().state;
      final tabs = List.of(state.tabs);
      for (final tab in tabs) {
        context.read<TabManagerBloc>().add(CloseTab(tab.id));
      }
    } catch (e) {
      debugPrint('Error closing all tabs: $e');
    }
  }

  // Helper method to build menu options
  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ...existing code...
}
