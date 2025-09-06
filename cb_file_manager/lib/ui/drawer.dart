import 'dart:io';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import './utils/route.dart';
import './tab_manager/tab_main_screen.dart';
import 'package:cb_file_manager/ui/screens/settings/settings_screen.dart';
import 'package:cb_file_manager/ui/screens/trash_bin/trash_bin_screen.dart'; // Import TrashBinScreen
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart'; // Add import for DirectoryProperties extension
// Import TrashManager
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_data.dart'; // Import TabData
// Add UserPreferences import
import 'package:cb_file_manager/config/app_theme.dart'; // Import theme configuration
import 'package:cb_file_manager/config/translation_helper.dart'; // Import translation helper

class CBDrawer extends StatefulWidget {
  final BuildContext parentContext;
  // Add parameters for pinned state
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const CBDrawer(
    this.parentContext, {
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  State<CBDrawer> createState() => _CBDrawerState();
}

class _CBDrawerState extends State<CBDrawer> {
  bool _isStorageExpanded = false;
  List<Directory> _storageLocations = [];
  bool _isLoadingStorages = false;

  @override
  void initState() {
    super.initState();
    // Load all storage locations when initialized
    _loadStorageLocations();
  }

  Future<void> _loadStorageLocations() async {
    setState(() {
      _isLoadingStorages = true;
    });

    try {
      final locations = await getAllStorageLocations();
      if (mounted) {
        setState(() {
          _storageLocations = locations;
          _isLoadingStorages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStorages = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Error loading storage locations: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if the screen is small (width < 600)
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final ThemeData theme = Theme.of(context);

    return Drawer(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor
          .withOpacity(0.85), // Make background semi-transparent
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: ClipRRect(
        // Clip the blur effect to the drawer's shape
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
                color: Colors
                    .transparent, // Important: child of BackdropFilter should be transparent
              ),
            ),
            // Original drawer content
            Column(
              children: [
                // Modern drawer header
                _buildDrawerHeader(isSmallScreen, theme),

                // Scrollable menu items
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    children: [
                      // Main navigation items
                      _buildNavigationItem(
                        context,
                        icon: EvaIcons.homeOutline,
                        title: context.tr.home,
                        onTap: () {
                          // Only pop the Navigator when drawer is not pinned
                          if (!widget.isPinned) {
                            RouteUtils.safePopDialog(context);
                          }
                          RouteUtils.safeNavigate(
                              context, const TabMainScreen());
                        },
                      ),

                      const SizedBox(height: 8),

                      // Storage section with expansion
                      _buildExpansionSection(
                        context,
                        icon: EvaIcons.hardDriveOutline,
                        title: 'Storage',
                      ),

                      const SizedBox(height: 8),

                      // Tags section
                      _buildNavigationItem(
                        context,
                        icon: EvaIcons.pricetags,
                        title: context.tr.tags,
                        onTap: () {
                          // Only pop the Navigator when drawer is not pinned
                          if (!widget.isPinned) {
                            RouteUtils.safePopDialog(context);
                          }

                          // Open tag management in a new tab
                          final tabBloc =
                              BlocProvider.of<TabManagerBloc>(context);

                          // Check if a tags tab already exists
                          final existingTab = tabBloc.state.tabs.firstWhere(
                            (tab) => tab.path == '#tags',
                            orElse: () => TabData(id: '', name: '', path: ''),
                          );

                          if (existingTab.id.isNotEmpty) {
                            // If tab exists, switch to it
                            tabBloc.add(SwitchToTab(existingTab.id));
                          } else {
                            // Otherwise, create a new tab
                            tabBloc.add(
                              AddTab(
                                path: '#tags',
                                name: 'Tags',
                                switchToTab: true,
                              ),
                            );
                          }
                        },
                      ),

                      _buildNavigationItem(
                        context,
                        icon: EvaIcons.wifi,
                        title: 'Networks',
                        onTap: () {
                          // Only pop the Navigator when drawer is not pinned
                          if (!widget.isPinned) {
                            RouteUtils.safePopDialog(context);
                          }

                          // Open network browsing in a new tab
                          final tabBloc =
                              BlocProvider.of<TabManagerBloc>(context);

                          // Check if a network tab already exists
                          final existingTab = tabBloc.state.tabs.firstWhere(
                            (tab) => tab.path == '#network',
                            orElse: () => TabData(id: '', name: '', path: ''),
                          );

                          if (existingTab.id.isNotEmpty) {
                            // If tab exists, switch to it
                            tabBloc.add(SwitchToTab(existingTab.id));
                          } else {
                            // Otherwise, create a new tab
                            tabBloc.add(
                              AddTab(
                                path: '#network',
                                name: 'Network',
                                switchToTab: true,
                              ),
                            );
                          }
                        },
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
                      _buildNavigationItem(
                        context,
                        icon: EvaIcons.settings2Outline,
                        title: context.tr.settings,
                        onTap: () {
                          // Only pop the Navigator when drawer is not pinned
                          if (!widget.isPinned) {
                            RouteUtils.safePopDialog(context);
                          }
                          _showSettingsDialog(context);
                        },
                      ),

                      _buildNavigationItem(
                        context,
                        icon: EvaIcons.infoOutline,
                        title: 'About',
                        onTap: () {
                          // Only pop the Navigator when drawer is not pinned
                          if (!widget.isPinned) {
                            RouteUtils.safePopDialog(context);
                          }
                          _showAboutDialog(context);
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

  Widget _buildDrawerHeader(bool isSmallScreen, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.darkBlue,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo with shadow effect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  width: 32,
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    context.tr.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Pin button (hidden on small screens)
              if (!isSmallScreen)
                IconButton(
                  icon: Icon(
                    widget.isPinned ? EvaIcons.pin : EvaIcons.pinOutline,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: widget.isPinned ? 'Unpin menu' : 'Pin menu',
                  onPressed: () {
                    widget.onPinStateChanged(!widget.isPinned);
                  },
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'File Management Made Simple',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildExpansionSection(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final ThemeData theme = Theme.of(context);

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: _isStorageExpanded
              ? theme.colorScheme.surface
                  .withOpacity(0.7) // Make expanded background semi-transparent
              : Colors.transparent,
          child: ExpansionTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(
              icon,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: theme.colorScheme.surface
                .withOpacity(0.7), // Make expanded background semi-transparent
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: _isStorageExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _isStorageExpanded = isExpanded;
              });
            },
            children: <Widget>[
              ..._buildStorageLocationsList(),
              // Add Trash Bin entry
              _buildStorageLocationItem(
                context,
                icon: EvaIcons.trash2Outline,
                title: 'Trash Bin',
                iconColor: Colors.red[400],
                onTap: () async {
                  // Only pop the Navigator when drawer is not pinned
                  if (!widget.isPinned) {
                    RouteUtils.safePopDialog(context);
                  }
                  // Navigate to the Trash Bin screen
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrashBinScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageLocationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: iconColor ?? theme.colorScheme.primary.withOpacity(0.8),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            )
          : null,
      onTap: onTap,
    );
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

  List<Widget> _buildStorageLocationsList() {
    if (_isLoadingStorages) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      ];
    }

    if (_storageLocations.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 56, right: 16),
          title: const Text('No storage locations found'),
          trailing: IconButton(
            icon: const Icon(EvaIcons.refresh),
            onPressed: _loadStorageLocations,
          ),
        )
      ];
    }

    return _storageLocations.map((storage) {
      String displayName = _getStorageDisplayName(storage);
      IconData icon = _getStorageIcon(storage);
      bool requiresAdmin = storage.requiresAdmin;

      return _buildStorageLocationItem(
        context,
        icon: icon,
        title: displayName,
        subtitle: requiresAdmin ? 'Requires administrator privileges' : null,
        iconColor: requiresAdmin ? Colors.orange : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, storage);
          } else {
            // Regular drive access
            // Only pop the Navigator when drawer is not pinned
            if (!widget.isPinned) {
              RouteUtils.safePopDialog(context);
            }
            _openInCurrentTab(storage.path, displayName);
          }
        },
      );
    }).toList();
  }

  void _openInCurrentTab(String path, String name) {
    // Check if we're already in a tab system
    TabManagerBloc? tabBloc;
    try {
      tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
    } catch (e) {
      // BlocProvider.of will throw if the bloc isn't found
      tabBloc = null;
    }

    if (tabBloc != null) {
      // Lấy tab hiện tại và cập nhật đường dẫn
      final activeTab = tabBloc.state.activeTab;
      if (activeTab != null) {
        // Add path to navigation history first
        tabBloc.add(AddToTabHistory(activeTab.id, path));

        // Update the tab path
        tabBloc.add(UpdateTabPath(activeTab.id, path));

        // Cập nhật tên tab để phản ánh thư mục mới
        final tabName = _getNameFromPath(path);
        tabBloc.add(UpdateTabName(activeTab.id, tabName));
      } else {
        // Nếu không có tab nào đang mở, tạo tab mới
        tabBloc.add(AddTab(path: path, name: _getNameFromPath(path)));
      }
    } else {
      // Không trong hệ thống tab, chuyển đến màn hình tab trước
      // Store the context to avoid using widget.context after dispose
      final currentContext = context;
      Navigator.of(context)
          .pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TabMainScreen()),
              (route) => false)
          .then((_) {
        // Thêm độ trễ nhỏ để đảm bảo TabManagerBloc được khởi tạo đúng cách
        Future.delayed(const Duration(milliseconds: 100), () {
          // Check if the widget is still mounted before using the context
          if (mounted) {
            TabMainScreen.openPath(currentContext, path);
          }
        });
      });
    }
  }

  String _getNameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    final lastPart =
        parts.lastWhere((part) => part.isNotEmpty, orElse: () => 'Root');
    return lastPart.isEmpty ? 'Root' : lastPart;
  }

  String _getDriveTypeIcon(Directory drive) {
    String path = drive.path;
    if (path.startsWith('C:')) {
      return 'System';
    }
    return 'Drive';
  }

  void _showSettingsDialog(BuildContext context) {
    // Navigate to the settings screen instead of showing a dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showAdminAccessDialog(BuildContext context, Directory drive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Access Required'),
        content: Text(
          'The drive ${drive.path} requires administrator privileges to access.',
        ),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
              // Only pop the Navigator when drawer is not pinned
              if (!widget.isPinned) {
                RouteUtils.safePopDialog(context);
              }
              _openInCurrentTab(drive.path, drive.path.split(r'\')[0]);
            },
            child: Text(context.tr.ok),
          ),
        ],
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

  // Helper method to get a display name for a storage location
  String _getStorageDisplayName(Directory storage) {
    String path = storage.path;

    // For Windows drives
    if (Platform.isWindows && path.contains(':')) {
      String driveLetter = path.split(r'\')[0];
      return '$driveLetter (${_getDriveTypeIcon(storage)})';
    }

    // For Android/Linux paths
    if (path == '/') {
      return 'Root (/)';
    }

    // Clearly identify the main internal storage
    if (path == '/storage/emulated/0') {
      return 'Internal Storage (Primary)';
    }

    // Provide clarity for the sdcard path, which typically points to internal storage on modern devices
    if (path == '/sdcard') {
      return 'Internal Storage (sdcard)';
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      // For paths like /storage/XXXX-XXXX that are actually external SD cards
      String sdName = path.substring('/storage/'.length);
      if (sdName != 'emulated' && !sdName.startsWith('emulated/')) {
        return 'SD Card ($sdName)';
      }
      // For paths like /storage/emulated/1 or other numbered emulated storage
      else if (sdName.startsWith('emulated/') &&
          !sdName.startsWith('emulated/0')) {
        String emulatedId = sdName.substring('emulated/'.length);
        return 'Secondary Storage ($emulatedId)';
      }
    }

    if (path == '/storage') {
      return 'Storage';
    }

    if (path == '/system') {
      return 'System';
    }

    if (path == '/data') {
      return 'Data';
    }

    if (path.startsWith('/mnt/')) {
      String mntName = path.substring('/mnt/'.length);
      return 'Mount ($mntName)';
    }

    // Default - show the last part of the path
    List<String> parts = path.split(Platform.pathSeparator);
    String lastPart =
        parts.lastWhere((part) => part.isNotEmpty, orElse: () => path);
    return lastPart.isEmpty ? path : lastPart;
  }

  // Helper method to get an appropriate icon for a storage location
  IconData _getStorageIcon(Directory storage) {
    String path = storage.path;

    // Icons for different storage types
    if (Platform.isWindows && path.contains(':')) {
      if (path.startsWith('C:')) {
        return EvaIcons.monitor;
      }
      return EvaIcons.hardDriveOutline;
    }

    // Android/Linux paths
    if (path == '/') {
      return EvaIcons.shieldOutline;
    }

    if (path == '/storage/emulated/0' || path == '/sdcard') {
      return EvaIcons.smartphone;
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      return EvaIcons.saveOutline;
    }

    if (path == '/storage') {
      return EvaIcons.hardDriveOutline;
    }

    if (path == '/system') {
      return EvaIcons.settingsOutline;
    }

    if (path == '/data') {
      return EvaIcons.activity;
    }

    if (path.startsWith('/mnt/')) {
      return EvaIcons.folderAddOutline;
    }

    // Default icon
    return EvaIcons.folderOutline;
  }
}
