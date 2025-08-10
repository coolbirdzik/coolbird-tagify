import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Temporary simplified video player for build testing
class CustomVideoPlayer extends StatefulWidget {
  final File file;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final bool allowFullScreen;
  final bool allowMuting;
  final bool allowPlaybackSpeedChanging;
  final Function(Map<String, dynamic>)? onVideoInitialized;
  final Function(String)? onError;
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;
  final bool hasNextVideo;
  final bool hasPreviousVideo;
  final VoidCallback? onControlVisibilityChanged;
  final VoidCallback? onFullScreenChanged;
  final VoidCallback? onInitialized;
  final bool showStreamingSpeed;
  final VoidCallback? onToggleStreamingSpeed;

  const CustomVideoPlayer({
    Key? key,
    required this.file,
    this.autoPlay = true,
    this.looping = false,
    this.showControls = true,
    this.allowFullScreen = true,
    this.allowMuting = true,
    this.allowPlaybackSpeedChanging = true,
    this.onVideoInitialized,
    this.onError,
    this.onNextVideo,
    this.onPreviousVideo,
    this.hasNextVideo = false,
    this.hasPreviousVideo = false,
    this.onControlVisibilityChanged,
    this.onFullScreenChanged,
    this.onInitialized,
    this.showStreamingSpeed = false,
    this.onToggleStreamingSpeed,
  }) : super(key: key);

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Simulate initialization
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onInitialized?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });

        widget.onError?.call(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading video: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _initializePlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_file, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Video Player (Placeholder)',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'File: ${widget.file.path}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Media Kit integration pending',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// A component that displays video information
class VideoInfoDialog extends StatelessWidget {
  final File file;
  final Map<String, dynamic>? videoMetadata;

  const VideoInfoDialog({
    Key? key,
    required this.file,
    this.videoMetadata,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Video Information'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('File Name', file.path.split('/').last),
            const Divider(),
            _infoRow('Path', file.path),
            const Divider(),
            _infoRow('Type', file.path.split('.').last.toUpperCase()),
            if (videoMetadata != null) ...[
              const Divider(),
              _infoRow('Duration', 'Unknown'),
              const Divider(),
              _infoRow('Resolution', 'Unknown'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
