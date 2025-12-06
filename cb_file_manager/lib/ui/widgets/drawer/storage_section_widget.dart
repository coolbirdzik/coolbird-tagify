import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/ui/widgets/drawer/cubit/drawer_cubit.dart';
import 'package:cb_file_manager/ui/utils/route.dart';

class StorageSectionWidget extends StatefulWidget {
  final Function(String path, String name) onNavigate;
  final VoidCallback onTrashTap;

  const StorageSectionWidget({
    Key? key,
    required this.onNavigate,
    required this.onTrashTap,
  }) : super(key: key);

  @override
  State<StorageSectionWidget> createState() => _StorageSectionWidgetState();
}

class _StorageSectionWidgetState extends State<StorageSectionWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return BlocBuilder<DrawerCubit, DrawerState>(
      builder: (context, state) {
        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: _isExpanded
                  ? theme.colorScheme.surface.withOpacity(0.7)
                  : Colors.transparent,
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  remix.Remix.hard_drive_2_line,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Storage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                collapsedBackgroundColor: Colors.transparent,
                backgroundColor: theme.colorScheme.surface.withOpacity(0.7),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: _isExpanded,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _isExpanded = isExpanded;
                  });
                },
                children: <Widget>[
                  if (state.isLoading)
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
                  else if (state.storageLocations.isEmpty)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      title: const Text('No storage locations found'),
                      trailing: IconButton(
                        icon: const Icon(remix.Remix.refresh_line),
                        onPressed: () {
                          context.read<DrawerCubit>().loadStorageLocations();
                        },
                      ),
                    )
                  else
                    ...state.storageLocations.map((storage) {
                      return _buildStorageItem(context, storage);
                    }).toList(),
                  
                  // Trash Bin
                  _buildItem(
                    context,
                    icon: remix.Remix.delete_bin_2_line,
                    title: 'Trash Bin',
                    iconColor: Colors.red[400],
                    onTap: widget.onTrashTap,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageItem(BuildContext context, Directory storage) {
    String displayName = _getStorageDisplayName(storage);
    IconData icon = _getStorageIcon(storage);
    bool requiresAdmin = storage.requiresAdmin;

    return _buildItem(
      context,
      icon: icon,
      title: displayName,
      subtitle: requiresAdmin ? 'Requires administrator privileges' : null,
      iconColor: requiresAdmin ? Colors.orange : null,
      onTap: () {
        if (requiresAdmin) {
          _showAdminAccessDialog(context, storage);
        } else {
          widget.onNavigate(storage.path, displayName);
        }
      },
    );
  }

  Widget _buildItem(
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
        style: const TextStyle(
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
              widget.onNavigate(drive.path, drive.path.split(r'\')[0]);
            },
            child: Text(context.tr.ok),
          ),
        ],
      ),
    );
  }

  // Helper methods from original file
  String _getStorageDisplayName(Directory storage) {
    String path = storage.path;
    if (path.length > 1 && path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }

    if (Platform.isWindows && path.contains(':')) {
      String driveLetter = path.split(r'\')[0];
      return '$driveLetter (${_getDriveTypeIcon(storage)})';
    }

    if (path == '/') return 'Root (/)';
    if (path == '/storage/emulated/0') return 'Internal Storage (Primary)';
    if (path == '/sdcard') return 'Internal Storage (sdcard)';
    if (path == '/storage') return 'Storage';

    return path;
  }

  String _getDriveTypeIcon(Directory drive) {
    String path = drive.path;
    if (path.startsWith('C:')) {
      return 'System';
    }
    return 'Drive';
  }

  IconData _getStorageIcon(Directory drive) {
    // Logic to determine icon based on drive type
    // Simplified for now
    if (Platform.isWindows && drive.path.startsWith('C:')) {
      return remix.Remix.computer_line;
    }
    return remix.Remix.hard_drive_2_line;
  }
}
