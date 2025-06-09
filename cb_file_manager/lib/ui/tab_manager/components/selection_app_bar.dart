import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'tag_dialogs.dart';

/// AppBar component displayed when in selection mode
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final int selectedFileCount;
  final int selectedFolderCount;
  final VoidCallback onClearSelection;
  final List<String> selectedFilePaths;
  final List<String> selectedFolderPaths;
  final Function(BuildContext) showRemoveTagsDialog;
  final Function(BuildContext) showManageAllTagsDialog;
  final Function(BuildContext) showDeleteConfirmationDialog;
  final bool isNetworkPath;

  const SelectionAppBar({
    Key? key,
    required this.selectedCount,
    required this.selectedFileCount,
    required this.selectedFolderCount,
    required this.onClearSelection,
    required this.selectedFilePaths,
    required this.selectedFolderPaths,
    required this.showRemoveTagsDialog,
    required this.showManageAllTagsDialog,
    required this.showDeleteConfirmationDialog,
    this.isNetworkPath = false,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Calculate the actual count from the lists or use provided counts
    final int fileCount = selectedFileCount;
    final int folderCount = selectedFolderCount;
    final int actualCount = fileCount + folderCount;

    // Warn if our count doesn't match what was passed in
    if (selectedCount != actualCount) {
      debugPrint(
          "⚠️ SelectionAppBar - Count mismatch: passed=$selectedCount, actual=$actualCount (files=$fileCount, folders=$folderCount)");
    }

    return AppBar(
      title: Text(
          '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} selected'),
      leading: IconButton(
        icon: const Icon(EvaIcons.close),
        onPressed: onClearSelection,
        tooltip: 'Cancel Selection',
      ),
      actions: [
        // Show tag management options if we have files selected
        if (fileCount > 0 &&
            !isNetworkPath) // Don't show tag options for network paths
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add_tags') {
                showBatchAddTagDialog(context, selectedFilePaths);
              } else if (value == 'remove_tags') {
                showRemoveTagsDialog(context);
              } else if (value == 'manage_all_tags') {
                showManageAllTagsDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'add_tags',
                child: ListTile(
                  leading: Icon(EvaIcons.plusCircle),
                  title: Text('Add Tags'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'remove_tags',
                child: ListTile(
                  leading: Icon(EvaIcons.closeCircle),
                  title: Text('Remove Tags'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage_all_tags',
                child: ListTile(
                  leading: Icon(EvaIcons.settingsOutline),
                  title: Text('Manage Tags'),
                ),
              ),
            ],
            icon: const Icon(EvaIcons.shoppingBag),
            tooltip: 'Tag Actions',
          ),

        // Delete button always shown
        IconButton(
          icon: const Icon(EvaIcons.trash2),
          onPressed: () => showDeleteConfirmationDialog(context),
          tooltip: 'Delete Selected Items',
        ),
      ],
    );
  }
}
