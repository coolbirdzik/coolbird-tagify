import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import './utils/route.dart';
import './tab_manager/core/tab_main_screen.dart';
import 'package:cb_file_manager/ui/screens/settings/settings_screen.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Imported components
import 'package:cb_file_manager/ui/widgets/drawer/drawer_header_widget.dart';
import 'package:cb_file_manager/ui/widgets/drawer/drawer_navigation_item.dart';
import 'package:cb_file_manager/ui/widgets/drawer/storage_section_widget.dart';
import 'package:cb_file_manager/ui/widgets/drawer/pinned_section_widget.dart';
import 'package:cb_file_manager/ui/widgets/drawer/cubit/drawer_cubit.dart';

class CBDrawer extends StatelessWidget {
  final BuildContext parentContext;
  final String? activeTabId;
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const CBDrawer(
    this.parentContext, {
    Key? key,
    this.activeTabId,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _CBDrawerContent(
      parentContext: parentContext,
      activeTabId: activeTabId,
      isPinned: isPinned,
      onPinStateChanged: onPinStateChanged,
    );
  }
}

class _CBDrawerContent extends StatefulWidget {
  final BuildContext parentContext;
  final String? activeTabId;
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const _CBDrawerContent({
    Key? key,
    required this.parentContext,
    this.activeTabId,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  State<_CBDrawerContent> createState() => _CBDrawerContentState();
}

class _CBDrawerContentState extends State<_CBDrawerContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DrawerCubit>().setActiveTab(widget.activeTabId);
    });
  }

  @override
  void didUpdateWidget(covariant _CBDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTabId != widget.activeTabId) {
      context.read<DrawerCubit>().setActiveTab(widget.activeTabId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Drawer(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerLowest
                    .withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            children: [
              // Modern drawer header
              DrawerHeaderWidget(
                isPinned: widget.isPinned,
                onPinStateChanged: widget.onPinStateChanged,
              ),

              // Scrollable menu items
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  children: [
                    // Main navigation items
                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.house,
                      title: context.tr.home,
                      onTap: () => _navigateTo(context, '#home', 'Home'),
                    ),

                    BlocBuilder<DrawerCubit, DrawerState>(
                      builder: (context, drawerState) {
                        return PinnedSectionWidget(
                          key: ValueKey<String>(
                            'pinned-${drawerState.activeTabId}-${drawerState.isPinnedExpanded}',
                          ),
                          onNavigate: (path, name) => _navigateTo(
                            context,
                            path,
                            name,
                            isStorage: true,
                          ),
                          initialExpanded: drawerState.isPinnedExpanded,
                          onExpansionChanged: (isExpanded) {
                            context
                                .read<DrawerCubit>()
                                .setPinnedExpanded(isExpanded);
                          },
                        );
                      },
                    ),

                    // Storage section with expansion
                    BlocBuilder<DrawerCubit, DrawerState>(
                      builder: (context, drawerState) {
                        return StorageSectionWidget(
                          key: ValueKey<String>(
                            'storage-${drawerState.activeTabId}-${drawerState.isStorageExpanded}',
                          ),
                          onNavigate: (path, name) => _navigateTo(
                            context,
                            path,
                            name,
                            isStorage: true,
                          ),
                          onTrashTap: () =>
                              _navigateTo(context, '#trash', 'Trash'),
                          initialExpanded: drawerState.isStorageExpanded,
                          onExpansionChanged: (isExpanded) {
                            context
                                .read<DrawerCubit>()
                                .setStorageExpanded(isExpanded);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.image,
                      title: context.tr.imageGallery,
                      onTap: () => _navigateTo(
                        context,
                        '#gallery',
                        context.tr.imageGallery,
                      ),
                    ),

                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.videoCamera,
                      title: context.tr.videoGallery,
                      onTap: () => _navigateTo(
                        context,
                        '#video',
                        context.tr.videoGallery,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tags section
                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.tag,
                      title: context.tr.tags,
                      onTap: () => _navigateTo(context, '#tags', 'Tags'),
                    ),

                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.wifiHigh,
                      title: context.tr.networksMenu,
                      onTap: () => _navigateTo(
                          context, '#network', context.tr.networkTab),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45),
                      ),
                    ),

                    // Settings and info section
                    DrawerNavigationItem(
                      icon: PhosphorIconsLight.gear,
                      title: context.tr.settings,
                      onTap: () {
                        if (!widget.isPinned) RouteUtils.safePopDialog(context);
                        _showSettingsDialog(widget.parentContext);
                      },
                    ),
                  ],
                ),
              ),

              // Footer with app info
              _buildDrawerFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String path, String name,
      {bool isStorage = false}) {
    if (!widget.isPinned) {
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
    final navigationPath = _normalizePinnedNavigationPath(path);
    final navigationName = navigationPath == path
        ? name
        : navigationPath.split(Platform.pathSeparator).lastWhere(
              (part) => part.isNotEmpty,
              orElse: () => name,
            );

    TabManagerBloc? tabBloc;
    try {
      tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
    } catch (e) {
      tabBloc = null;
    }

    if (tabBloc != null) {
      final activeTab = tabBloc.state.activeTab;
      if (activeTab != null) {
        tabBloc.add(UpdateTabPath(activeTab.id, navigationPath));
        tabBloc.add(UpdateTabName(activeTab.id, navigationName));
      } else {
        tabBloc.add(AddTab(path: navigationPath, name: navigationName));
      }
    } else {
      // Fallback navigation
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

  String _normalizePinnedNavigationPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return path;

    try {
      final type = FileSystemEntity.typeSync(trimmed, followLinks: false);
      if (type == FileSystemEntityType.file) {
        return File(trimmed).parent.path;
      }
    } catch (_) {}

    return path;
  }

  Widget _buildDrawerFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FutureBuilder<String>(
            future: _getFullVersion(),
            builder: (context, snapshot) {
              final versionText = snapshot.data == null
                  ? 'Version'
                  : 'Version ${snapshot.data}';
              return Text(
                versionText,
                style: TextStyle(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              );
            },
          ),
          Text(
            '© CoolBirdZik',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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

  Future<String> _getFullVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    if (version.isEmpty && build.isEmpty) {
      return '';
    }
    if (build.isEmpty) {
      return version;
    }
    if (version.isEmpty) {
      return build;
    }
    return '$version.$build';
  }
}
