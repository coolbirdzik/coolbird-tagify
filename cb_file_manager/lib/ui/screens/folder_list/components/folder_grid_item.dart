import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';

class FolderGridItem extends StatelessWidget {
  final Directory folder;
  final Function(String)? onTap;

  const FolderGridItem({
    Key? key,
    required this.folder,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => _showFolderContextMenu(
          context), // Thêm menu ngữ cảnh khi click chuột phải
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap!(folder.path);
            }
          },
          onLongPress: () => _showFolderContextMenu(
              context), // Thêm menu ngữ cảnh khi nhấn giữ
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon section
              Expanded(
                flex: 3,
                child: Center(
                  child: Icon(
                    Icons.folder,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              ),
              // Text section - improved to prevent overflow
              Container(
                constraints: BoxConstraints(
                    minHeight: 36,
                    maxHeight: 40), // Increased max height and added min height
                padding:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                width: double.infinity,
                child: LayoutBuilder(builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folder.basename(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Flexible(
                        child: FutureBuilder<FileStat>(
                          future: folder.stat(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                '${snapshot.data!.modified.toString().split('.')[0]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 8),
                              );
                            }
                            return const Text('Loading...',
                                style: TextStyle(fontSize: 8));
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hiển thị menu ngữ cảnh cho thư mục
  void _showFolderContextMenu(BuildContext context) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: folder,
      onNavigate: onTap,
    );
  }

  // Hiển thị hộp thoại đổi tên thư mục
  void _showRenameDialog(BuildContext context) {
    final TextEditingController controller =
        TextEditingController(text: folder.basename());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folder.basename()) {
                context
                    .read<FolderListBloc>()
                    .add(RenameFileOrFolder(folder, newName));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed folder to "$newName"')),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  // Helper cho việc hiển thị thông tin trong hộp thoại thuộc tính
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(),
            ),
          ),
        ],
      ),
    );
  }
}
