import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/utils/fluent_background.dart';
import 'package:cb_file_manager/ui/components/window_caption_buttons.dart';
import 'package:window_manager/window_manager.dart';

/// Custom app bar for video player with window controls and glass blur effect
class VideoPlayerAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final bool showWindowControls;
  final double blurAmount;
  final double opacity;

  const VideoPlayerAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.onClose,
    this.showWindowControls = true,
    this.blurAmount = 12.0,
    this.opacity = 0.6,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<VideoPlayerAppBar> createState() => _VideoPlayerAppBarState();
}

class _VideoPlayerAppBarState extends State<VideoPlayerAppBar> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return FluentBackground.appBar(
      context: context,
      title: _buildTitle(),
      actions: _buildActions(),
      blurAmount: widget.blurAmount,
      opacity: widget.opacity,
    );
  }

  Widget _buildTitle() {
    final content = Row(
      children: [
        const Icon(EvaIcons.video, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    // Allow dragging the window by the title area on desktop
    if (_isDesktopPlatform) {
      return DragToMoveArea(child: content);
    }
    return content;
  }

  List<Widget> _buildActions() {
    final List<Widget> actions = [];

    // Add custom actions if provided
    if (widget.actions != null) {
      actions.addAll(widget.actions!);
    }

    // Add window controls for desktop platforms
    if (widget.showWindowControls && _isDesktopPlatform) {
      actions.add(WindowCaptionButtons(
        theme: Theme.of(context),
        onClose: widget.onClose ??
            () {
              // Close the app completely when close button is pressed
              exit(0);
            },
      ));
    }

    return actions;
  }
}
