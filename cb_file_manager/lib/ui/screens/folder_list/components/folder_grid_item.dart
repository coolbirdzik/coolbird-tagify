import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiêu đề menu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    folder.basename(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tùy chọn mở thư mục
          ListTile(
            leading: Icon(Icons.folder_open,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Open Folder',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              if (onTap != null) {
                onTap!(folder.path);
              }
            },
          ),

          // Tùy chọn Sao chép (Copy)
          ListTile(
            leading: Icon(EvaIcons.copyOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Copy',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              // Gửi sự kiện Copy tới BLoC
              context.read<FolderListBloc>().add(CopyFile(folder));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Copied "${folder.basename()}" to clipboard')),
              );
            },
          ),

          // Tùy chọn Cắt (Cut)
          ListTile(
            leading: Icon(Icons.content_cut,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Cut',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              // Gửi sự kiện Cut tới BLoC
              context.read<FolderListBloc>().add(CutFile(folder));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Cut "${folder.basename()}" to clipboard')),
              );
            },
          ),

          // Tùy chọn Đổi tên (Rename)
          ListTile(
            leading: Icon(EvaIcons.editOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Rename',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context);
            },
          ),

          // Tùy chọn Dán (Paste) - chỉ hiển thị nếu người dùng đã sao chép hoặc cắt một tệp tin
          // Lưu ý: Tính năng này cần kiểm tra xem clipboard có dữ liệu không
          // Trong thư mục, chúng ta cần truyền thư mục hiện tại làm nơi đích
          ListTile(
            leading: Icon(Icons.content_paste,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Paste Here',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              context.read<FolderListBloc>().add(PasteFile(folder.path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pasting...')),
              );
            },
          ),

          // Tùy chọn Thuộc tính (Properties)
          ListTile(
            leading: Icon(EvaIcons.infoOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Properties',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () async {
              try {
                final FileStat stat = await folder.stat();

                if (context.mounted) {
                  Navigator.pop(context);
                  // Hiển thị hộp thoại thuộc tính thư mục
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Folder Properties'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _infoRow('Name', folder.basename()),
                            const Divider(),
                            _infoRow('Path', folder.path),
                            const Divider(),
                            _infoRow('Modified',
                                stat.modified.toString().split('.')[0]),
                            const Divider(),
                            _infoRow('Accessed',
                                stat.accessed.toString().split('.')[0]),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CLOSE'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error getting folder properties: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error getting folder properties: $e')),
                  );
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
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
