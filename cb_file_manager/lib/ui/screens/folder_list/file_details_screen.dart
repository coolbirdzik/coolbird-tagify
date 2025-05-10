import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/thumbnail_helper.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/components/video_player/custom_video_player.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/widgets/tag_management_section.dart';

class FileDetailsScreen extends StatefulWidget {
  final File file;

  const FileDetailsScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<FileDetailsScreen> createState() => _FileDetailsScreenState();
}

class _FileDetailsScreenState extends State<FileDetailsScreen> {
  late Future<FileStat> _fileStatFuture;
  bool _videoPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _fileStatFuture = widget.file.stat();
  }

  @override
  Widget build(BuildContext context) {
    final String extension = widget.file.extension().toLowerCase();
    final bool isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension);
    final bool isAudio =
        ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'].contains(extension);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
    final Color cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color secondaryTextColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;

    return BaseScreen(
      title: 'File Properties',
      actions: [
        IconButton(
          icon: const Icon(EvaIcons.externalLinkOutline),
          tooltip: 'Open with external app',
          onPressed: () {
            _showOpenWithDialog();
          },
        ),
        IconButton(
          icon: const Icon(EvaIcons.shareOutline),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share functionality not implemented yet'),
              ),
            );
          },
        ),
      ],
      body: Container(
        color: bgColor,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File preview section with hero animation
              if (isImage || isVideo || isAudio)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (isImage) _buildImagePreview(),
                      if (isVideo) _buildVideoPreview(),
                      if (isAudio) _buildAudioPreview(),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Basic file info card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 16),
                        _buildFileDetails(textColor, secondaryTextColor),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tags section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              EvaIcons.bookmarkOutline,
                              color: textColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tags',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Use the common tag management component
                        TagManagementSection(
                          filePath: widget.file.path,
                          showFileTagsHeader: false,
                          onTagsUpdated: () {
                            // Optional callback if needed
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(EvaIcons.externalLinkOutline,
                              color: textColor),
                          title: Text('Open with...',
                              style: TextStyle(color: textColor)),
                          onTap: _showOpenWithDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              Icon(EvaIcons.fileTextOutline, color: textColor),
                          title: Text('Make a copy',
                              style: TextStyle(color: textColor)),
                          onTap: () {
                            // Make a copy functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Copy functionality not implemented yet')),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(EvaIcons.trash2Outline,
                              color: Colors.red[300]),
                          title: Text('Delete file',
                              style: TextStyle(color: Colors.red[300])),
                          onTap: () {
                            // Delete functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Delete functionality coming soon')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final extension = widget.file.extension().toLowerCase();
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    IconData fileIcon;
    Color iconColor;

    // Set icon based on file type
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      fileIcon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      fileIcon = EvaIcons.videoOutline;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      fileIcon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if (['pdf'].contains(extension)) {
      fileIcon = EvaIcons.fileOutline;
      iconColor = Colors.orange;
    } else if (['doc', 'docx', 'txt', 'rtf'].contains(extension)) {
      fileIcon = EvaIcons.fileTextOutline;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      fileIcon = EvaIcons.gridOutline;
      iconColor = Colors.green;
    } else {
      fileIcon = EvaIcons.fileOutline;
      iconColor = Colors.grey;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            fileIcon,
            size: 28,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pathlib.basename(widget.file.path),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.file.extension().toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: Hero(
        tag: widget.file.path,
        child: Image.file(
          widget.file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image,
                      size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Show thumbnail first
          if (!_videoPlayerReady)
            Hero(
              tag: widget.file.path,
              child: ThumbnailHelper.buildVideoThumbnail(
                videoPath: widget.file.path,
                width: double.infinity,
                height: 300,
                isVisible: true,
                onThumbnailGenerated: (_) {},
                fallbackBuilder: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 64, color: Colors.white54),
                      const SizedBox(height: 8),
                      const Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Video player with opacity animation based on ready state
          AnimatedOpacity(
            opacity: _videoPlayerReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: CustomVideoPlayer(
              file: widget.file,
              showControls: true,
              allowFullScreen: true,
              allowMuting: true,
              onInitialized: () {
                setState(() {
                  _videoPlayerReady = true;
                });
              },
              onError: (errorMessage) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error playing video: $errorMessage'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      color: Colors.grey[900],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(EvaIcons.musicOutline,
                size: 64, color: Colors.purpleAccent),
          ),
          const SizedBox(height: 16),
          Text(
            pathlib.basename(widget.file.path),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 36,
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Audio playback not implemented in this preview version'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.purpleAccent,
                ),
                child: const Icon(Icons.play_arrow, size: 32),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 36,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileDetails(Color textColor, Color secondaryTextColor) {
    return FutureBuilder<FileStat>(
      future: _fileStatFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'Error loading file details',
              style: TextStyle(color: textColor),
            ),
          );
        }

        final stat = snapshot.data!;
        final fileSize = _formatFileSize(stat.size);
        final formattedDate = stat.modified.toString().split('.')[0];

        return Column(
          children: [
            _buildDetailRow('Size', fileSize, Icons.storage_outlined, textColor,
                secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow('Location', pathlib.dirname(widget.file.path),
                Icons.folder_outlined, textColor, secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow('Created', stat.changed.toString().split('.')[0],
                Icons.date_range_outlined, textColor, secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow('Modified', formattedDate,
                Icons.edit_calendar_outlined, textColor, secondaryTextColor),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      Color textColor, Color secondaryTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: secondaryTextColor),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showOpenWithDialog() {
    showDialog(
      context: context,
      builder: (context) => OpenWithDialog(filePath: widget.file.path),
    );
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
