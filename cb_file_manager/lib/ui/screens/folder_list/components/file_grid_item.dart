import 'dart:io';

import 'package:cb_file_manager/helpers/thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:flutter/material.dart';

class FileGridItem extends StatelessWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String) toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(File, bool)? onFileTap; // Callback cho file click

  const FileGridItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    this.onFileTap, // Thêm parameter mới
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final extension = _getFileExtension(file);
    IconData icon;
    Color? iconColor;
    bool isPreviewable = false;
    bool isVideo = false;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue;
      isPreviewable = true;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = Icons.videocam;
      iconColor = Colors.red;
      isVideo = true;
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

    // Use a Container with border instead of Card with elevation for flat design
    return Container(
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
            // Sử dụng callback thay vì điều hướng trực tiếp
            onFileTap!(file, isVideo);
          } else if (isVideo) {
            // Fallback cho các component không truyền callback
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerFullScreen(file: file),
              ),
            );
          } else {
            // Fallback cho các component không truyền callback
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
            // File preview or icon - give it most of the space
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show image preview or appropriate icon for video files
                  isPreviewable || isVideo
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
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // File name and tags - wrap in a Flexible to prevent overflow
            Flexible(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Use minimum vertical space
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
                    // Tag indicators - only show if we have space and tags
                    if (fileTags.isNotEmpty)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.label,
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
    );
  }

  Widget _buildThumbnail(File file) {
    final String extension = _getFileExtension(file);
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension);

    if (isVideo) {
      // Use the new VideoThumbnailHelper instead of ThumbnailHelper
      return Hero(
        tag: file.path,
        child: VideoThumbnailHelper.buildVideoThumbnail(
          videoPath: file.path,
          width: double.infinity,
          height: double.infinity,
          fallbackBuilder: () => Container(
            color: Colors.black12,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    size: 36,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      );
    } else {
      // For image files, use the existing Image.file approach
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
}
