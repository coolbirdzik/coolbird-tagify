import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // Import for keyboard keys
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/folder_thumbnail_service.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:path/path.dart' as path;
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui'; // Import for lerpDouble

/// Component for displaying a folder item in grid view
class FolderGridItem extends StatefulWidget {
  final Directory folder;
  final Function(String) onNavigate;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FolderGridItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FolderGridItem> createState() => _FolderGridItemState();
}

class _FolderGridItemState extends State<FolderGridItem> {
  bool _isHovering = false;
  // Locally cached selection state for instant response
  bool _visuallySelected = false;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
  }

  @override
  void didUpdateWidget(FolderGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update when external selection state changes
    if (widget.isSelected != oldWidget.isSelected) {
      _visuallySelected = widget.isSelected;
    }
  }

  // Handle folder selection with immediate visual feedback
  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Get keyboard state
    final RawKeyboard keyboard = RawKeyboard.instance;
    final bool isShiftPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.shift) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftRight);
    final bool isCtrlPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.control) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlRight) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.meta) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaRight);

    // Visual update depends on the selection type
    if (!isShiftPressed) {
      // For single selection or Ctrl+click, toggle this item
      setState(() {
        if (!isCtrlPressed) {
          // Single selection: this item will be selected
          _visuallySelected = true;
        } else {
          // Ctrl+click: toggle this item's selection
          _visuallySelected = !_visuallySelected;
        }
      });
    }
    // For Shift+click, we don't update visually here since the parent will handle it

    // Call the selection handler with the appropriate modifiers
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // DIRECT RENDERING - no animations, just direct state-based rendering
    final Color backgroundColor = _visuallySelected
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
        : _isHovering && widget.isDesktopMode
            ? Theme.of(context).hoverColor
            : Theme.of(context).cardColor;

    final Color borderColor = _visuallySelected
        ? Theme.of(context).primaryColor
        : _isHovering && widget.isDesktopMode
            ? Theme.of(context).primaryColor.withOpacity(0.5)
            : Colors.transparent;

    final double elevation = _visuallySelected
        ? 3
        : _isHovering && widget.isDesktopMode
            ? 2
            : 1;

    return GestureDetector(
      onSecondaryTap: () => _showFolderContextMenu(context),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: elevation,
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.isDesktopMode &&
                    widget.toggleFolderSelection != null) {
                  // On desktop, use keyboard modifiers for selection with INSTANT feedback
                  _handleFolderSelection();
                } else {
                  // Navigate to folder
                  widget.onNavigate(widget.folder.path);
                }
              },
              onDoubleTap: widget.isDesktopMode
                  ? () => widget.onNavigate(widget.folder.path)
                  : null,
              onLongPress: () => _showFolderContextMenu(context),
              child: Column(
                children: [
                  // Thumbnail/Icon section
                  Expanded(
                    flex: 3,
                    child: FolderThumbnail(folder: widget.folder),
                  ),
                  // Text section
                  Container(
                    height: 40,
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    alignment: Alignment.center,
                    child: Text(
                      widget.folder.basename(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: _visuallySelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onNavigate,
    );
  }
}

/// Component for displaying a folder item in list view
class FolderListItem extends StatefulWidget {
  final Directory folder;
  final Function(String) onNavigate;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FolderListItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<FolderListItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
  }

  @override
  void didUpdateWidget(FolderListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      setState(() {
        _visuallySelected = widget.isSelected;
      });
    }
  }

  // Handle folder selection based on keyboard modifiers
  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Check for Shift and Ctrl keys
    final RawKeyboard keyboard = RawKeyboard.instance;

    // Check for Shift key
    final bool isShiftPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.shift) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.shiftRight);

    // Check for Ctrl key (Control on Windows/Linux, Command on Mac)
    final bool isCtrlPressed =
        keyboard.keysPressed.contains(LogicalKeyboardKey.control) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.controlRight) ||
            keyboard.keysPressed
                .contains(LogicalKeyboardKey.meta) || // Command key on Mac
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
            keyboard.keysPressed.contains(LogicalKeyboardKey.metaRight);

    // Visual update for immediate feedback
    if (!isShiftPressed) {
      setState(() {
        if (!isCtrlPressed) {
          // Single selection without Ctrl: this item will be selected, others will be deselected
          _visuallySelected = true;
        } else {
          // Ctrl+click: toggle this item's selection
          _visuallySelected = !_visuallySelected;
        }
      });
    }
    // For Shift+click, we don't update visually here since the parent will handle
    // the range selection and update all items in the range

    // Call toggleFolderSelection with appropriate parameters
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Colors and effects similar to Windows Explorer
    final Color itemBackgroundColor = _visuallySelected
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
        : _isHovering && widget.isDesktopMode
            ? Theme.of(context).hoverColor
            : Theme.of(context).cardColor;

    // Border for default or hover/selected state
    final Border itemBorder = _visuallySelected
        ? Border.all(color: Theme.of(context).primaryColor, width: 1.0)
        : _isHovering && widget.isDesktopMode
            ? Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1.0)
            : Border.all(color: Colors.grey.shade300);

    return GestureDetector(
      onSecondaryTap: () => _showFolderContextMenu(context),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: itemBackgroundColor,
            border: itemBorder,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: _visuallySelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ]
                : _isHovering && widget.isDesktopMode
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        )
                      ]
                    : null,
          ),
          child: GestureDetector(
            onDoubleTap: widget.isDesktopMode
                ? () => widget.onNavigate(widget.folder.path)
                : null,
            child: Theme(
              // Apply no splash theme
              data: Theme.of(context).copyWith(
                splashFactory: NoSplashFactory(),
                highlightColor: Colors.transparent,
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: FolderThumbnail(
                      folder: widget.folder,
                      size: 40,
                    ),
                  ),
                  title: Text(
                    widget.folder.basename(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight:
                          _visuallySelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  subtitle: FutureBuilder<FileStat>(
                    future: widget.folder.stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          '${snapshot.data!.modified.toString().split('.')[0]}',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[800]),
                        );
                      }
                      return Text('Loading...',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[700]));
                    },
                  ),
                  onTap: () {
                    if (widget.isDesktopMode &&
                        widget.toggleFolderSelection != null) {
                      // On desktop, use keyboard modifiers for selection
                      _handleFolderSelection();
                    } else {
                      // Navigate to folder
                      widget.onNavigate(widget.folder.path);
                    }
                  },
                  onLongPress: () => _showFolderContextMenu(context),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'properties') {
                        _showFolderContextMenu(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'properties',
                        child: Row(
                          children: [
                            Icon(Icons.settings),
                            SizedBox(width: 8),
                            Text('Folder Properties'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onNavigate,
    );
  }
}

/// Widget for displaying folder thumbnail
class FolderThumbnail extends StatefulWidget {
  final Directory folder;
  final double size;

  const FolderThumbnail({
    Key? key,
    required this.folder,
    this.size = 80,
  }) : super(key: key);

  @override
  State<FolderThumbnail> createState() => _FolderThumbnailState();
}

class _FolderThumbnailState extends State<FolderThumbnail> {
  final FolderThumbnailService _thumbnailService = FolderThumbnailService();
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(FolderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder.path != widget.folder.path) {
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (_disposed) return;

    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final path =
          await _thumbnailService.getFolderThumbnail(widget.folder.path);

      if (_disposed) return;

      setState(() {
        _thumbnailPath = path;
        _isLoading = false;
      });

      debugPrint('Loaded thumbnail for folder: ${widget.folder.path}');
      debugPrint('Thumbnail path: ${_thumbnailPath ?? "null"}');
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (!_disposed) {
        setState(() {
          _thumbnailPath = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  bool _isVideoPath(String? path) {
    if (path == null) return false;
    return path.startsWith("video::");
  }

  String _getVideoPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[1];
    }
    return path.substring(7);
  }

  String _getThumbnailPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[2];
    }
    return path.substring(7);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: widget.size * 0.5,
          height: widget.size * 0.5,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Default folder icon when no thumbnail
    if (_thumbnailPath == null || _loadFailed) {
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }

    final bool isVideo = _isVideoPath(_thumbnailPath);
    final String videoPath = _getVideoPath(_thumbnailPath!);
    final String thumbnailPath = _getThumbnailPath(_thumbnailPath!);

    try {
      if (isVideo) {
        if (!File(videoPath).existsSync()) {
          debugPrint('Video file does not exist: $videoPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          // Use AspectRatio to maintain proper video aspect ratio
          child: Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9, // Standard video aspect ratio
                child: LazyVideoThumbnail(
                  videoPath: videoPath,
                  width: double.infinity,
                  height: double.infinity,
                  keepAlive: true,
                  fallbackBuilder: () => Container(
                    color: Colors.blueGrey[900],
                    child: Center(
                      child: Icon(
                        EvaIcons.videoOutline,
                        size: widget.size * 0.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: widget.size * 0.25 < 16 ? widget.size * 0.25 : 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final file = File(thumbnailPath);
        if (!file.existsSync()) {
          debugPrint('Image file does not exist: $thumbnailPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1, // Square aspect ratio for images
            child: Image.file(
              file,
              fit: BoxFit.contain, // Use contain to respect aspect ratio
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image loading error: $error');
                return Center(
                  child: Icon(
                    EvaIcons.folderOutline,
                    size: widget.size * 0.7,
                    color: Colors.amber[700],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating image widget: $e');
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }
  }
}

// Helper function to determine if we're on desktop
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

// Class to disable splash effect
class NoSplashFactory extends InteractiveInkFeatureFactory {
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _NoSplash(
      controller: controller,
      referenceBox: referenceBox,
    );
  }
}

class _NoSplash extends InteractiveInkFeature {
  _NoSplash({
    required MaterialInkController controller,
    required RenderBox referenceBox,
  }) : super(
          controller: controller,
          referenceBox: referenceBox,
          color: Colors.transparent,
        );

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    // No painting
  }
}
