import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/components/video_player/video_player.dart';

class VideoPlayerDialog extends StatefulWidget {
  final File videoFile;

  const VideoPlayerDialog({
    Key? key,
    required this.videoFile,
  }) : super(key: key);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  bool _isFullScreen = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: _isFullScreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.videoFile.path.split('/').last,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: VideoPlayer.file(
              file: widget.videoFile,
              showControls: true,
              allowFullScreen: true,
              allowMuting: true,
              onFullScreenChanged: () {
                setState(() {
                  _isFullScreen = !_isFullScreen;
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
}
