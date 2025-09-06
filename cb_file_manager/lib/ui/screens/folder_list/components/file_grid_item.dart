import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../components/common/shared_file_context_menu.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

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

  void _showContextMenu(BuildContext context) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(file.path);

    return Column(
      children: [
        // Thumbnail section
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The content that does NOT change on selection
              ThumbnailLoader(
                filePath: file.path,
                isVideo: FileTypeUtils.isVideoFile(file.path),
                isImage: FileTypeUtils.isImageFile(file.path),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                onThumbnailLoaded: onThumbnailGenerated,
              ),

              // The content that DOES change on selection
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      final isShiftPressed =
                          RawKeyboard.instance.keysPressed.contains(
                                LogicalKeyboardKey.shiftLeft,
                              ) ||
                              RawKeyboard.instance.keysPressed.contains(
                                LogicalKeyboardKey.shiftRight,
                              );
                      final isCtrlPressed =
                          RawKeyboard.instance.keysPressed.contains(
                                LogicalKeyboardKey.controlLeft,
                              ) ||
                              RawKeyboard.instance.keysPressed.contains(
                                LogicalKeyboardKey.controlRight,
                              );

                      // If in selection mode or modifier keys pressed, handle selection
                      if (isSelectionMode || isShiftPressed || isCtrlPressed) {
                        toggleFileSelection(
                          file.path,
                          shiftSelect: isShiftPressed,
                          ctrlSelect: isCtrlPressed,
                        );
                      } else {
                        // Single tap opens file when not in selection mode
                        onFileTap?.call(file as File, false);
                      }
                    },
                    onLongPress: toggleSelectionMode,
                    onDoubleTap: () => onFileTap?.call(file as File, false),
                    onSecondaryTap: () => _showContextMenu(context),
                    child: isSelected
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.2),
                            ),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  EvaIcons.checkmarkCircle2,
                                  color: Theme.of(context).primaryColor,
                                  size: 24,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
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
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 0.5,
                ),
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
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 0.5,
              ),
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
