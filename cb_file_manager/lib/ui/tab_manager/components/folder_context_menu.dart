// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays a context menu for empty areas in folder view
class FolderContextMenu {
  /// Currently displayed submenu overlay
  static OverlayEntry? _submenuOverlayEntry;

  /// Remove the submenu overlay if it's open
  static void _removeSubMenu() {
    _submenuOverlayEntry?.remove();
    _submenuOverlayEntry = null;
  }

  /// Shows the context menu for the current directory
  static Future<void> show({
    required BuildContext context,
    required Offset globalPosition, // Renamed from position for clarity
    required FolderListBloc folderListBloc,
    required String currentPath,
    required ViewMode currentViewMode,
    required SortOption currentSortOption,
    required Function(ViewMode) onViewModeChanged,
    required VoidCallback onRefresh,
    required Future<void> Function(String) onCreateFolder,
    required Future<void> Function(SortOption)
        onSortOptionSaved, // Keep for future use or remove if not needed by caller
  }) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    await showMenu<String>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String>>[
        _buildSubmenuPopupMenuItem(
          context: context,
          value: 'view',
          title: 'View',
          icon: Icons.visibility_outlined,
          builder: (BuildContext context) {
            return <PopupMenuEntry<ViewMode>>[
              _buildCheckedPopupMenuItem(
                title: 'List View',
                value: ViewMode.list,
                isChecked: currentViewMode == ViewMode.list,
              ),
              _buildCheckedPopupMenuItem(
                title: 'Grid View',
                value: ViewMode.grid,
                isChecked: currentViewMode == ViewMode.grid,
              ),
              _buildCheckedPopupMenuItem(
                title: 'Details View',
                value: ViewMode.details,
                isChecked: currentViewMode == ViewMode.details,
              ),
            ];
          },
          onSelected: (ViewMode viewMode) {
            onViewModeChanged(viewMode);
          },
        ),
        _buildSubmenuPopupMenuItem(
          context: context,
          value: 'sort',
          title: 'Sort by',
          icon: Icons.sort_outlined,
          builder: (BuildContext context) {
            return <PopupMenuEntry<SortOption>>[
              _buildCheckedPopupMenuItem(
                  title: 'Name (A to Z)',
                  value: SortOption.nameAsc,
                  isChecked: currentSortOption == SortOption.nameAsc),
              _buildCheckedPopupMenuItem(
                  title: 'Name (Z to A)',
                  value: SortOption.nameDesc,
                  isChecked: currentSortOption == SortOption.nameDesc),
              _buildCheckedPopupMenuItem(
                  title: 'Date (Newest first)',
                  value: SortOption.dateDesc,
                  isChecked: currentSortOption == SortOption.dateDesc),
              _buildCheckedPopupMenuItem(
                  title: 'Date (Oldest first)',
                  value: SortOption.dateAsc,
                  isChecked: currentSortOption == SortOption.dateAsc),
              _buildCheckedPopupMenuItem(
                  title: 'Size (Largest first)',
                  value: SortOption.sizeDesc,
                  isChecked: currentSortOption == SortOption.sizeDesc),
              _buildCheckedPopupMenuItem(
                  title: 'Size (Smallest first)',
                  value: SortOption.sizeAsc,
                  isChecked: currentSortOption == SortOption.sizeAsc),
              _buildCheckedPopupMenuItem(
                  title: 'Type (A to Z)',
                  value: SortOption.typeAsc,
                  isChecked: currentSortOption == SortOption.typeAsc),
              _buildCheckedPopupMenuItem(
                  title: 'Type (Z to A)',
                  value: SortOption.typeDesc,
                  isChecked: currentSortOption == SortOption.typeDesc),
            ];
          },
          onSelected: (SortOption sortOption) {
            folderListBloc.add(SetSortOption(sortOption));
            onSortOptionSaved(sortOption);
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'refresh',
          child: _buildIconMenuItemContent(
              title: 'Refresh', icon: EvaIcons.refresh),
        ),
        PopupMenuItem<String>(
          value: 'new_folder',
          child: _buildIconMenuItemContent(
              title: 'New Folder', icon: EvaIcons.folderAdd),
        ),
        PopupMenuItem<String>(
          value: 'new_file',
          child: _buildIconMenuItemContent(
              title: 'New File', icon: EvaIcons.fileAdd),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          child: _buildIconMenuItemContent(
              title: 'Paste', icon: Icons.content_paste_outlined),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'properties',
          child: _buildIconMenuItemContent(
              title: 'Properties', icon: Icons.info_outline),
        ),
      ],
    ).then((String? value) async {
      // Ensure any open submenu overlay is removed when the main menu closes
      _removeSubMenu();
      if (value == null) return;

      switch (value) {
        case 'refresh':
          onRefresh();
          break;
        case 'new_folder':
          _showCreateFolderDialog(context, currentPath, onCreateFolder);
          break;
        case 'new_file':
          _showCreateFileDialog(context, currentPath);
          break;
        case 'paste':
          // TODO: Implement paste functionality
          break;
        case 'properties':
          _showFolderProperties(context, currentPath);
          break;
        // 'view' and 'sort' are handled by their onSelected callbacks in _buildSubmenuPopupMenuItem
      }
    });
  }

  // New helper method to encapsulate submenu opening logic
  static void _openActualSubMenu<T>(
    BuildContext anchorContext,
    GlobalKey itemKey,
    List<PopupMenuEntry<T>> Function(BuildContext) builder,
    ValueChanged<T> onSelectedCallback, // Renamed for clarity
    VoidCallback onSubMenuDismissedWithoutSelection, // New callback
  ) {
    // Remove any existing submenu overlay
    _removeSubMenu();
    if (itemKey.currentContext == null) return;
    final overlayState = Overlay.of(anchorContext);
    final RenderBox overlay =
        overlayState.context.findRenderObject() as RenderBox;
    final RenderBox itemRenderBox =
        itemKey.currentContext!.findRenderObject() as RenderBox;
    final Offset itemPosition =
        itemRenderBox.localToGlobal(Offset.zero, ancestor: overlay);

    const double minSubMenuWidth = 180.0;
    final double subMenuWidth =
        math.max(itemRenderBox.size.width, minSubMenuWidth);
    const double menuGap = 2.0;
    const double verticalOffsetCorrection = -8.0;
    double subMenuLeft;
    if (itemPosition.dx + itemRenderBox.size.width + menuGap + subMenuWidth >
        overlay.size.width) {
      subMenuLeft = itemPosition.dx - subMenuWidth - menuGap;
    } else {
      subMenuLeft = itemPosition.dx + itemRenderBox.size.width + menuGap;
    }
    final double subMenuTop =
        math.max(0.0, itemPosition.dy + verticalOffsetCorrection);
    final List<PopupMenuEntry<T>> items = builder(anchorContext);
    final double subMenuHeight =
        itemRenderBox.size.height * items.length * 1.2 + 16.0;

    // Create and insert submenu overlay
    final entry = OverlayEntry(builder: (context) {
      return Positioned(
        left: subMenuLeft,
        top: subMenuTop,
        width: subMenuWidth,
        child: Material(
          elevation: 8.0,
          color: Theme.of(anchorContext).canvasColor,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0))),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: subMenuHeight),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, thickness: 1),
              itemBuilder: (context, index) {
                final entryItem = items[index];
                if (entryItem is PopupMenuDivider) {
                  return Divider(height: entryItem.height, thickness: 1);
                } else if (entryItem is PopupMenuItem<T>) {
                  return InkWell(
                    onTap: () {
                      onSelectedCallback(entryItem.value as T);
                      _removeSubMenu();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: entryItem.child,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });
    _submenuOverlayEntry = entry;
    overlayState.insert(entry);
  }

  // Helper to build a PopupMenuItem that opens a submenu
  static PopupMenuEntry<String> _buildSubmenuPopupMenuItem<T>({
    required BuildContext context,
    required String value,
    required String title,
    required IconData icon,
    required List<PopupMenuEntry<T>> Function(BuildContext) builder,
    required ValueChanged<T> onSelected,
  }) {
    final GlobalKey itemKey = GlobalKey();
    return PopupMenuItem<String>(
      value: value,
      enabled: true,
      child: MouseRegion(
        onEnter: (_) {
          _openActualSubMenu<T>(context, itemKey, builder, onSelected, () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
        },
        child: _buildIconMenuItemContent(
          key: itemKey,
          title: title,
          icon: icon,
          hasTrailingArrow: true,
        ),
      ),
      onTap: () {
        _openActualSubMenu<T>(context, itemKey, builder, onSelected, () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      },
    );
  }

  // Helper for direct action menu items
  static Widget _buildIconMenuItemContent({
    Key? key, // Added key parameter
    required String title,
    required IconData icon,
    bool hasTrailingArrow = false,
  }) {
    return Row(
      key: key, // Assign the key to the Row
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
        if (hasTrailingArrow) const Icon(Icons.arrow_right, size: 20),
      ],
    );
  }

  // Helper for items within submenus (with checkmark)
  static PopupMenuItem<T> _buildCheckedPopupMenuItem<T>({
    required String title,
    required T value,
    required bool isChecked,
  }) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Expanded(child: Text(title)),
          if (isChecked)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
        ],
      ),
    );
  }

  static Future<void> _showCreateFolderDialog(
    BuildContext context,
    String currentPath,
    Future<void> Function(String) onCreateFolder,
  ) async {
    final TextEditingController nameController = TextEditingController();
    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final String folderName = nameController.text.trim();
              if (folderName.isNotEmpty) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await onCreateFolder(folderName);
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
    });
  }

  static Future<void> _showCreateFileDialog(
    BuildContext context,
    String currentPath,
  ) async {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final folderListBloc = context.read<FolderListBloc>();

    final TextEditingController nameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New File'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'File Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final String fileName = nameController.text.trim();
              if (fileName.isNotEmpty) {
                final String newFilePath =
                    '$currentPath${Platform.pathSeparator}$fileName';

                try {
                  File(newFilePath).createSync();
                  folderListBloc.add(FolderListLoad(currentPath));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error creating file: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
    });
  }

  static Future<void> _showFolderProperties(
    BuildContext context,
    String path,
  ) async {
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final directory = Directory(path);
      final stat = await directory.stat();

      int totalSize = 0;
      int fileCount = 0;
      int folderCount = 0;

      try {
        await for (final entity in directory.list(recursive: false)) {
          if (entity is File) {
            fileCount++;
            totalSize += await entity.length();
          } else if (entity is Directory) {
            folderCount++;
          }
        }
      } catch (e) {
        // Ignore errors
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Folder Properties'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Path'),
                  subtitle: Text(path),
                ),
                ListTile(
                  title: const Text('Created'),
                  subtitle: Text(stat.modified.toLocal().toString()),
                ),
                ListTile(
                  title: const Text('Content'),
                  subtitle: Text('$fileCount files, $folderCount folders'),
                ),
                ListTile(
                  title: const Text('Size (direct children)'),
                  subtitle: Text(_formatFileSize(totalSize)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error retrieving folder properties: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      final kb = sizeInBytes / 1024;
      return '${kb.toStringAsFixed(2)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      final mb = sizeInBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } else {
      final gb = sizeInBytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }
}
