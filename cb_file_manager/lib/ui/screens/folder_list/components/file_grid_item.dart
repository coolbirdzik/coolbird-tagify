import 'dart:io';

import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:flutter/material.dart';

class FileGridItem extends StatelessWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) toggleFileSelection;
  final Function() toggleSelectionMode;

  const FileGridItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final extension = _getFileExtension(file);
    IconData icon;
    Color? iconColor;
    bool isPreviewable = false;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue;
      isPreviewable = true;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = Icons.videocam;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = Icons.audiotrack;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = Icons.description;
      iconColor = Colors.indigo;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    // Get tags for this file
    final List<String> fileTags = state.getTagsForFile(file.path);

    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (isSelectionMode) {
            toggleFileSelection(file.path);
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
            toggleSelectionMode();
            toggleFileSelection(file.path);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File preview or icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show image preview if it's an image file, otherwise show icon
                  isPreviewable
                      ? _buildThumbnail(file)
                      : Center(
                          child: Icon(
                            icon,
                            size: 48,
                            color: iconColor,
                          ),
                        ),
                  // Selection indicator overlay
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
                              ? Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // File name and tags
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
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
                  const SizedBox(height: 4),
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
                  // Tag indicators
                  if (fileTags.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.label, size: 12, color: Colors.green[800]),
                        const SizedBox(width: 4),
                        Text(
                          '${fileTags.length} tags',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(File file) {
    return Hero(
      tag: file.path,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey[400],
            ),
          );
        },
      ),
    );
  }

  String _basename(File file) {
    return file.path.split('/').last;
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
}
