import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';

class NetworkFolderContextMenu {
  static void show({
    required BuildContext context,
    required Offset globalPosition,
    required VoidCallback onRefresh,
    required VoidCallback onCreateFolder,
    required VoidCallback onUploadFile,
  }) {
    final RenderObject? renderObject = Overlay.of(
      context,
    ).context.findRenderObject();
    final RenderBox overlay = renderObject as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: onRefresh,
          child: const ListTile(
            leading: Icon(EvaIcons.refresh),
            title: Text('Refresh'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: onCreateFolder,
          child: const ListTile(
            leading: Icon(EvaIcons.folderAdd),
            title: Text('Create Folder'),
          ),
        ),
        PopupMenuItem(
          onTap: onUploadFile,
          child: const ListTile(
            leading: Icon(EvaIcons.upload),
            title: Text('Upload File'),
          ),
        ),
      ],
      elevation: 8.0,
    );
  }
}
