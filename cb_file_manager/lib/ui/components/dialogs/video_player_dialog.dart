import 'dart:io';
import 'package:flutter/material.dart';
import '../video/video_player/video_player.dart';

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
      insetPadding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
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
                  content: Text(AppLocalizations.of(context)!
                      .errorPlayingVideoMessage(errorMessage)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
