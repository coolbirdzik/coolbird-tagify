import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/thumbnail_helper.dart'; // Added ThumbnailHelper import
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/components/video_player/custom_video_player.dart'; // Import the custom video player

class FileDetailsScreen extends StatefulWidget {
  final File file;

  const FileDetailsScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<FileDetailsScreen> createState() => _FileDetailsScreenState();
}

class _FileDetailsScreenState extends State<FileDetailsScreen> {
  late Future<FileStat> _fileStatFuture;
  late Future<List<String>> _tagsFuture;
  late TextEditingController _tagController;
  bool _videoPlayerReady = false; // Track if video player is ready

  @override
  void initState() {
    super.initState();
    _fileStatFuture = widget.file.stat();
    _tagsFuture = TagManager.getTags(widget.file.path);
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _refreshTags() async {
    setState(() {
      _tagsFuture = TagManager.getTags(widget.file.path);
    });
  }

  Future<void> _addTag(String tag) async {
    if (tag.trim().isEmpty) return;

    try {
      await TagManager.addTag(widget.file.path, tag.trim());
      _refreshTags();
      _tagController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding tag: $e')),
      );
    }
  }

  Future<void> _removeTag(String tag) async {
    try {
      await TagManager.removeTag(widget.file.path, tag);
      _refreshTags();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing tag: $e')),
      );
    }
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

    return BaseScreen(
      title: pathlib.basename(widget.file.path),
      actions: [
        IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open with...',
          onPressed: () {
            _showOpenWithDialog();
          },
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            // Share functionality would go here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share functionality not implemented yet'),
              ),
            );
          },
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File preview section
            if (isImage) _buildImagePreview(),
            if (isVideo) _buildVideoPreview(),
            if (isAudio) _buildAudioPreview(),

            // Tags section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildTagsSection(),
                ],
              ),
            ),

            // File details section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFileDetails(),
                ],
              ),
            ),
          ],
        ),
      ),
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
    // NOTE: For actual implementation, you'd use an audio player package like just_audio
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Column(
        children: [
          const Icon(Icons.audiotrack, size: 64, color: Colors.white),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<String>>(
          future: _tagsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tags = snapshot.data ?? [];

            if (tags.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No tags added to this file yet',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              );
            }

            return Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: Colors.green[100],
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter a new tag',
                  isDense: true,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _addTag(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  _addTag(_tagController.text);
                }
              },
              child: const Text('Add Tag'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileDetails() {
    return FutureBuilder<FileStat>(
      future: _fileStatFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('Error loading file details'),
          );
        }

        final stat = snapshot.data!;
        final fileSize = _formatFileSize(stat.size);
        final formattedDate = stat.modified.toString().split('.')[0];

        return Column(
          children: [
            _buildDetailRow('Name', pathlib.basename(widget.file.path)),
            _buildDetailRow('Type', widget.file.extension().toUpperCase()),
            _buildDetailRow('Size', fileSize),
            _buildDetailRow('Path', widget.file.path),
            _buildDetailRow('Created', stat.changed.toString().split('.')[0]),
            _buildDetailRow('Modified', formattedDate),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
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
