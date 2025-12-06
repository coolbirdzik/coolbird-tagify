import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../components/common/shared_file_context_menu.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import 'thumbnail_only.dart';

class FileGridItem extends StatelessWidget {
  final FileSystemEntity file;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})
      toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(File, bool)? onFileTap;
  // Optional parameters for backward compatibility with previous API and other widgets
  final FolderListState? state;
  final bool isSelectionMode;
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final Function()? onThumbnailGenerated;
  // Context menu parameters
  final Function(BuildContext, String, List<String>)? showDeleteTagDialog;
  final Function(BuildContext, String)? showAddTagToFileDialog;
  final bool showFileTags; // Add parameter to control tag display

  const FileGridItem({
    Key? key,
    required this.file,
    required this.isSelected,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    this.onFileTap,
    this.state,
    this.isSelectionMode = false,
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.onThumbnailGenerated,
    this.showDeleteTagDialog,
    this.showAddTagToFileDialog,
    this.showFileTags = true, // Default to showing tags
  }) : super(key: key);

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final bool isVideo = FileTypeUtils.isVideoFile(file.path);
    final bool isImage = FileTypeUtils.isImageFile(file.path);

    // Get file tags from state if available
    final List<String> fileTags = state?.getTagsForFile(file.path) ?? [];

    showFileContextMenu(
      context: context,
      file: file as File,
      fileTags: fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: showAddTagToFileDialog,
      globalPosition: globalPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(file.path);

    return RepaintBoundary(
      child: Column(
        children: [
          // Thumbnail section (flat: no border, just radius + spacing)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Use ThumbnailOnly to prevent rebuilds when selection changes
                  ThumbnailOnly(
                    key: ValueKey('thumb-only-${file.path}'),
                    file: file,
                    iconSize: 48.0,
                  ),

                  // Selection overlay with tap handling
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () {
                          final bool isShiftPressed = HardwareKeyboard
                                  .instance.logicalKeysPressed
                                  .contains(
                                LogicalKeyboardKey.shiftLeft,
                              ) ||
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(
                                LogicalKeyboardKey.shiftRight,
                              );
                          final bool isCtrlPressed = HardwareKeyboard
                                  .instance.logicalKeysPressed
                                  .contains(
                                LogicalKeyboardKey.controlLeft,
                              ) ||
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(
                                LogicalKeyboardKey.controlRight,
                              );
                          final bool isVideo =
                              FileTypeUtils.isVideoFile(file.path);

                          // If in selection mode or modifier keys pressed, handle selection
                          if (isSelectionMode ||
                              isShiftPressed ||
                              isCtrlPressed) {
                            toggleFileSelection(
                              file.path,
                              shiftSelect: isShiftPressed,
                              ctrlSelect: isCtrlPressed,
                            );
                          } else if (isDesktopMode && isVideo) {
                            toggleFileSelection(file.path,
                                shiftSelect: false, ctrlSelect: false);
                          } else {
                            // Single tap opens file when not in selection mode
                            onFileTap?.call(file as File, isVideo);
                          }
                        },
                        onDoubleTap: () {
                          onFileTap?.call(file as File,
                              FileTypeUtils.isVideoFile(file.path));
                        },
                        onSecondaryTapDown: (details) {
                          _showContextMenu(context, details.globalPosition);
                        },
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          toggleFileSelection(file.path);
                          if (!isSelectionMode) {
                            toggleSelectionMode();
                          }
                        },
                      ),
                    ),
                  ),

                  // Selection indicator overlay - only show when selected
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.2),
                      ),
                      child: isDesktopMode
                          ? null
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  remix.Remix.checkbox_circle_line,
                                  color: Theme.of(context).primaryColor,
                                  size: 24,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),

          // File name section
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
            child: Column(
              children: [
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Show tags if enabled and available
                if (showFileTags && state != null) ...[
                  const SizedBox(height: 2),
                  _buildTagsDisplay(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsDisplay(BuildContext context) {
    if (state == null) return const SizedBox.shrink();

    final List<String> fileTags = state!.getTagsForFile(file.path);
    if (fileTags.isEmpty) return const SizedBox.shrink();

    // Show only first 2 tags in grid view to save space
    final tagsToShow = fileTags.take(2).toList();
    final hasMoreTags = fileTags.length > 2;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        ...tagsToShow.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
        if (hasMoreTags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${fileTags.length - 2}',
              style: TextStyle(
                fontSize: 8,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
