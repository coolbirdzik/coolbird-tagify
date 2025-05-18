import 'dart:io';
import 'dart:async'; // Thêm import cho StreamSubscription
// For lerpDouble
// For more responsive animations

import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart'; // Import TagManager để lắng nghe thay đổi
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/file_icon_helper.dart';
// Import app theme
import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart'; // Import the new TagChip widget
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart'; // Import ThumbnailLoader
import 'package:flutter/services.dart'; // Import for keyboard key detection
// Import for RepaintBoundary

// Add this class to disable ripple effects
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
    // No painting needed
  }
}

class FileItem extends StatefulWidget {
  final File file;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(File, bool)? onFileTap;
  final bool isDesktopMode;
  final String?
      lastSelectedPath; // Add parameter to track last selected file for shift-selection

  const FileItem({
    Key? key,
    required this.file,
    required this.state,
    required this.isSelectionMode,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.onFileTap,
    this.isDesktopMode = false,
    this.lastSelectedPath,
  }) : super(key: key);

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  late List<String> _fileTags;
  StreamSubscription? _tagChangeSubscription;
  // Use ValueNotifier for hover state
  final ValueNotifier<bool> _isHoveringNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);
    // Đăng ký lắng nghe thay đổi tag
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
  }

  @override
  void dispose() {
    // Hủy đăng ký lắng nghe khi widget bị hủy
    _tagChangeSubscription?.cancel();
    _isHoveringNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Visual selection updates are driven by widget.isSelected via ValueListenableBuilder in parent

    // Update tags if they've changed
    final newTags = widget.state.getTagsForFile(widget.file.path);
    if (!_areTagListsEqual(newTags, _fileTags)) {
      if (mounted) {
        setState(() {
          _fileTags = newTags;
        });
      }
    }
  }

  // Xử lý sự kiện thay đổi tag
  void _onTagChanged(String changedFilePath) {
    bool isTagOnlyEvent = false;
    String actualPath = changedFilePath;

    if (changedFilePath.startsWith("tag_only:")) {
      isTagOnlyEvent = true;
      actualPath = changedFilePath.substring("tag_only:".length);
    }

    if (actualPath == widget.file.path ||
        changedFilePath == "global:tag_deleted") {
      if (!isTagOnlyEvent) {
        TagManager.clearCache();
      }
      final newTags = widget.state.getTagsForFile(widget.file.path);
      if (!_areTagListsEqual(newTags, _fileTags)) {
        if (mounted) {
          setState(() {
            _fileTags = newTags;
          });
        }
      }
    }
  }

  bool _areTagListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    list1.sort();
    list2.sort();
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _removeTagDirectly(String tag) async {
    try {
      await TagManager.removeTag(widget.file.path, tag);
      if (mounted) {
        setState(() {
          _fileTags.remove(tag);
        });
        TagManager.instance.notifyTagChanged("tag_only:${widget.file.path}");
        final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
        bloc.add(RemoveTagFromFile(widget.file.path, tag));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "$tag" đã được xóa'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa tag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openFile(bool isVideo, bool isImage) {
    if (widget.onFileTap != null) {
      widget.onFileTap!(widget.file, isVideo);
    } else {
      // Open directly using default apps
      if (isVideo) {
        if (!context.mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    VideoPlayerFullScreen(file: widget.file)));
      } else if (isImage) {
        if (!context.mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ImageViewerScreen(file: widget.file)));
      } else {
        ExternalAppHelper.openFileWithApp(widget.file.path, 'shell_open')
            .then((success) {
          if (!success && context.mounted) {
            showDialog(
                context: context,
                builder: (context) =>
                    OpenWithDialog(filePath: widget.file.path));
          }
        });
      }
    }
  }

  void _handleSelection() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    widget.toggleFileSelection(widget.file.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  void _showContextMenu(BuildContext context) {
    final extension = widget.file.path.split('.').last.toLowerCase();
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(extension);
    final bool isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

    showFileContextMenu(
      context: context,
      file: widget.file,
      fileTags: _fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: widget.showAddTagToFileDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.file.path.split('.').last.toLowerCase();
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(extension);
    final bool isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

    // Use ValueListenableBuilder for hover state to avoid full rebuilds
    return ValueListenableBuilder<bool>(
      valueListenable: _isHoveringNotifier,
      builder: (context, isHovering, _) {
        final bool isSelected = widget.isSelected;

        // Calculate colors based on selection and hover state
        final Color backgroundColor = isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : isHovering && widget.isDesktopMode
                ? Theme.of(context).colorScheme.surface.withOpacity(0.6)
                : Colors.transparent;

        return RepaintBoundary(
          child: GestureDetector(
            onSecondaryTap: () => _showContextMenu(context),
            onLongPress: () {
              if (!widget.isSelectionMode) {
                widget.toggleFileSelection(widget.file.path,
                    shiftSelect: false, ctrlSelect: false);
              }
            },
            child: MouseRegion(
              onEnter: (_) => _isHoveringNotifier.value = true,
              onExit: (_) => _isHoveringNotifier.value = false,
              cursor: SystemMouseCursors.click,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // File content that doesn't need to rebuild on selection changes
                    RepaintBoundary(
                      child: _FileItemContent(
                        file: widget.file,
                        fileTags: _fileTags,
                        state: widget.state,
                        showDeleteTagDialog: widget.showDeleteTagDialog,
                        showAddTagToFileDialog: widget.showAddTagToFileDialog,
                        removeTagDirectly: _removeTagDirectly,
                      ),
                    ),
                    // Interactive layer
                    Positioned.fill(
                      child: _FileInteractionLayer(
                        onTap: () {
                          if (widget.isSelectionMode || widget.isDesktopMode) {
                            _handleSelection();
                          } else {
                            _openFile(isVideo, isImage);
                          }
                        },
                        onDoubleTap: () {
                          if (widget.isDesktopMode && !widget.isSelectionMode) {
                            _openFile(isVideo, isImage);
                          }
                        },
                      ),
                    ),
                    // Selection indicator - only rebuilds when selection changes
                    if (isSelected)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Separate interaction layer to handle gestures without requiring content rerender
class _FileInteractionLayer extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _FileInteractionLayer({
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
    );
  }
}

// Content widget that doesn't change with selection
class _FileItemContent extends StatelessWidget {
  final File file;
  final List<String> fileTags;
  final FolderListState state;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(String) removeTagDirectly;

  const _FileItemContent({
    required this.file,
    required this.fileTags,
    required this.state,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    required this.removeTagDirectly,
  });

  @override
  Widget build(BuildContext context) {
    final extension = file.path.split('.').last.toLowerCase();
    final bool isVideo =
        ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(extension);
    final bool isImage =
        ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          _buildThumbnail(isVideo, isImage),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.path.split(Platform.pathSeparator).last,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                _buildFileDetails(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(bool isVideo, bool isImage) {
    return RepaintBoundary(
      child: SizedBox(
        width: 48,
        height: 48,
        child: FutureBuilder<Widget>(
          future: FileIconHelper.getIconForFile(file),
          builder: (context, snapshot) {
            if (isVideo) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ThumbnailLoader(
                  filePath: file.path,
                  isVideo: true,
                  isImage: false,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                  fallbackBuilder: () => const Icon(
                    EvaIcons.videoOutline,
                    size: 36,
                    color: Colors.red,
                  ),
                ),
              );
            } else if (isImage) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ThumbnailLoader(
                  filePath: file.path,
                  isVideo: false,
                  isImage: true,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                  fallbackBuilder: () => const Icon(
                    EvaIcons.imageOutline,
                    size: 36,
                    color: Colors.blue,
                  ),
                ),
              );
            } else if (snapshot.hasData) {
              return snapshot.data!;
            } else {
              // Returns a placeholder while the future is loading
              return const Icon(
                EvaIcons.fileOutline,
                size: 36,
                color: Colors.grey,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFileDetails(BuildContext context) {
    return Row(
      children: [
        FutureBuilder<FileStat>(
          future: file.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final size = snapshot.data!.size;
              String sizeStr;
              if (size < 1024) {
                sizeStr = '$size B';
              } else if (size < 1024 * 1024) {
                sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
              } else if (size < 1024 * 1024 * 1024) {
                sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
              } else {
                sizeStr =
                    '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
              }
              return Text(sizeStr,
                  style: Theme.of(context).textTheme.bodySmall);
            }
            return Text('Loading...',
                style: Theme.of(context).textTheme.bodySmall);
          },
        ),
        if (fileTags.isNotEmpty) ...[
          const SizedBox(width: 16),
          const Icon(EvaIcons.bookmarkOutline,
              size: 14, color: AppTheme.primaryBlue),
          const SizedBox(width: 4),
          if (fileTags.length == 1)
            TagChip(
              tag: fileTags.first,
              isCompact: true,
              onTap: () {
                final bloc =
                    BlocProvider.of<FolderListBloc>(context, listen: false);
                bloc.add(SearchByTag(fileTags.first));
              },
              onDeleted: () => removeTagDirectly(fileTags.first),
            )
          else
            Text(
              '${fileTags.length} tags',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryBlue,
              ),
            ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(EvaIcons.moreHorizontal),
          iconSize: 20,
          onPressed: () => showDeleteTagDialog(context, file.path, fileTags),
          tooltip: 'More options',
        ),
      ],
    );
  }
}
