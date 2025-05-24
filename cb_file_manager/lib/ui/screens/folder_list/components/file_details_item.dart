import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:cb_file_manager/helpers/file_type_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
import 'package:cb_file_manager/ui/widgets/lazy_video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:cb_file_manager/ui/components/optimized_interaction_handler.dart';

class FileDetailsItem extends StatefulWidget {
  final File file;
  final Function(File, bool)? onTap;
  final bool isSelected;
  final ColumnVisibility columnVisibility;
  final FolderListState state;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final bool isDesktopMode;
  final String? lastSelectedPath;

  const FileDetailsItem({
    Key? key,
    required this.file,
    required this.onTap,
    required this.isSelected,
    required this.columnVisibility,
    required this.state,
    required this.toggleFileSelection,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FileDetailsItem> createState() => _FileDetailsItemState();
}

class _FileDetailsItemState extends State<FileDetailsItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;
  FileStat? _fileStat;
  late bool isImage;
  late bool isVideo;
  // Create a key based on the file path to prevent thumbnail recreation
  late final ValueKey<String> _thumbnailKey;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
    _loadFileStats();
    _checkFileType();
    _thumbnailKey = ValueKey('thumbnail-${widget.file.path}');
  }

  @override
  void didUpdateWidget(FileDetailsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      setState(() {
        _visuallySelected = widget.isSelected;
      });
    }

    if (widget.file.path != oldWidget.file.path) {
      _loadFileStats();
      _checkFileType();
      // We don't need to update the thumbnail key here since file path changed
      // and we'll get a new widget instance anyway
    }
  }

  Future<void> _loadFileStats() async {
    try {
      final stat = await widget.file.stat();
      if (mounted) {
        setState(() {
          _fileStat = stat;
        });
      }
    } catch (e) {
      debugPrint('Error loading file stats: $e');
    }
  }

  void _checkFileType() {
    final String extension = path.extension(widget.file.path).toLowerCase();
    isImage = FileTypeHelper.isImage(extension);
    isVideo = FileTypeHelper.isVideo(extension);
  }

  void _handleFileSelection() {
    // Check for Shift and Ctrl keys
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    // Log selection attempt
    debugPrint("File selection: ${widget.file.path}");
    debugPrint("Shift: $isShiftPressed, Ctrl: $isCtrlPressed");

    // Visual update for immediate feedback
    if (!isShiftPressed) {
      setState(() {
        if (!isCtrlPressed) {
          // Single selection without Ctrl: this item will be selected
          _visuallySelected = true;
        } else {
          // Ctrl+click: toggle this item's selection
          _visuallySelected = !_visuallySelected;
        }
      });
    }

    // Call toggleFileSelection with appropriate parameters
    widget.toggleFileSelection(
      widget.file.path,
      shiftSelect: isShiftPressed,
      ctrlSelect: isCtrlPressed,
    );
  }

  void _showFileContextMenu(BuildContext context) {
    showFileContextMenu(
      context: context,
      file: widget.file,
      fileTags: widget.state.fileTags[widget.file.path] ?? [],
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: widget.showAddTagToFileDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate colors based on selection state
    final Color itemBackgroundColor = _visuallySelected
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
        : _isHovering && widget.isDesktopMode
            ? isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[100]!
            : Colors.transparent;

    final BoxDecoration boxDecoration = BoxDecoration(
      color: itemBackgroundColor,
    );

    // Get the file extension and icon
    final String fileExtension = path.extension(widget.file.path).toLowerCase();
    final FileType fileType = FileTypeHelper.getFileType(fileExtension);
    final IconData fileIcon = FileTypeHelper.getIconForFileType(fileType);
    final Color iconColor = FileTypeHelper.getColorForFileType(fileType);

    return GestureDetector(
      onSecondaryTap: () => _showFileContextMenu(context),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: Stack(
          children: [
            Container(
              decoration: boxDecoration,
              child: Row(
                children: [
                  // Name column (always visible)
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      child: Row(
                        children: [
                          // Use a dedicated widget for file icon with a key to prevent rebuilds
                          _OptimizedFileIcon(
                            key: _thumbnailKey,
                            file: widget.file,
                            isVideo: isVideo,
                            isImage: isImage,
                            icon: fileIcon,
                            color: iconColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              path.basename(widget.file.path),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: _visuallySelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),

                          // Show file tags if available
                          if (widget.state.fileTags[widget.file.path]
                                  ?.isNotEmpty ??
                              false)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(
                                EvaIcons.bookmarkOutline,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Type column
                  if (widget.columnVisibility.type)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        child: Text(
                          _getFileTypeLabel(fileExtension),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // Size column
                  if (widget.columnVisibility.size)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        child: Text(
                          _fileStat != null
                              ? _formatFileSize(_fileStat!.size)
                              : 'Loading...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // Date modified column
                  if (widget.columnVisibility.dateModified)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        child: Text(
                          _fileStat != null
                              ? _fileStat!.modified.toString().split('.')[0]
                              : 'Loading...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // Date created column
                  if (widget.columnVisibility.dateCreated)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        child: Text(
                          _fileStat != null
                              ? _fileStat!.changed.toString().split('.')[0]
                              : 'Loading...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // Attributes column
                  if (widget.columnVisibility.attributes)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        child: Text(
                          _getAttributes(_fileStat),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Add optimized interaction layer on top
            Positioned.fill(
              child: OptimizedInteractionLayer(
                onTap: () {
                  if (widget.isDesktopMode) {
                    _handleFileSelection();
                  } else if (widget.onTap != null) {
                    widget.onTap!(widget.file, false);
                  }
                },
                onDoubleTap: () {
                  if (widget.onTap != null) {
                    widget.onTap!(widget.file, true);
                  }
                },
                onLongPress: () {
                  if (!_visuallySelected) {
                    _handleFileSelection();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileTypeLabel(String extension) {
    if (extension.isEmpty) return 'Tệp tin';

    // Remove the dot
    extension = extension.substring(1).toUpperCase();

    switch (extension) {
      case 'JPG':
      case 'JPEG':
        return 'Ảnh JPEG';
      case 'PNG':
        return 'Ảnh PNG';
      case 'GIF':
        return 'Ảnh GIF';
      case 'MP4':
        return 'Video MP4';
      case 'AVI':
        return 'Video AVI';
      case 'MP3':
        return 'Âm thanh MP3';
      case 'WAV':
        return 'Âm thanh WAV';
      case 'PDF':
        return 'Tài liệu PDF';
      case 'DOCX':
      case 'DOC':
        return 'Tài liệu Word';
      case 'XLSX':
      case 'XLS':
        return 'Bảng tính Excel';
      case 'PPTX':
      case 'PPT':
        return 'Bài thuyết trình PowerPoint';
      case 'TXT':
        return 'Tệp văn bản';
      default:
        return 'Tệp $extension';
    }
  }

  String _formatFileSize(int size) {
    return FileUtils.formatFileSize(size);
  }

  String _getAttributes(FileStat? stat) {
    if (stat == null) return '';

    final List<String> attrs = [];

    if (stat.modeString()[0] == 'd') attrs.add('D');
    if (stat.modeString()[1] == 'r') attrs.add('R');
    if (stat.modeString()[2] == 'w') attrs.add('W');
    if (stat.modeString()[3] == 'x') attrs.add('X');

    return attrs.join(' ');
  }
}

// Replace the _FileInteractionLayer class (remove it)
// Remove entire _FileInteractionLayer class and its state class

// Replace the _OptimizedFileIcon class with this:
class _OptimizedFileIcon extends StatefulWidget {
  final File file;
  final bool isVideo;
  final bool isImage;
  final IconData icon;
  final Color? color;

  const _OptimizedFileIcon({
    Key? key,
    required this.file,
    required this.isVideo,
    required this.isImage,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  State<_OptimizedFileIcon> createState() => _OptimizedFileIconState();
}

class _OptimizedFileIconState extends State<_OptimizedFileIcon>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return OptimizedFileIcon(
      file: widget.file,
      isVideo: widget.isVideo,
      isImage: widget.isImage,
      size: 24,
      fallbackIcon: widget.icon,
      fallbackColor: widget.color,
      borderRadius: BorderRadius.circular(2),
    );
  }
}
