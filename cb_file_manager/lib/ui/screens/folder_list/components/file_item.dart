import 'dart:io';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';

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

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
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

    return Container(
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
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileDetailsScreen(file: file),
                  ),
                );
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
                      } else if (value == 'details' && isVideo) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileDetailsScreen(file: file),
                          ),
                        );
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
                      if (isVideo)
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('View Details'),
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
