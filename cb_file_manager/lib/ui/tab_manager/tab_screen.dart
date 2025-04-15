import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard shortcuts
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'tab_manager.dart';
import 'tab_data.dart';
import '../drawer.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'tabbed_folder_list_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'package:flutter/gestures.dart'; // Import for mouse scrolling
import 'scrollable_tab_bar.dart'; // Import our custom ScrollableTabBar

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

class _TabScreenState extends State<TabScreen> with TickerProviderStateMixin {
  bool _initialTabAdded = false;

  // Drawer state variables
  bool _isDrawerPinned = false;
  bool _isDrawerVisible = true;

  // Key for the scaffold to control drawer programmatically
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controller cho TabBar tích hợp
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize với 0 tab vì chúng ta sẽ tạo tab động
    _tabController = TabController(length: 0, vsync: this);

    // Add a default tab when the screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDefaultTab();
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
      final UserPreferences prefs = UserPreferences();
      await prefs.init();

      setState(() {
        _isDrawerPinned = prefs.getDrawerPinned();
        _isDrawerVisible = prefs.getDrawerVisible();
      });
    } catch (e) {
      print('Error loading drawer preferences: $e');
    }
  }

  // Save drawer pinned state
  Future<void> _saveDrawerPinned(bool isPinned) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setDrawerPinned(isPinned);
    } catch (e) {
      print('Error saving drawer pinned state: $e');
    }
  }

  // Save drawer visibility
  Future<void> _saveDrawerVisible(bool isVisible) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setDrawerVisible(isVisible);
    } catch (e) {
      print('Error saving drawer visibility: $e');
    }
  }

  // Toggle drawer pin state
  void _toggleDrawerPin() {
    setState(() {
      _isDrawerPinned = !_isDrawerPinned;
    });
    _saveDrawerPinned(_isDrawerPinned);
  }

  // Toggle drawer visibility
  void _toggleDrawerVisibility() {
    setState(() {
      _isDrawerVisible = !_isDrawerVisible;
    });
    _saveDrawerVisible(_isDrawerVisible);
  }

  Future<void> _openDefaultTab() async {
    if (_initialTabAdded) return;

    try {
      // Get default directory (documents folder)
      final directory = await getApplicationDocumentsDirectory();

      // Add a new tab with this directory
      if (mounted) {
        context
            .read<TabManagerBloc>()
            .add(AddTab(path: directory.path, name: 'Documents'));
        _initialTabAdded = true;
      }
    } catch (e) {
      // Show error if directory can't be accessed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing directory: $e')));
      }
    }
  }

  // Method to close the current active tab
  void _handleCloseCurrentTab() {
    final state = context.read<TabManagerBloc>().state;
    final activeTab = state.activeTab;
    if (activeTab != null) {
      context.read<TabManagerBloc>().add(CloseTab(activeTab.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabManagerBloc, TabManagerState>(
      builder: (context, state) {
        // Cập nhật tab controller khi có sự thay đổi
        if (_tabController.length != state.tabs.length + 1) {
          // +1 to account for the "+" tab
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTabController(state.tabs.length);
          });
        }

        // Đồng bộ các tab đang hoạt động
        if (state.activeTabId != null && _tabController.length > 0) {
          final activeIndex =
              state.tabs.indexWhere((tab) => tab.id == state.activeTabId);
          if (activeIndex >= 0 &&
              activeIndex <
                  state.tabs
                      .length && // Compare with state.tabs.length, not _tabController.length
              _tabController.index != activeIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tabController.animateTo(activeIndex);
            });
          }
        }

        // Define keyboard shortcuts and actions
        final Map<ShortcutActivator, Intent> shortcuts = {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT):
              const CreateNewTabIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
              const CloseTabIntent(),
        };

        final Map<Type, Action<Intent>> actions = {
          CreateNewTabIntent: CallbackAction<CreateNewTabIntent>(
            onInvoke: (CreateNewTabIntent intent) => _handleAddNewTab(),
          ),
          CloseTabIntent: CallbackAction<CloseTabIntent>(
            onInvoke: (CloseTabIntent intent) => _handleCloseCurrentTab(),
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
                  appBar: AppBar(
                    // Move TabBar to the title area instead of using bottom
                    title: state.tabs.isEmpty
                        ? const Text('File Manager')
                        : ScrollConfiguration(
                            // Apply custom scroll behavior that supports mouse wheel scrolling
                            behavior: TabBarMouseScrollBehavior(),
                            child: ScrollableTabBar(
                              controller: _tabController,
                              onTap: (index) {
                                // If the last tab (+ button) is clicked, create a new tab
                                if (index == state.tabs.length) {
                                  _handleAddNewTab();
                                } else if (index < state.tabs.length) {
                                  // Otherwise, switch to the selected tab
                                  context
                                      .read<TabManagerBloc>()
                                      .add(SwitchToTab(state.tabs[index].id));
                                }
                              },
                              tabs: [
                                // Regular tabs
                                ...state.tabs.map((tab) {
                                  return Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          tab.isPinned
                                              ? Icons.push_pin
                                              : tab.icon,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(tab.name),
                                        const SizedBox(width: 6),
                                        // Replace simple InkWell with a more touch-friendly close button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () {
                                              // Stop event propagation
                                              context
                                                  .read<TabManagerBloc>()
                                                  .add(CloseTab(tab.id));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(Icons.close,
                                                  size: 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Add "+" tab at the end
                                Tab(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: const Tooltip(
                                      message: 'Add new tab',
                                      child: Icon(Icons.add, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    actions: [
                      // Drawer control actions
                      IconButton(
                        icon: Icon(_isDrawerVisible
                            ? (_isDrawerPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined)
                            : Icons.menu),
                        tooltip: _isDrawerVisible
                            ? (_isDrawerPinned ? 'Unpin menu' : 'Pin menu')
                            : 'Show menu',
                        onPressed: () {
                          if (_isDrawerVisible) {
                            _toggleDrawerPin();
                          } else {
                            _toggleDrawerVisibility();
                          }
                        },
                      ),
                      if (_isDrawerVisible && !_isDrawerPinned)
                        IconButton(
                          icon: const Icon(Icons.visibility_off),
                          tooltip: 'Hide menu',
                          onPressed: _toggleDrawerVisibility,
                        ),
                      // Tab management actions
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _showTabOptions(context),
                      ),
                    ],
                  ),
                  drawer: _isDrawerVisible && !_isDrawerPinned
                      ? CBDrawer(context)
                      : null,
                  body: Row(
                    children: [
                      // Pinned drawer (if enabled)
                      if (_isDrawerVisible && _isDrawerPinned)
                        SizedBox(
                          width: 280,
                          child: CBDrawer(context),
                        ),
                      // Main content area
                      Expanded(
                        child: state.tabs.isEmpty
                            ? _buildEmptyTabsView(context)
                            : _buildTabContent(state),
                      ),
                    ],
                  ),
                  floatingActionButton: state.tabs.isEmpty
                      ? FloatingActionButton(
                          onPressed: _handleAddNewTab,
                          child: const Icon(Icons.add),
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

  Widget _buildEmptyTabsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.tab_unselected,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tabs open',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a new tab to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Tab'),
            onPressed: _handleAddNewTab,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(TabManagerState state) {
    final activeTab = state.activeTab;
    if (activeTab == null) return Container();

    return TabbedFolderListScreen(
      key: ValueKey(activeTab.id),
      path: activeTab.path,
      tabId: activeTab.id,
    );
  }

  Future<void> _handleAddNewTab() async {
    // Nếu là Windows, tạo tab với path rỗng để hiển thị drive picker trong view
    if (Platform.isWindows) {
      context.read<TabManagerBloc>().add(AddTab(path: '', name: 'Drives'));
      return;
    }
    // Xử lý cho các hệ điều hành khác
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (mounted) {
        context
            .read<TabManagerBloc>()
            .add(AddTab(path: directory.path, name: 'Documents'));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _initialTabAdded = true;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing directory: $e')));
      }
    }
  }

  void _showTabOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tab Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Tab'),
              onTap: () {
                Navigator.pop(context);
                _handleAddNewTab();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Current Tab'),
              onTap: () {
                Navigator.pop(context);
                // Get the current tab and refresh its content
                final state = context.read<TabManagerBloc>().state;
                final activeTab = state.activeTab;
                if (activeTab != null) {
                  // This will trigger a rebuild of the active tab
                  context
                      .read<TabManagerBloc>()
                      .add(UpdateTabPath(activeTab.id, activeTab.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ).then((_) {
                  // Force rebuild when returning from settings to apply theme changes
                  if (mounted) setState(() {});
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close All Tabs'),
              onTap: () {
                Navigator.pop(context);
                // Get all tabs and close them one by one
                final tabBloc = context.read<TabManagerBloc>();
                final tabs = List<TabData>.from(tabBloc.state.tabs);
                for (var tab in tabs) {
                  tabBloc.add(CloseTab(tab.id));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
