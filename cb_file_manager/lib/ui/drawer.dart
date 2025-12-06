import 'dart:ui'; // Import for ImageFilter
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart' as remix;
import './utils/route.dart';
import './tab_manager/core/tab_main_screen.dart';
import 'package:cb_file_manager/ui/screens/settings/settings_screen.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';
import 'package:cb_file_manager/config/translation_helper.dart';

// Imported components
import 'package:cb_file_manager/ui/widgets/drawer/drawer_header_widget.dart';
import 'package:cb_file_manager/ui/widgets/drawer/drawer_navigation_item.dart';
import 'package:cb_file_manager/ui/widgets/drawer/storage_section_widget.dart';
import 'package:cb_file_manager/ui/widgets/drawer/cubit/drawer_cubit.dart';

class CBDrawer extends StatelessWidget {
  final BuildContext parentContext;
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const CBDrawer(
    this.parentContext, {
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DrawerCubit()..loadStorageLocations(),
      child: _CBDrawerContent(
        parentContext: parentContext,
        isPinned: isPinned,
        onPinStateChanged: onPinStateChanged,
      ),
    );
  }
}

class _CBDrawerContent extends StatelessWidget {
  final BuildContext parentContext;
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const _CBDrawerContent({
    Key? key,
    required this.parentContext,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Drawer(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: Stack(
          children: [
            // BackdropFilter for blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // Original drawer content
            Column(
              children: [
                // Modern drawer header
                DrawerHeaderWidget(
                  isPinned: isPinned,
                  onPinStateChanged: onPinStateChanged,
                ),

                // Scrollable menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    children: [
                      // Main navigation items
                      DrawerNavigationItem(
                        icon: remix.Remix.home_3_line,
                        title: context.tr.home,
                        onTap: () => _navigateTo(context, '#home', 'Home'),
                      ),

                      const SizedBox(height: 8),

                      // Storage section with expansion
                      StorageSectionWidget(
                        onNavigate: (path, name) => _navigateTo(context, path, name, isStorage: true),
                        onTrashTap: () => _navigateTo(context, '#trash', 'Trash'),
                      ),

                      const SizedBox(height: 8),

                      // Tags section
                      DrawerNavigationItem(
                        icon: remix.Remix.price_tag_3_line,
                        title: context.tr.tags,
                        onTap: () => _navigateTo(context, '#tags', 'Tags'),
                      ),

                      DrawerNavigationItem(
                        icon: remix.Remix.wifi_line,
                        title: context.tr.networksMenu,
                        onTap: () => _navigateTo(context, '#network', context.tr.networkTab),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerTheme.color,
                        ),
                      ),

                      // Settings and info section
                      DrawerNavigationItem(
                        icon: remix.Remix.settings_3_line,
                        title: context.tr.settings,
                        onTap: () {
                          if (!isPinned) RouteUtils.safePopDialog(context);
                          _showSettingsDialog(parentContext);
                        },
                      ),

                      DrawerNavigationItem(
                        icon: remix.Remix.information_line,
                        title: context.tr.about,
                        onTap: () {
                          if (!isPinned) RouteUtils.safePopDialog(context);
                          _showAboutDialog(parentContext);
                        },
                      ),
                    ],
                  ),
                ),

                // Footer with app info
                _buildDrawerFooter(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String path, String name, {bool isStorage = false}) {
    if (!isPinned) {
      RouteUtils.safePopDialog(context);
    }

    if (isStorage) {
      _openInCurrentTab(context, path, name);
    } else {
      final tabBloc = BlocProvider.of<TabManagerBloc>(context);
      
      // Check if tab exists for special paths
      if (path.startsWith('#')) {
        final existingTab = tabBloc.state.tabs.firstWhere(
          (tab) => tab.path == path,
          orElse: () => TabData(id: '', name: '', path: ''),
        );

        if (existingTab.id.isNotEmpty) {
          tabBloc.add(SwitchToTab(existingTab.id));
          return;
        }
      }

      // If home, update current tab or create new
      if (path == '#home') {
        final activeTab = tabBloc.state.activeTab;
        if (activeTab != null) {
          tabBloc.add(UpdateTabPath(activeTab.id, '#home'));
          tabBloc.add(UpdateTabName(activeTab.id, 'Home'));
        } else {
          tabBloc.add(AddTab(path: '#home', name: 'Home', switchToTab: true));
        }
        return;
      }

      // Create new tab for others
      tabBloc.add(AddTab(path: path, name: name, switchToTab: true));
    }
  }

  void _openInCurrentTab(BuildContext context, String path, String name) {
    TabManagerBloc? tabBloc;
    try {
      tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
    } catch (e) {
      tabBloc = null;
    }

    if (tabBloc != null) {
      final activeTab = tabBloc.state.activeTab;
      if (activeTab != null) {
        tabBloc.add(UpdateTabPath(activeTab.id, path));
        tabBloc.add(UpdateTabName(activeTab.id, name));
      } else {
        tabBloc.add(AddTab(path: path, name: name));
      }
    } else {
      // Fallback navigation
      final currentContext = context;
      Navigator.of(context)
          .pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TabMainScreen()),
              (route) => false)
          .then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          // Note: context might be invalid here, but TabMainScreen.openPath handles it?
          // Actually we should use navigator key or similar if possible, but this is legacy logic
          // Keeping it simple for now
        });
      });
    }
  }

  Widget _buildDrawerFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          Text(
            '© CoolBird',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.appTitle),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A powerful file manager with tagging capabilities.'),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed by CoolBird - ngtanhung41@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: Text(context.tr.close),
          ),
        ],
      ),
    );
  }
}
