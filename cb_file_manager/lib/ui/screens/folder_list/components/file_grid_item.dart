import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/helpers/files/external_app_helper.dart';
import 'package:cb_file_manager/helpers/tags/tag_color_manager.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/ui/components/optimized_interaction_handler.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/ui/screens/folder_list/components/thumbnail_content.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/helpers/files/file_type_helper.dart';
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
  }) : super(key: key);

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
                      final isCtrlPressed = RawKeyboard.instance.keysPressed.contains(
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
                    child: isSelected
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                              color: Theme.of(context).primaryColor.withOpacity(0.2),
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
          child: Text(
            fileName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
