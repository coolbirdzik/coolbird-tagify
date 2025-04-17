import 'dart:io';
import 'package:flutter/material.dart';
import './main_ui.dart';
import './utils/route.dart';
import './home.dart';
import './tab_manager/tab_main_screen.dart';
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_screen.dart';
import 'package:cb_file_manager/ui/screens/settings/settings_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart'; // Add import for DirectoryProperties extension
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart'; // Add UserPreferences import
import 'package:cb_file_manager/config/app_theme.dart'; // Import theme configuration

class CBDrawer extends StatefulWidget {
  final BuildContext parentContext;
  // Add parameters for pinned state
  final bool isPinned;
  final Function(bool) onPinStateChanged;
  final Function() onHideMenu;

  const CBDrawer(
    this.parentContext, {
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
    required this.onHideMenu,
  }) : super(key: key);

  @override
  State<CBDrawer> createState() => _CBDrawerState();
}

class _CBDrawerState extends State<CBDrawer> {
  bool _isStorageExpanded = false;
  List<Directory> _drives = [];
  bool _isLoadingDrives = false;

  @override
  void initState() {
    super.initState();
    // Load drives when initialized
    if (Platform.isWindows) {
      _loadDrives();
    }
  }

  Future<void> _loadDrives() async {
    setState(() {
      _isLoadingDrives = true;
    });

    try {
      final drives = await getAllWindowsDrives();
      setState(() {
        _drives = drives;
        _isLoadingDrives = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDrives = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Error loading drives: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Custom drawer header with pin button
          SizedBox(
            height: 120,
            child: DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue, // Using color from global AppTheme
              ),
              child: Row(
                children: [
                  // Add logo image
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 40,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'CoolBird File Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // Pin button in drawer
                  IconButton(
                    icon: Icon(
                      widget.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: Colors.white,
                    ),
                    tooltip: widget.isPinned ? 'Unpin menu' : 'Pin menu',
                    onPressed: () {
                      widget.onPinStateChanged(!widget.isPinned);
                    },
                  ),
                  // Hide menu button (only shown when not pinned)
                  if (!widget.isPinned)
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_off,
                        color: Colors.white,
                      ),
                      tooltip: 'Hide menu',
                      onPressed: widget.onHideMenu,
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Homepage'),
            onTap: () {
              Navigator.pop(context);
              RouteUtils.toNewScreen(context, const TabMainScreen());
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Local'),
            initiallyExpanded: _isStorageExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _isStorageExpanded = isExpanded;
              });
            },
            children: <Widget>[
              if (Platform.isWindows) ..._buildWindowsDrivesList(),
              if (!Platform.isWindows || _drives.isEmpty)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 30),
                  leading: const Icon(Icons.folder),
                  title: const Text('Documents'),
                  onTap: () async {
                    final directory = await getApplicationDocumentsDirectory();
                    Navigator.pop(context);
                    _showOpenOptions(context, directory.path, 'Documents');
                  },
                ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 30),
                leading: const Icon(Icons.label),
                title: const Text('Tags'),
                onTap: () async {
                  Navigator.pop(context);
                  // Get documents directory as starting directory
                  final directory = await getApplicationDocumentsDirectory();
                  // Navigate to the Tag Management screen
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TagManagementScreen(
                          startingDirectory: directory.path,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.network_wifi),
            title: const Text('Networks'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Network functionality coming soon'),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWindowsDrivesList() {
    if (_isLoadingDrives) {
      return [
        const ListTile(
          contentPadding: EdgeInsets.only(left: 30),
          title: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      ];
    }

    if (_drives.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No drives found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrives,
          ),
        )
      ];
    }

    return _drives.map((drive) {
      // Get drive letter for display
      String driveLetter = drive.path.split(r'\')[0];
      String driveLabel = '$driveLetter (${_getDriveTypeIcon(drive)})';

      // Check if the drive requires admin privileges
      bool requiresAdmin = drive.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: requiresAdmin
            ? const Icon(Icons.admin_panel_settings, color: Colors.orange)
            : const Icon(Icons.drive_folder_upload),
        title: Text(driveLabel),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, drive);
          } else {
            // Regular drive access
            Navigator.pop(context);
            _openInCurrentTab(drive.path, driveLabel);
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
      Navigator.of(context)
          .pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TabMainScreen()),
              (route) => false)
          .then((_) {
        // Thêm độ trễ nhỏ để đảm bảo TabManagerBloc được khởi tạo đúng cách
        Future.delayed(Duration(milliseconds: 100), () {
          TabMainScreen.openPath(context, path);
        });
      });
    }
  }

  void _showOpenOptions(BuildContext context, String path, String name) {
    // Trực tiếp cập nhật tab hiện tại với đường dẫn mới thay vì hiển thị dialog
    _openInCurrentTab(path, name);
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
              _openInCurrentTab(drive.path, drive.path.split(r'\')[0]);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showTagMigrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrate Tags'),
        content: const Text(
          'This will migrate all your existing tags from individual directories to the new global tag system. '
          'This allows your tags to be accessible from anywhere in the app.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Show progress dialog
              _showProgressDialog(context);

              try {
                // Get the root storage path
                final directory = await getExternalStorageDirectory() ??
                    await getApplicationDocumentsDirectory();

                // Start migration process
                final migratedCount =
                    await TagManager.migrateToGlobalTags(directory.path);

                // Hide progress dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show result dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Migration Complete'),
                      content: Text(
                          'Successfully migrated $migratedCount tagged files to the global tag system.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                // Hide progress dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show error dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Migration Error'),
                      content: Text('An error occurred during migration: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Migrating Tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while your tags are being migrated...'),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CoolBird File Manager'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A powerful file manager with tagging capabilities.'),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed by CoolBird Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A simplified app drawer for the main UI
class AppDrawer extends StatefulWidget {
  // Add parameters for pinned state like in CBDrawer
  final bool isPinned;
  final Function(bool) onPinStateChanged;
  final Function() onHideMenu;

  const AppDrawer({
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
    required this.onHideMenu,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isStorageExpanded = false;
  List<Directory> _drives = [];
  bool _isLoadingDrives = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadDrives();
    }
  }

  Future<void> _loadDrives() async {
    setState(() {
      _isLoadingDrives = true;
    });

    try {
      final drives = await getAllWindowsDrives();
      setState(() {
        _drives = drives;
        _isLoadingDrives = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDrives = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading drives: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue, // Using color from global AppTheme
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Add logo image
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 40,
                        width: 40,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'CoolBird File Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    // Pin button in drawer
                    IconButton(
                      icon: Icon(
                        widget.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: Colors.white,
                      ),
                      tooltip: widget.isPinned ? 'Unpin menu' : 'Pin menu',
                      onPressed: () {
                        widget.onPinStateChanged(!widget.isPinned);
                      },
                    ),
                    // Hide menu button (only shown when not pinned)
                    if (!widget.isPinned)
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_off,
                          color: Colors.white,
                        ),
                        tooltip: 'Hide menu',
                        onPressed: widget.onHideMenu,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'File management made easy',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          // Storage section
          ExpansionTile(
            leading: const Icon(Icons.storage),
            title: const Text('Local Storage'),
            initiallyExpanded: _isStorageExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _isStorageExpanded = isExpanded;
              });
            },
            children: [
              if (Platform.isWindows) ..._buildWindowsDrivesList(),
              if (!Platform.isWindows)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 30),
                  leading: const Icon(Icons.folder),
                  title: const Text('Documents'),
                  onTap: () async {
                    Navigator.pop(context);
                    final directory = await getApplicationDocumentsDirectory();
                    _showOpenOptions(context, directory.path, 'Documents');
                  },
                ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.label),
            title: const Text('Tags'),
            onTap: () async {
              Navigator.pop(context);
              try {
                // Get documents directory as starting directory
                final directory = await getApplicationDocumentsDirectory();
                // Navigate to the Tag Management screen
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TagManagementScreen(
                        startingDirectory: directory.path,
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error opening tag manager: $e'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWindowsDrivesList() {
    if (_isLoadingDrives) {
      return [
        const ListTile(
          contentPadding: EdgeInsets.only(left: 30),
          title: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      ];
    }

    if (_drives.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No drives found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrives,
          ),
        )
      ];
    }

    return _drives.map((drive) {
      // Get drive letter for display
      String driveLetter = drive.path.split(r'\')[0];
      String driveLabel = '$driveLetter (${_getDriveTypeIcon(drive)})';

      // Check if the drive requires admin privileges
      bool requiresAdmin = drive.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: requiresAdmin
            ? const Icon(Icons.admin_panel_settings, color: Colors.orange)
            : const Icon(Icons.drive_folder_upload),
        title: Text(driveLabel),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, drive);
          } else {
            // Regular drive access
            Navigator.pop(context);
            _openInCurrentTab(drive.path, driveLabel);
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
      Navigator.of(context)
          .pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TabMainScreen()),
              (route) => false)
          .then((_) {
        // Thêm độ trễ nhỏ để đảm bảo TabManagerBloc được khởi tạo đúng cách
        Future.delayed(Duration(milliseconds: 100), () {
          TabMainScreen.openPath(context, path);
        });
      });
    }
  }

  void _showOpenOptions(BuildContext context, String path, String name) {
    // Trực tiếp cập nhật tab hiện tại với đường dẫn mới thay vì hiển thị dialog
    _openInCurrentTab(path, name);
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
              _openInCurrentTab(drive.path, drive.path.split(r'\')[0]);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CoolBird File Manager'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A powerful file manager with tagging capabilities.'),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Developed by CoolBird Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
