import 'dart:io';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:path/path.dart' as pathlib;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';

class FileGridItem extends StatelessWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(File, bool)? onFileTap;
  final Function()? onThumbnailGenerated;
  final Function(BuildContext, String)? showAddTagToFileDialog;
  final Function(BuildContext, String, List<String>)? showDeleteTagDialog;

  const FileGridItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    this.onFileTap,
    this.onThumbnailGenerated,
    this.showAddTagToFileDialog,
    this.showDeleteTagDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FrameTimingOptimizer().optimizeImageRendering();

    final extension = _getFileExtension(file);
    IconData icon;
    Color? iconColor;
    bool isPreviewable = false;
    bool isVideo = false;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
      isPreviewable = true;
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

    final List<String> fileTags = state.getTagsForFile(file.path);

    return GestureDetector(
      onSecondaryTap: () => _showFileContextMenu(context, isVideo),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
            if (!isSelectionMode) {
              _showFileContextMenu(context, isVideo);
            } else {
              toggleFileSelection(file.path);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    isPreviewable || isVideo
                        ? _buildThumbnail(file)
                        : Center(
                            child: Icon(
                              icon,
                              size: 48,
                              color: iconColor,
                            ),
                          ),
                    if (isSelectionMode)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(EvaIcons.checkmark,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _basename(file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<FileStat>(
                        future: file.stat(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              _formatFileSize(snapshot.data!.size),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('Loading...',
                              style: TextStyle(fontSize: 10));
                        },
                      ),
                      if (fileTags.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(EvaIcons.bookmarkOutline,
                                  size: 12, color: Colors.green[800]),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${fileTags.length} tags',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileContextMenu(BuildContext context, bool isVideo) {
    bool isImage = file.path.toLowerCase().endsWith('.jpg') ||
        file.path.toLowerCase().endsWith('.jpeg') ||
        file.path.toLowerCase().endsWith('.png') ||
        file.path.toLowerCase().endsWith('.gif') ||
        file.path.toLowerCase().endsWith('.webp');

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<String> fileTags = state.getTagsForFile(file.path);
    final extension = _getFileExtension(file);

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
          // Thêm tùy chọn Sao chép (Copy)
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
              context.read<FolderListBloc>().add(CopyFile(file));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Copied "${_basename(file)}" to clipboard')),
              );
            },
          ),
          // Thêm tùy chọn Cắt (Cut)
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
              context.read<FolderListBloc>().add(CutFile(file));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Cut "${_basename(file)}" to clipboard')),
              );
            },
          ),
          // Thêm tùy chọn Đổi tên (Rename)
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
          if (showAddTagToFileDialog != null)
            ListTile(
              leading: Icon(EvaIcons.bookmarkOutline,
                  color: isDarkMode ? Colors.white70 : Colors.black87),
              title: Text(
                'Add Tag',
                style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87),
              ),
              onTap: () {
                Navigator.pop(context);
                showAddTagToFileDialog!(context, file.path);
              },
            ),
          if (fileTags.isNotEmpty && showDeleteTagDialog != null)
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
                showDeleteTagDialog!(context, file.path, fileTags);
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
            onTap: () async {
              Navigator.pop(context);

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Move to Trash?'),
                  content: Text(
                      'Do you want to move "${_basename(file)}" to trash?'),
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
                    SnackBar(
                        content: Text('Moved "${_basename(file)}" to trash')),
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(File file) {
    FrameTimingOptimizer().optimizeImageRendering();

    final String extension = _getFileExtension(file);
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension);

    if (isVideo) {
      return RepaintBoundary(
        child: Hero(
          tag: file.path,
          child: LazyVideoThumbnail(
            videoPath: file.path,
            width: double.infinity,
            height: double.infinity,
            keepAlive: true,
            onThumbnailGenerated: (path) {
              if (onThumbnailGenerated != null) {
                onThumbnailGenerated!();
              }
            },
            fallbackBuilder: () => Container(
              color: Colors.black12,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      EvaIcons.videoOutline,
                      size: 36,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Video',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return RepaintBoundary(
        child: Hero(
          tag: file.path,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  EvaIcons.alertTriangleOutline,
                  size: 48,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ),
      );
    }
  }

  String _basename(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  String _getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
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

  void _showRenameDialog(BuildContext context) {
    final TextEditingController nameController =
        TextEditingController(text: _basename(file));
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

              // Dispatch rename event with correct event type
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
}
