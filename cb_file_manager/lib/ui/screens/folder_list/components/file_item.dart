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
import 'package:cb_file_manager/ui/components/optimized_interaction_handler.dart';

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
  // Use ValueNotifier for state management
  final ValueNotifier<bool> _isHoveringNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSelectedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _fileTags = widget.state.getTagsForFile(widget.file.path);
    // Đăng ký lắng nghe thay đổi tag
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagChanged);
    _isSelectedNotifier.value = widget.isSelected;
  }

  @override
  void dispose() {
    // Hủy đăng ký lắng nghe khi widget bị hủy
    _tagChangeSubscription?.cancel();
    _isHoveringNotifier.dispose();
    _isSelectedNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selection state if it changed externally
    if (widget.isSelected != oldWidget.isSelected) {
      _isSelectedNotifier.value = widget.isSelected;
    }

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
    debugPrint(
        "FileItem: received tag change notification: $changedFilePath for file: ${widget.file.path}");

    // Check for global notifications first
    if (changedFilePath == "global:tag_updated" ||
        changedFilePath == "global:tag_deleted") {
      _updateTagsIfChanged();
      return;
    }

    // Extract the actual file path if it has a prefix
    String actualPath = changedFilePath;
    bool isTagOnlyEvent = false;

    if (changedFilePath.startsWith("preserve_scroll:")) {
      actualPath = changedFilePath.substring("preserve_scroll:".length);
    } else if (changedFilePath.startsWith("tag_only:")) {
      isTagOnlyEvent = true;
      actualPath = changedFilePath.substring("tag_only:".length);
    }

    if (actualPath == widget.file.path) {
      if (!isTagOnlyEvent) {
        TagManager.clearCache();
      }
      _updateTagsIfChanged();
    }
  }

  void _updateTagsIfChanged() {
    final newTags = widget.state.getTagsForFile(widget.file.path);
    debugPrint(
        "FileItem: comparing tags for ${widget.file.path}: old=$_fileTags, new=$newTags");
    if (mounted && !_areTagListsEqual(newTags, _fileTags)) {
      debugPrint("FileItem: updating tags for ${widget.file.path}");
      setState(() {
        _fileTags = newTags;
      });
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

        // Clear cache to ensure fresh data
        TagManager.clearCache();

        // Send multiple notifications to ensure all components update
        TagManager.instance.notifyTagChanged("tag_only:${widget.file.path}");
        TagManager.instance.notifyTagChanged(widget.file.path);
        TagManager.instance.notifyTagChanged("global:tag_updated");

        // Update via bloc if available
        try {
          final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
          bloc.add(RemoveTagFromFile(widget.file.path, tag));
        } catch (e) {
          debugPrint('FolderListBloc not available in this context: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag "$tag" đã được xóa'),
            duration: const Duration(seconds: 2),
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

    // Use ValueListenableBuilder for hover and selection state to avoid full rebuilds
    return ValueListenableBuilder<bool>(
      valueListenable: _isHoveringNotifier,
      builder: (context, isHovering, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isSelectedNotifier,
          builder: (context, isSelected, _) {
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
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // File content that doesn't need to rebuild on selection changes
                        RepaintBoundary(
                          key: ValueKey('content_${widget.file.path}'),
                          child: _FileItemContent(
                            file: widget.file,
                            fileTags: _fileTags,
                            state: widget.state,
                            showDeleteTagDialog: widget.showDeleteTagDialog,
                            showAddTagToFileDialog:
                                widget.showAddTagToFileDialog,
                            removeTagDirectly: _removeTagDirectly,
                          ),
                        ),
                        // Interactive layer
                        Positioned.fill(
                          child: OptimizedInteractionLayer(
                            onTap: () {
                              if (widget.isSelectionMode ||
                                  widget.isDesktopMode) {
                                _handleSelection();
                              } else {
                                _openFile(isVideo, isImage);
                              }
                            },
                            onDoubleTap: () {
                              _openFile(isVideo, isImage);
                            },
                            onLongPress: () {
                              if (!widget.isSelectionMode) {
                                widget.toggleFileSelection(widget.file.path,
                                    shiftSelect: false, ctrlSelect: false);
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
      },
    );
  }
}

// Content widget that doesn't change with selection
class _FileItemContent extends StatefulWidget {
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
  State<_FileItemContent> createState() => _FileItemContentState();
}

class _FileItemContentState extends State<_FileItemContent> {
  late Future<Widget> _iconFuture;
  late Future<FileStat> _fileStatFuture;

  @override
  void initState() {
    super.initState();
    _iconFuture = FileIconHelper.getIconForFile(widget.file);
    _fileStatFuture = widget.file.stat();
  }

  @override
  void didUpdateWidget(_FileItemContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file.path != oldWidget.file.path) {
      _iconFuture = FileIconHelper.getIconForFile(widget.file);
      _fileStatFuture = widget.file.stat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.file.path.split('.').last.toLowerCase();
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
                  widget.file.path.split(Platform.pathSeparator).last,
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
        child: isVideo || isImage
            ? isVideo
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ThumbnailLoader(
                      filePath: widget.file.path,
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
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ThumbnailLoader(
                      filePath: widget.file.path,
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
                  )
            : OptimizedFileIcon(
                file: widget.file,
                size: 48,
                fallbackIcon: EvaIcons.fileOutline,
                fallbackColor: Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
      ),
    );
  }

  Widget _buildFileDetails(BuildContext context) {
    // Calculate approximate available width for tags
    // File size text ~100px, icon button ~48px, spacing ~32px, bookmark icon ~20px
    final screenWidth = MediaQuery.of(context).size.width;
    final approximateAvailableWidth =
        screenWidth * 0.6 - 200; // Conservative estimate

    // Estimate tag chip width: each character ~8px + padding ~20px
    int estimatedTagsToShow = 0;
    int totalTagWidth = 0;
    final List<String> tagsToShow = [];

    // Sort tags by length to prioritize shorter tags that fit better
    final sortedTags = List<String>.from(widget.fileTags)
      ..sort((a, b) => a.length.compareTo(b.length));

    // Determine how many tags can fit
    for (final tag in sortedTags) {
      final estimatedWidth =
          tag.length * 8 + 40; // Character width + padding and icon
      if (totalTagWidth + estimatedWidth <= approximateAvailableWidth) {
        totalTagWidth += estimatedWidth;
        tagsToShow.add(tag);
        estimatedTagsToShow++;
      } else {
        break;
      }
    }

    // Limit to max 3 tags for aesthetics
    if (tagsToShow.length > 3) {
      tagsToShow.length = 3;
    }

    return Row(
      children: [
        FutureBuilder<FileStat>(
          future: _fileStatFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final size = snapshot.data!.size;
              return Text(FileUtils.formatFileSize(size),
                  style: Theme.of(context).textTheme.bodySmall);
            }
            return Text('Loading...',
                style: Theme.of(context).textTheme.bodySmall);
          },
        ),
        if (widget.fileTags.isNotEmpty) ...[
          const SizedBox(width: 16),
          const Icon(EvaIcons.bookmarkOutline,
              size: 14, color: AppTheme.primaryBlue),
          const SizedBox(width: 4),
          if (tagsToShow.isEmpty)
            // If no tags fit, show count
            Text(
              '${widget.fileTags.length} tags',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryBlue,
              ),
            )
          else if (tagsToShow.length == widget.fileTags.length)
            // All tags fit, show them
            Flexible(
              child: Wrap(
                spacing: 4,
                children: tagsToShow
                    .map((tag) => TagChip(
                          tag: tag,
                          isCompact: true,
                          onTap: () {
                            final bloc = BlocProvider.of<FolderListBloc>(
                                context,
                                listen: false);
                            bloc.add(SearchByTag(tag));
                          },
                          onDeleted: () => widget.removeTagDirectly(tag),
                        ))
                    .toList(),
              ),
            )
          else
            // Some tags fit, show them + count of remaining
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...tagsToShow.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TagChip(
                          tag: tag,
                          isCompact: true,
                          onTap: () {
                            final bloc = BlocProvider.of<FolderListBloc>(
                                context,
                                listen: false);
                            bloc.add(SearchByTag(tag));
                          },
                          onDeleted: () => widget.removeTagDirectly(tag),
                        ),
                      )),
                  Text(
                    '+${widget.fileTags.length - tagsToShow.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
