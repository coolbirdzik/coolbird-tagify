import 'dart:io';
import 'dart:async'; // Thêm import cho StreamSubscription

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart'; // Import TagManager để lắng nghe thay đổi
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
import 'package:cb_file_manager/config/app_theme.dart'; // Import app theme
import 'package:cb_file_manager/widgets/tag_chip.dart'; // Import the new TagChip widget
import 'package:cb_file_manager/ui/tab_manager/components/tag_dialogs.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';

class FileItem extends StatefulWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) toggleFileSelection;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(File, bool)? onFileTap;

  const FileItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.onFileTap,
  }) : super(key: key);

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  late List<String> _fileTags;
  StreamSubscription? _tagChangeSubscription;

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);

    // Đăng ký lắng nghe thay đổi tag
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
  }

  @override
  void dispose() {
    // Hủy đăng ký lắng nghe khi widget bị hủy
    _tagChangeSubscription?.cancel();
    super.dispose();
  }

  // Xử lý sự kiện thay đổi tag
  void _onTagChanged(String changedFilePath) {
    // Kiểm tra xem có phải tag_only event không
    bool isTagOnlyEvent = false;
    String actualPath = changedFilePath;

    if (changedFilePath.startsWith("tag_only:")) {
      isTagOnlyEvent = true;
      actualPath = changedFilePath.substring("tag_only:".length);
    }

    // Chỉ xử lý nếu sự kiện liên quan đến file này
    if (actualPath == widget.file.path ||
        changedFilePath == "global:tag_deleted") {
      // Chỉ xóa cache khi cần thiết, không xóa nếu là tag_only event
      if (!isTagOnlyEvent) {
        TagManager.clearCache();
      }

      // Lấy tags mới từ state
      final newTags = widget.state.getTagsForFile(widget.file.path);

      // Cập nhật UI nếu tags đã thay đổi
      if (!_areTagListsEqual(newTags, _fileTags)) {
        setState(() {
          _fileTags = newTags;
        });
      }
    }
  }

  // Helper để so sánh hai danh sách tag
  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!list2.contains(list1[i])) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(FileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Vẫn giữ mã này để cập nhật từ state khi state thay đổi
    final newTags = widget.state.getTagsForFile(widget.file.path);
    if (!_areTagListsEqual(newTags, _fileTags)) {
      setState(() {
        _fileTags = newTags;
      });
    }
  }

  // Hàm xóa tag trực tiếp, không reload tab
  Future<void> _removeTagDirectly(String tag) async {
    try {
      // Xóa tag
      await TagManager.removeTag(widget.file.path, tag);

      // Cập nhật danh sách local
      setState(() {
        _fileTags.remove(tag);
      });

      // Thông báo cho các thành phần khác với prefix tag_only
      TagManager.instance.notifyTagChanged("tag_only:" + widget.file.path);

      // Thông báo bloc nếu có
      try {
        if (context.mounted) {
          final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
          bloc.add(RemoveTagFromFile(widget.file.path, tag));
        }
      } catch (e) {
        print('Error notifying bloc: $e');
      }

      // Hiển thị thông báo
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "$tag" đã được xóa'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.file.path.split('.').last.toLowerCase();
    IconData icon;
    Color? iconColor;
    bool isVideo = false;
    bool isImage = false;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
      isImage = true;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = EvaIcons.videoOutline;
      iconColor = Colors.red;
      isVideo = true;
    } else if ([
      'mp3',
      'wav',
      'ogg',
      'm4a',
      'aac',
      'flac',
    ].contains(extension)) {
      icon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if ([
      'pdf',
      'doc',
      'docx',
      'txt',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    ].contains(extension)) {
      icon = EvaIcons.fileTextOutline;
      iconColor = Colors.indigo;
    } else {
      icon = EvaIcons.fileOutline;
      iconColor = Colors.grey;
    }

    // Thay đổi phần tạo TagChip để xử lý xóa tag trực tiếp
    Widget _buildTagChip(String tag) {
      return TagChip(
        tag: tag,
        onTap: () {
          // Search by tag functionality
          final bloc = BlocProvider.of<FolderListBloc>(
            context,
          );
          bloc.add(SearchByTag(tag));
        },
        onDeleted: () {
          // Xóa tag trực tiếp thay vì hiển thị dialog
          _removeTagDirectly(tag);
        },
      );
    }

    return GestureDetector(
      onSecondaryTap: () => _showFileContextMenu(context, isVideo, isImage),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.blue.shade50
              : Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: widget.isSelectionMode
                  ? Checkbox(
                      value: widget.isSelected,
                      onChanged: (bool? value) {
                        widget.toggleFileSelection(widget.file.path);
                      },
                    )
                  : _buildLeadingWidget(isVideo, icon, iconColor),
              title: Text(_basename(widget.file)),
              subtitle: FutureBuilder<FileStat>(
                future: widget.file.stat(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    String sizeText = _formatFileSize(snapshot.data!.size);
                    return Text(
                      '${snapshot.data!.modified.toString().split('.')[0]} • $sizeText',
                    );
                  }
                  return const Text('Loading...');
                },
              ),
              onTap: () {
                if (widget.isSelectionMode) {
                  widget.toggleFileSelection(widget.file.path);
                } else if (widget.onFileTap != null) {
                  widget.onFileTap!(widget.file, isVideo);
                } else if (isVideo) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VideoPlayerFullScreen(file: widget.file),
                    ),
                  );
                } else if (isImage) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ImageViewerScreen(file: widget.file),
                    ),
                  );
                } else {
                  // Open other file types with external app
                  ExternalAppHelper.openFileWithApp(
                    widget.file.path,
                    'shell_open',
                  ).then((success) {
                    if (!success && context.mounted) {
                      // If that fails, show the open with dialog
                      showDialog(
                        context: context,
                        builder: (context) =>
                            OpenWithDialog(filePath: widget.file.path),
                      );
                    }
                  });
                }
              },
              onLongPress: () {
                if (widget.isSelectionMode) {
                  widget.toggleFileSelection(widget.file.path);
                } else {
                  _showFileContextMenu(context, isVideo, isImage);
                }
              },
              trailing: widget.isSelectionMode
                  ? null
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (String value) {
                        if (value == 'tag') {
                          widget.showAddTagToFileDialog(
                            context,
                            widget.file.path,
                          );
                        } else if (value == 'delete_tag') {
                          widget.showDeleteTagDialog(
                            context,
                            widget.file.path,
                            _fileTags,
                          );
                        } else if (value == 'details') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FileDetailsScreen(file: widget.file),
                            ),
                          );
                        } else if (value == 'trash') {
                          _moveToTrash(context);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'tag',
                          child: Text('Add Tag'),
                        ),
                        if (_fileTags.isNotEmpty)
                          const PopupMenuItem(
                            value: 'delete_tag',
                            child: Text('Manage Tags'),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Properties'),
                        ),
                        const PopupMenuItem(
                          value: 'trash',
                          child: Text(
                            'Move to Trash',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
            ),
            if (_fileTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  bottom: 8.0,
                  right: 16.0,
                ),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _fileTags.map((tag) => _buildTagChip(tag)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFileContextMenu(BuildContext context, bool isVideo, bool isImage) {
    // Use the shared file context menu
    showFileContextMenu(
      context: context,
      file: widget.file,
      fileTags: _fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: widget.showAddTagToFileDialog,
    );
  }

  Future<void> _moveToTrash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text(
          'Do you want to move "${_basename(widget.file)}" to trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'MOVE TO TRASH',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final trashManager = TrashManager();
        await trashManager.moveToTrash(widget.file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved "${_basename(widget.file)}" to trash')),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to move file to trash: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final String fileName = _basename(widget.file);
    final String extension = pathlib.extension(widget.file.path);
    final String fileNameWithoutExt = pathlib.basenameWithoutExtension(
      widget.file.path,
    );

    // Pre-fill with current name without extension
    nameController.text = fileNameWithoutExt;
    nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: fileNameWithoutExt.length,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current name: $fileName'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'New name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final String newName = nameController.text.trim() + extension;
              if (newName.isEmpty || newName == fileName) {
                Navigator.pop(context);
                return;
              }

              // Dispatch rename event
              context.read<FolderListBloc>().add(
                    RenameFileOrFolder(widget.file, newName),
                  );
              Navigator.pop(context);

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Renamed file to "$newName"')),
              );
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingWidget(bool isVideo, IconData icon, Color? iconColor) {
    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 56,
          height: 56,
          child: LazyVideoThumbnail(
            videoPath: widget.file.path,
            width: 56,
            height: 56,
            keepAlive: true,
            fallbackBuilder: () => Container(
              color: Colors.black12,
              child: Center(
                child: Icon(
                  EvaIcons.videoOutline,
                  size: 24,
                  color: Colors.red[400],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Wrap with FutureBuilder to load the app icon
      return FutureBuilder<Widget>(
        future: FileIconHelper.getIconForFile(widget.file, size: 36),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Return a generic icon while loading
            return Icon(icon, color: iconColor, size: 36);
          }

          if (snapshot.hasData) {
            return snapshot.data!;
          }

          // Fallback to generic icon
          return Icon(icon, color: iconColor, size: 36);
        },
      );
    }
  }

  String _basename(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int size) {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
