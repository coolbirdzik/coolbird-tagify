import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Import for keyboard shortcuts
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:eva_icons_flutter/eva_icons_flutter.dart'; // Import Eva Icons
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'tab_manager.dart';
import 'tab_data.dart';
import '../drawer.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'tabbed_folder_list_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'package:flutter/gestures.dart'; // Import for mouse scrolling
import 'scrollable_tab_bar.dart'; // Import our custom ScrollableTabBar
import 'mobile_tab_view.dart'; // Import giao diện mobile kiểu Chrome
import 'package:cb_file_manager/config/translation_helper.dart'; // Import translation helper
import 'package:cb_file_manager/ui/screens/system_screen_router.dart'; // Import system screen router

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
    // Initialize với 0 tab vì chúng ta sẽ tạo tab động
    _tabController = TabController(length: 0, vsync: this);

    // Load drawer preferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrawerPreferences();
    });
  }

  @override
  void didUpdateWidget(TabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Cập nhật TabController khi số lượng tab thay đổi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<TabManagerBloc>().state;
      if (_tabController.length != state.tabs.length) {
        _updateTabController(state.tabs.length);
        if (state.activeTabId != null) {
          final activeIndex =
              state.tabs.indexWhere((tab) => tab.id == state.activeTabId);
          if (activeIndex >= 0 && activeIndex < _tabController.length) {
            _tabController.animateTo(activeIndex);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabController(int tabCount) {
    final oldController = _tabController;
    _tabController = TabController(
      // Add +1 to include the "+" tab
      length: (tabCount > 0 ? tabCount : 1) + 1,
      vsync: this,
      initialIndex: oldController.index < tabCount ? oldController.index : 0,
    );
    oldController.dispose();

    // Đảm bảo TabController được cập nhật ngay lập tức khi có tab mới
    if (mounted) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu pinning is only available on larger screens'),
              duration: Duration(seconds: 2),
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

      // Force UI update to make active tab display correctly
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // This triggers a rebuild that ensures tab state is correctly reflected
          });
        }
      });
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
        // Cập nhật tab controller khi có sự thay đổi (chỉ cần cho UI tablet)
        if (isTablet && _tabController.length != state.tabs.length + 1) {
          // +1 to account for the "+" tab
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTabController(state.tabs.length);
          });
        }

        // Đồng bộ các tab đang hoạt động (chỉ cần cho UI tablet)
        if (isTablet &&
            state.activeTabId != null &&
            _tabController.length > 0) {
          final activeIndex =
              state.tabs.indexWhere((tab) => tab.id == state.activeTabId);
          if (activeIndex >= 0 &&
              activeIndex < state.tabs.length &&
              _tabController.index != activeIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tabController.animateTo(activeIndex);
            });
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
              child: WillPopScope(
                onWillPop: () async {
                  // Handle back button press - if any tab is open, navigate back in that tab
                  final activeTab = state.activeTab;
                  if (activeTab != null) {
                    final navigatorState = activeTab.navigatorKey.currentState;
                    if (navigatorState != null && navigatorState.canPop()) {
                      navigatorState.pop();
                      return false; // Don't close the app
                    }
                  }
                  return true; // Allow app to close
                },
                child: Scaffold(
                  key: _scaffoldKey,
                  // Modern AppBar only for tablet interface
                  appBar: isTablet
                      ? AppBar(
                          elevation: 0,
                          backgroundColor: theme.scaffoldBackgroundColor,
                          // Move TabBar to the title area instead of using bottom
                          title: state.tabs.isEmpty
                              ? Text(
                                  context.tr.appTitle,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : ScrollConfiguration(
                                  // Apply custom scroll behavior that supports mouse wheel scrolling
                                  behavior: TabBarMouseScrollBehavior(),
                                  child: ScrollableTabBar(
                                    controller: _tabController,
                                    onTap: (index) {
                                      // Only handle tab switching for valid tabs
                                      if (index < state.tabs.length) {
                                        // Dispatch event to change active tab
                                        context.read<TabManagerBloc>().add(
                                            SwitchToTab(state.tabs[index].id));

                                        // Force UI update to make active tab display correctly on desktop
                                        SchedulerBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              // This triggers a rebuild that ensures tab state is correctly reflected
                                            });
                                          }
                                        });
                                      }
                                    },
                                    // Add tab close callback
                                    onTabClose: (index) {
                                      if (index < state.tabs.length) {
                                        context.read<TabManagerBloc>().add(
                                            CloseTab(state.tabs[index].id));
                                      }
                                    },
                                    // Keep the add tab button functionality
                                    onAddTabPressed: _handleAddNewTab,
                                    tabs: [
                                      // Generate modern-style tabs
                                      ...state.tabs.map((tab) {
                                        return Tab(
                                          height: 38,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  tab.isPinned
                                                      ? EvaIcons.pin
                                                      : tab.icon ??
                                                          EvaIcons
                                                              .folderOutline,
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
                                  EvaIcons.moreVertical,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.8)
                                      : theme.colorScheme.primary,
                                  size: 22,
                                ),
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: isDarkMode
                                      ? Colors.white.withOpacity(0.03)
                                      : theme.colorScheme.primary
                                          .withOpacity(0.05),
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
                          onPressed: _handleAddNewTab,
                          tooltip: context.tr.newFolder,
                          elevation: 2,
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            EvaIcons.plus,
                            size: 24,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Phương thức mới để xây dựng nội dung dựa trên loại thiết bị
  Widget _buildContent(
      BuildContext context, TabManagerState state, bool isTablet) {
    // Giao diện cho tablet sử dụng UI hiện tại
    if (isTablet) {
      if (state.tabs.isEmpty) {
        return _buildEmptyTabsView(context);
      }
      return _buildTabContent(state);
    }
    // Giao diện cho mobile luôn sử dụng kiểu Chrome, ngay cả khi không có tab
    else {
      return MobileTabView(
        onAddNewTab: _handleAddNewTab,
      );
    }
  }

  Widget _buildEmptyTabsView(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode
              ? theme.colorScheme.surface.withOpacity(0.4)
              : theme.colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              EvaIcons.folderOutline,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
            const SizedBox(height: 24),
            Text(
              'No tabs open',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Open a new tab to start browsing your files',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(EvaIcons.plus, size: 18),
              label: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  context.tr.newFolder,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleAddNewTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(TabManagerState state) {
    final activeTab = state.activeTab;
    if (activeTab == null) return Container();

    // Check if this is a system path (starting with #)
    if (activeTab.path.startsWith('#')) {
      // Use the SystemScreenRouter to route to the appropriate system screen
      final systemScreen = SystemScreenRouter.routeSystemPath(
          context, activeTab.path, activeTab.id);

      // If we have a system screen, return it
      if (systemScreen != null) {
        return systemScreen;
      }
    }

    // Default to normal folder list for regular file paths
    return TabbedFolderListScreen(
      key: ValueKey(activeTab.id),
      path: activeTab.path,
      tabId: activeTab.id,
    );
  }

  Future<void> _handleAddNewTab() async {
    try {
      debugPrint("Attempting to add new tab...");
      // Nếu là Windows, tạo tab với path rỗng để hiển thị drive picker trong view
      if (Platform.isWindows) {
        debugPrint("Adding Drives tab for Windows");
        context.read<TabManagerBloc>().add(AddTab(path: '', name: 'Drives'));
        return;
      }

      // Xử lý cho các hệ điều hành khác
      try {
        debugPrint("Getting documents directory...");
        final directory = await getApplicationDocumentsDirectory();
        debugPrint("Got directory: ${directory.path}");

        if (mounted) {
          debugPrint("Adding tab with Documents path");
          final bloc = context.read<TabManagerBloc>();
          bloc.add(AddTab(path: directory.path, name: 'Documents'));

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                debugPrint("Tab added successfully");
              });
            }
          });
        } else {
          debugPrint("Context is not mounted");
        }
      } catch (e) {
        debugPrint("Error accessing directory: $e");

        // Fallback - try to use current directory
        if (mounted) {
          final fallbackPath = Directory.current.path;
          debugPrint("Using fallback path: $fallbackPath");
          context
              .read<TabManagerBloc>()
              .add(AddTab(path: fallbackPath, name: 'Home'));
        }
      }
    } catch (e) {
      debugPrint("Critical error in _handleAddNewTab: $e");
      // Last resort - try to display something
      if (mounted) {
        try {
          context.read<TabManagerBloc>().add(AddTab(path: '', name: 'Browse'));
        } catch (e) {
          debugPrint("Failed to create fallback tab: $e");
        }
      }
    }
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
                        EvaIcons.close,
                        size: 20,
                        color: textColor?.withOpacity(0.7),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
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
                icon: EvaIcons.plusCircleOutline,
                text: 'New tab',
                onTap: () {
                  Navigator.of(context).pop();
                  _handleAddNewTab();
                },
              ),
              _buildOptionItem(
                context,
                icon: EvaIcons.close,
                text: 'Close current tab',
                onTap: () {
                  Navigator.of(context).pop();
                  _handleCloseCurrentTab();
                },
              ),
              _buildOptionItem(
                context,
                icon: EvaIcons.settings2Outline,
                text: 'Settings',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.colorScheme.primary.withOpacity(0.05),
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
}
