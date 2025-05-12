import 'dart:io';
import 'dart:async';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:path/path.dart' as pathlib;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/widgets/tag_chip.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';

class FileGridItem extends StatefulWidget {
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
  State<FileGridItem> createState() => _FileGridItemState();
}

class _FileGridItemState extends State<FileGridItem> {
  late List<String> _fileTags;
  StreamSubscription? _tagChangeSubscription;

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);

    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
  }

  @override
  void dispose() {
    _tagChangeSubscription?.cancel();
    super.dispose();
  }

  void _onTagChanged(String changedFilePath) {
    if (changedFilePath == widget.file.path ||
        changedFilePath == "global:tag_deleted") {
      final newTags = widget.state.getTagsForFile(widget.file.path);

      if (!_areTagListsEqual(newTags, _fileTags)) {
        setState(() {
          _fileTags = newTags;
        });
      }
    }
  }

  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!list2.contains(list1[i])) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(FileGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTags = widget.state.getTagsForFile(widget.file.path);
    if (!_areTagListsEqual(newTags, _fileTags)) {
      setState(() {
        _fileTags = newTags;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    FrameTimingOptimizer().optimizeImageRendering();

    final extension = widget.file.path.split('.').last.toLowerCase();
    final bool isVideo = [
      'mp4',
      'avi',
      'mov',
      'mkv',
      'webm',
      'flv',
      'wmv',
    ].contains(extension);
    final bool isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);

    IconData icon;
    Color? iconColor;
    bool isPreviewable = false;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
      isPreviewable = true;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = EvaIcons.videoOutline;
      iconColor = Colors.red;
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

    return GestureDetector(
      onSecondaryTap: () => _showFileContextMenu(context, isVideo),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.blue.shade50
              : Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
                  builder: (context) => ImageViewerScreen(file: widget.file),
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
            if (!widget.isSelectionMode) {
              _showFileContextMenu(context, isVideo);
            } else {
              widget.toggleFileSelection(widget.file.path);
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
                        ? _buildThumbnail(widget.file)
                        : Center(
                            child: FutureBuilder<Widget>(
                              future: FileIconHelper.getIconForFile(
                                widget.file,
                                size: 48,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  // Return a generic icon while loading
                                  return Icon(icon, size: 48, color: iconColor);
                                }

                                if (snapshot.hasData) {
                                  return snapshot.data!;
                                }

                                // Fallback to generic icon
                                return Icon(icon, size: 48, color: iconColor);
                              },
                            ),
                          ),
                    if (widget.isSelectionMode)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color:
                                widget.isSelected ? Colors.blue : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: widget.isSelected
                                ? const Icon(
                                    EvaIcons.checkmark,
                                    size: 16,
                                    color: Colors.white,
                                  )
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
                        _basename(widget.file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<FileStat>(
                        future: widget.file.stat(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              _formatFileSize(snapshot.data!.size),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text(
                            'Loading...',
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                      if (_fileTags.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                EvaIcons.bookmarkOutline,
                                size: 12,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: _fileTags.length == 1
                                    ? TagChip(
                                        tag: _fileTags.first,
                                        isCompact: true,
                                        onTap: () {
                                          // Search by tag functionality
                                          final bloc =
                                              BlocProvider.of<FolderListBloc>(
                                            context,
                                          );
                                          bloc.add(
                                            SearchByTag(_fileTags.first),
                                          );
                                        },
                                      )
                                    : Text(
                                        '${_fileTags.length} ${_fileTags.length == 1 ? 'tag' : 'tags'}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.w500,
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
    bool isImage = widget.file.path.toLowerCase().endsWith('.jpg') ||
        widget.file.path.toLowerCase().endsWith('.jpeg') ||
        widget.file.path.toLowerCase().endsWith('.png') ||
        widget.file.path.toLowerCase().endsWith('.gif') ||
        widget.file.path.toLowerCase().endsWith('.webp');

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

  Widget _buildThumbnail(File file) {
    FrameTimingOptimizer().optimizeImageRendering();

    final String extension = _getFileExtension(file);
    final bool isVideo = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'flv',
      'wmv',
    ].contains(extension);

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
              if (widget.onThumbnailGenerated != null) {
                widget.onThumbnailGenerated!();
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
                        horizontal: 8,
                        vertical: 4,
                      ),
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
    final TextEditingController nameController = TextEditingController(
      text: _basename(widget.file),
    );
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

              // Dispatch rename event with correct event type
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
}
