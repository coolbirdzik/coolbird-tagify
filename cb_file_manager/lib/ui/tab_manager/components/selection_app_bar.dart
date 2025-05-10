import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';
import 'tag_dialogs.dart';

/// AppBar component displayed when in selection mode
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onClearSelection;
  final List<String> selectedFilePaths;
  final Function(BuildContext, List<String>) showRemoveTagsDialog;
  final Function(BuildContext) showManageAllTagsDialog;
  final Function(BuildContext) showDeleteConfirmationDialog;

  const SelectionAppBar({
    Key? key,
    required this.selectedCount,
    required this.onClearSelection,
    required this.selectedFilePaths,
    required this.showRemoveTagsDialog,
    required this.showManageAllTagsDialog,
    required this.showDeleteConfirmationDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('$selectedCount selected'),
      leading: IconButton(
        icon: const Icon(EvaIcons.close),
        onPressed: onClearSelection,
      ),
      actions: [
        if (selectedFilePaths.isNotEmpty) ...[
          // Tag management dropdown menu
          PopupMenuButton<String>(
            icon: const Icon(EvaIcons.shoppingBag),
            tooltip: 'Quản lý thẻ',
            onSelected: (value) {
              if (value == 'add_tag') {
                showBatchAddTagDialog(context, selectedFilePaths);
              } else if (value == 'manage_all_tags') {
                showManageAllTagsDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'add_tag',
                child: Row(
                  children: [
                    Icon(EvaIcons.plusCircleOutline),
                    SizedBox(width: 8),
                    Text('Thêm thẻ'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage_all_tags',
                child: Row(
                  children: [
                    Icon(EvaIcons.settings2Outline),
                    SizedBox(width: 8),
                    Text('Quản lý tất cả thẻ'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(EvaIcons.trash2Outline),
            tooltip: 'Delete selected',
            onPressed: () {
              showDeleteConfirmationDialog(context);
            },
          ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
