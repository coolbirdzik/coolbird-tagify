import 'dart:io';

import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/helpers/media/thumbnail_helper.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/components/video_player/video_player.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/widgets/tag_management_section.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

class FileDetailsScreen extends StatefulWidget {
  final File file;

  /// Tab index to show initially (0 = default details tab)
  final int initialTab;

  const FileDetailsScreen({
    Key? key,
    required this.file,
    this.initialTab = 0,
  }) : super(key: key);

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

    // Set initial tab if specified
    if (widget.initialTab > 0) {
      // We'll switch to the specified tab after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // For now, just scroll to the Tags section if initialTab = 1
        if (widget.initialTab == 1) {
          // Find a simpler way to scroll to the Tags section
          final scrollController = PrimaryScrollController.of(context);
          if (scrollController != null) {
            // Scroll to the estimated position of the Tags section (value based on UI height)
            scrollController.animateTo(
              500, // Estimated position of the Tags section
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bool isImage = FileTypeUtils.isImageFile(widget.file.path);
    final bool isVideo = FileTypeUtils.isVideoFile(widget.file.path);
    final bool isAudio = FileTypeUtils.isAudioFile(widget.file.path);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
    final Color cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color secondaryTextColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;

    return BaseScreen(
      title: localizations.properties,
      actions: [
        IconButton(
          icon: const Icon(EvaIcons.externalLinkOutline),
          tooltip: localizations.openWith,
          onPressed: () {
            _showOpenWithDialog();
          },
        ),
        IconButton(
          icon: const Icon(EvaIcons.shareOutline),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.operationFailed),
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
                              localizations.tags,
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
                          title: Text(localizations.openWith,
                              style: TextStyle(color: textColor)),
                          onTap: _showOpenWithDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              Icon(EvaIcons.fileTextOutline, color: textColor),
                          title: Text(localizations.createCopy,
                              style: TextStyle(color: textColor)),
                          onTap: () {
                            // Make a copy functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(localizations.operationFailed)),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(EvaIcons.trash2Outline,
                              color: Colors.red[300]),
                          title: Text(localizations.deleteFile,
                              style: TextStyle(color: Colors.red[300])),
                          onTap: () {
                            // Delete functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(localizations.operationFailed)),
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
    final localizations = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final extension = widget.file.extension().toLowerCase();
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    IconData fileIcon;
    Color iconColor;

    // Set icon based on file type using FileTypeUtils
    if (FileTypeUtils.isImageFile(widget.file.path)) {
      fileIcon = EvaIcons.imageOutline;
      iconColor = Colors.blue;
    } else if (FileTypeUtils.isVideoFile(widget.file.path)) {
      fileIcon = EvaIcons.videoOutline;
      iconColor = Colors.red;
    } else if (FileTypeUtils.isAudioFile(widget.file.path)) {
      fileIcon = EvaIcons.musicOutline;
      iconColor = Colors.purple;
    } else if (FileTypeUtils.isDocumentFile(widget.file.path)) {
      fileIcon = EvaIcons.fileTextOutline;
      iconColor = Colors.blue;
    } else if (FileTypeUtils.isSpreadsheetFile(widget.file.path)) {
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
    final localizations = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: Hero(
        tag: widget.file.path,
        child: Image.file(
          widget.file,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image,
                      size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    localizations.errorLoadingImage,
                    style: const TextStyle(color: Colors.white70),
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
    final localizations = AppLocalizations.of(context)!;
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
                      const Icon(Icons.videocam,
                          size: 64, color: Colors.white54),
                      const SizedBox(height: 8),
                      Text(
                        localizations.loadingVideo,
                        style: const TextStyle(color: Colors.white70),
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
            child: VideoPlayer.file(
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
                    content:
                        Text('${localizations.operationFailed}: $errorMessage'),
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
    final localizations = AppLocalizations.of(context)!;
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
                    SnackBar(
                      content: Text(localizations.operationFailed),
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
    final localizations = AppLocalizations.of(context)!;
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
              localizations.operationFailed,
              style: TextStyle(color: textColor),
            ),
          );
        }

        final stat = snapshot.data!;
        final fileSize = _formatFileSize(stat.size);
        final formattedDate = stat.modified.toString().split('.')[0];

        return Column(
          children: [
            _buildDetailRow(localizations.fileSize, fileSize,
                Icons.storage_outlined, textColor, secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow(
                localizations.fileLocation,
                pathlib.dirname(widget.file.path),
                Icons.folder_outlined,
                textColor,
                secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow(
                localizations.fileCreated,
                stat.changed.toString().split('.')[0],
                Icons.date_range_outlined,
                textColor,
                secondaryTextColor),
            const Divider(height: 24),
            _buildDetailRow(localizations.fileModified, formattedDate,
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
