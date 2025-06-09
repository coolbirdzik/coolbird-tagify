import 'dart:io';

import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:flutter/material.dart';

class PathNavigationBar extends StatefulWidget {
  final String currentPath;
  final String tabId;
  final bool isNetworkPath;
  final TextEditingController pathController;
  final Function(String) onPathSubmitted;

  const PathNavigationBar({
    Key? key,
    required this.currentPath,
    required this.tabId,
    required this.isNetworkPath,
    required this.pathController,
    required this.onPathSubmitted,
  }) : super(key: key);

  @override
  _PathNavigationBarState createState() => _PathNavigationBarState();
}

class _PathNavigationBarState extends State<PathNavigationBar> {
  bool _isEditing = false;
  late FocusNode _pathFocusNode;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _pathFocusNode = FocusNode();
    if (widget.isNetworkPath) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _pathFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _pathFocusNode.requestFocus();
    });
  }

  void _stopEditing() {
    if (widget.isNetworkPath) {
      return;
    }
    setState(() {
      _isEditing = false;
      _pathFocusNode.unfocus();
    });
  }

  Widget _buildPathSegments() {
    final pathSegments = widget.currentPath.split(Platform.pathSeparator);
    if (pathSegments.isEmpty ||
        (pathSegments.length == 1 && pathSegments[0].isEmpty)) {
      return GestureDetector(
        onTap: _startEditing,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'This PC',
            style: const TextStyle(fontSize: 16.0),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: _isHovering
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: pathSegments.length,
            separatorBuilder: (context, index) =>
                const Icon(Icons.chevron_right, size: 18.0),
            itemBuilder: (context, index) {
              final segment = pathSegments[index];
              if (index == 0 && segment.isEmpty) {
                return const SizedBox.shrink();
              }
              final segmentPath = pathSegments
                  .sublist(0, index + 1)
                  .join(Platform.pathSeparator);
              return InkWell(
                onTap: () => widget.onPathSubmitted(segmentPath),
                borderRadius: BorderRadius.circular(4.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    segment.isEmpty && index == 0 ? 'Root' : segment,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEditablePathField() {
    return Container(
      height: 40.0,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: widget.pathController,
        focusNode: _pathFocusNode,
        onSubmitted: (path) {
          widget.onPathSubmitted(path);
          _stopEditing();
        },
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          border: InputBorder.none,
          hintText: 'Enter path...',
          hintStyle: TextStyle(
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        style: TextStyle(
          fontSize: 14.0,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        onTapOutside: (_) => _stopEditing(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isEditing ? _buildEditablePathField() : _buildPathSegments();
  }
}
