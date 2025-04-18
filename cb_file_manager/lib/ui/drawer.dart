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
      setState(() {
        _storageLocations = locations;
        _isLoadingStorages = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStorages = false;
      });
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
                  Expanded(
                    child: Text(
                      context.tr.appTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // Pin button in drawer (hidden on small screens)
                  if (!isSmallScreen)
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
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(context.tr.home),
            onTap: () {
              Navigator.pop(context);
              RouteUtils.toNewScreen(context, const TabMainScreen());
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Storage'),
            initiallyExpanded: _isStorageExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _isStorageExpanded = isExpanded;
              });
            },
            children: <Widget>[
              ..._buildStorageLocationsList(),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 30),
                leading: const Icon(Icons.label),
                title: Text(context.tr.tags),
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
            title: Text(context.tr.settings),
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

  List<Widget> _buildStorageLocationsList() {
    if (_isLoadingStorages) {
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

    if (_storageLocations.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No storage locations found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageLocations,
          ),
        )
      ];
    }

    return _storageLocations.map((storage) {
      String displayName = _getStorageDisplayName(storage);
      IconData icon = _getStorageIcon(storage);
      bool requiresAdmin = storage.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: Icon(icon, color: requiresAdmin ? Colors.orange : null),
        title: Text(displayName),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, storage);
          } else {
            // Regular drive access
            Navigator.pop(context);
            _openInCurrentTab(storage.path, displayName);
          }
        },
      );
    }).toList();
  }

  List<Widget> _buildWindowsDrivesList() {
    if (_isLoadingStorages) {
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

    if (_storageLocations.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No storage locations found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageLocations,
          ),
        )
      ];
    }

    return _storageLocations.map((storage) {
      String displayName = _getStorageDisplayName(storage);
      IconData icon = _getStorageIcon(storage);
      bool requiresAdmin = storage.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: Icon(icon, color: requiresAdmin ? Colors.orange : null),
        title: Text(displayName),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, storage);
          } else {
            // Regular drive access
            Navigator.pop(context);
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

        print("Drawer: Navigating to path: $path");
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
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
              _openInCurrentTab(drive.path, drive.path.split(r'\')[0]);
            },
            child: Text(context.tr.ok),
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
        title: Text(context.tr.appTitle),
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

    if (path == '/storage/emulated/0' || path == '/sdcard') {
      return 'Internal Storage';
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      // Extract the SD card name from path like /storage/XXXX-XXXX
      String sdName = path.substring('/storage/'.length);
      return 'SD Card ($sdName)';
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
        return Icons.computer;
      }
      return Icons.drive_folder_upload;
    }

    // Android/Linux paths
    if (path == '/') {
      return Icons.admin_panel_settings;
    }

    if (path == '/storage/emulated/0' || path == '/sdcard') {
      return Icons.phone_android;
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      return Icons.sd_card;
    }

    if (path == '/storage') {
      return Icons.storage;
    }

    if (path == '/system') {
      return Icons.system_security_update;
    }

    if (path == '/data') {
      return Icons.data_usage;
    }

    if (path.startsWith('/mnt/')) {
      return Icons.folder_special;
    }

    // Default icon
    return Icons.folder;
  }
}

/// A simplified app drawer for the main UI
class AppDrawer extends StatefulWidget {
  // Add parameters for pinned state like in CBDrawer
  final bool isPinned;
  final Function(bool) onPinStateChanged;

  const AppDrawer({
    Key? key,
    required this.isPinned,
    required this.onPinStateChanged,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
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
      setState(() {
        _storageLocations = locations;
        _isLoadingStorages = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStorages = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                    Expanded(
                      child: Text(
                        context.tr.appTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    // Pin button in drawer (hidden on small screens)
                    if (!isSmallScreen)
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
            title: Text(context.tr.home),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          // Storage section
          ExpansionTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            initiallyExpanded: _isStorageExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() {
                _isStorageExpanded = isExpanded;
              });
            },
            children: _buildStorageLocationsList(),
          ),
          ListTile(
            leading: const Icon(Icons.label),
            title: Text(context.tr.tags),
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
            title: Text(context.tr.settings),
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

  List<Widget> _buildStorageLocationsList() {
    if (_isLoadingStorages) {
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

    if (_storageLocations.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No storage locations found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageLocations,
          ),
        )
      ];
    }

    return _storageLocations.map((storage) {
      String displayName = _getStorageDisplayName(storage);
      IconData icon = _getStorageIcon(storage);
      bool requiresAdmin = storage.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: Icon(icon, color: requiresAdmin ? Colors.orange : null),
        title: Text(displayName),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, storage);
          } else {
            // Regular drive access
            Navigator.pop(context);
            _openInCurrentTab(storage.path, displayName);
          }
        },
      );
    }).toList();
  }

  List<Widget> _buildWindowsDrivesList() {
    if (_isLoadingStorages) {
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

    if (_storageLocations.isEmpty) {
      return [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 30),
          title: const Text('No storage locations found'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageLocations,
          ),
        )
      ];
    }

    return _storageLocations.map((storage) {
      String displayName = _getStorageDisplayName(storage);
      IconData icon = _getStorageIcon(storage);
      bool requiresAdmin = storage.requiresAdmin;

      return ListTile(
        contentPadding: const EdgeInsets.only(left: 30),
        leading: Icon(icon, color: requiresAdmin ? Colors.orange : null),
        title: Text(displayName),
        subtitle: requiresAdmin
            ? const Text('Requires administrator privileges',
                style: TextStyle(fontSize: 12, color: Colors.orange))
            : null,
        onTap: () {
          if (requiresAdmin) {
            // Show warning dialog for protected drives
            _showAdminAccessDialog(context, storage);
          } else {
            // Regular drive access
            Navigator.pop(context);
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

        print("Drawer: Navigating to path: $path");
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
            child: Text(context.tr.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
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
            Text('Developed by CoolBird Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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

    if (path == '/storage/emulated/0' || path == '/sdcard') {
      return 'Internal Storage';
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      // Extract the SD card name from path like /storage/XXXX-XXXX
      String sdName = path.substring('/storage/'.length);
      return 'SD Card ($sdName)';
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
        return Icons.computer;
      }
      return Icons.drive_folder_upload;
    }

    // Android/Linux paths
    if (path == '/') {
      return Icons.admin_panel_settings;
    }

    if (path == '/storage/emulated/0' || path == '/sdcard') {
      return Icons.phone_android;
    }

    if (path.startsWith('/storage/') && path != '/storage') {
      return Icons.sd_card;
    }

    if (path == '/storage') {
      return Icons.storage;
    }

    if (path == '/system') {
      return Icons.system_security_update;
    }

    if (path == '/data') {
      return Icons.data_usage;
    }

    if (path.startsWith('/mnt/')) {
      return Icons.folder_special;
    }

    // Default icon
    return Icons.folder;
  }
}
