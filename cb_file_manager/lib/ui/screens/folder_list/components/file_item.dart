import 'dart:io';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';

import 'tag_dialogs.dart';

class FileItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final extension = file.path.split('.').last.toLowerCase();
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
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = EvaIcons.fileTextOutline;
      iconColor = Colors.indigo;
    } else {
      icon = EvaIcons.fileOutline;
      iconColor = Colors.grey;
    }

    // Get tags for this file
    final List<String> fileTags = state.getTagsForFile(file.path);

    return GestureDetector(
      onSecondaryTap: () => _showFileContextMenu(context, isVideo, isImage),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        toggleFileSelection(file.path);
                      },
                    )
                  : _buildLeadingWidget(isVideo, icon, iconColor),
              title: Text(_basename(file)),
              subtitle: FutureBuilder<FileStat>(
                future: file.stat(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    String sizeText = _formatFileSize(snapshot.data!.size);
                    return Text(
                        '${snapshot.data!.modified.toString().split('.')[0]} • $sizeText');
                  }
                  return const Text('Loading...');
                },
              ),
              onTap: () {
                if (isSelectionMode) {
                  toggleFileSelection(file.path);
                } else if (onFileTap != null) {
                  onFileTap!(file, isVideo);
                } else if (isVideo) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerFullScreen(file: file),
                    ),
                  );
                } else if (isImage) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(file: file),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsScreen(file: file),
                    ),
                  );
                }
              },
              onLongPress: () {
                if (isSelectionMode) {
                  toggleFileSelection(file.path);
                } else {
                  _showFileContextMenu(context, isVideo, isImage);
                }
              },
              trailing: isSelectionMode
                  ? null
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (String value) {
                        if (value == 'tag') {
                          showAddTagToFileDialog(context, file.path);
                        } else if (value == 'delete_tag') {
                          showDeleteTagDialog(context, file.path, fileTags);
                        } else if (value == 'details') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FileDetailsScreen(file: file),
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
                        if (fileTags.isNotEmpty)
                          const PopupMenuItem(
                            value: 'delete_tag',
                            child: Text('Remove Tag'),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Properties'),
                        ),
                        const PopupMenuItem(
                          value: 'trash',
                          child: Text('Move to Trash',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
            ),
            if (fileTags.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  children: fileTags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      backgroundColor: Colors.green[100],
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {},
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFileContextMenu(BuildContext context, bool isVideo, bool isImage) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<String> fileTags = state.getTagsForFile(file.path);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                Icon(
                  isVideo
                      ? EvaIcons.videoOutline
                      : isImage
                          ? EvaIcons.imageOutline
                          : EvaIcons.fileOutline,
                  color: isVideo
                      ? Colors.red
                      : isImage
                          ? Colors.blue
                          : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _basename(file),
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
          ListTile(
            leading: Icon(
                isVideo
                    ? EvaIcons.playCircleOutline
                    : isImage
                        ? EvaIcons.imageOutline
                        : EvaIcons.eyeOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              isVideo
                  ? 'Play Video'
                  : isImage
                      ? 'View Image'
                      : 'Open File',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              if (onFileTap != null) {
                onFileTap!(file, isVideo);
              } else if (isVideo) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerFullScreen(file: file),
                  ),
                );
              } else if (isImage) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageViewerScreen(
                      file: file,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileDetailsScreen(file: file),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(EvaIcons.externalLinkOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Open With...',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => OpenWithDialog(filePath: file.path),
              );
            },
          ),
          ListTile(
            leading: Icon(EvaIcons.infoOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Properties',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FileDetailsScreen(file: file),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(EvaIcons.bookmarkOutline,
                color: isDarkMode ? Colors.white70 : Colors.black87),
            title: Text(
              'Add Tag',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              showAddTagToFileDialog(context, file.path);
            },
          ),
          if (fileTags.isNotEmpty)
            ListTile(
              leading: Icon(EvaIcons.minusCircleOutline,
                  color: isDarkMode ? Colors.white70 : Colors.black87),
              title: Text(
                'Remove Tag',
                style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87),
              ),
              onTap: () {
                Navigator.pop(context);
                showDeleteTagDialog(context, file.path, fileTags);
              },
            ),
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
              // Dispatch copy event to the bloc
              context.read<FolderListBloc>().add(CopyFile(file));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Copied "${_basename(file)}" to clipboard')),
              );
            },
          ),
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
              // Dispatch cut event to the bloc
              context.read<FolderListBloc>().add(CutFile(file));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Cut "${_basename(file)}" to clipboard')),
              );
            },
          ),
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
          ListTile(
            leading: Icon(EvaIcons.trash2Outline, color: Colors.red),
            title: Text(
              'Move to Trash',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _moveToTrash(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _moveToTrash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('Do you want to move "${_basename(file)}" to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('MOVE TO TRASH',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final trashManager = TrashManager();
        await trashManager.moveToTrash(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved "${_basename(file)}" to trash')),
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
    final String fileName = _basename(file);
    final String extension = pathlib.extension(file.path);
    final String fileNameWithoutExt =
        pathlib.basenameWithoutExtension(file.path);

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
              context
                  .read<FolderListBloc>()
                  .add(RenameFileOrFolder(file, newName));
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
            videoPath: file.path,
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
      return Icon(icon, color: iconColor, size: 36);
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
