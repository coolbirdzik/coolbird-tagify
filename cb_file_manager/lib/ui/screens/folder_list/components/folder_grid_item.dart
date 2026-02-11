import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/ui/controllers/inline_rename_controller.dart';
import 'package:cb_file_manager/ui/widgets/inline_rename_field.dart';
import '../../../components/common/shared_file_context_menu.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../bloc/selection/selection_bloc.dart';
import '../../../../bloc/selection/selection_event.dart';
import 'folder_thumbnail.dart';
import '../../../components/common/optimized_interaction_handler.dart';
import '../../../utils/item_interaction_style.dart';

class FolderGridItem extends StatefulWidget {
  final Directory folder;
  final Function(String) onNavigate;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final Function()? clearSelectionMode;

  const FolderGridItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.clearSelectionMode,
  }) : super(key: key);

  @override
  State<FolderGridItem> createState() => _FolderGridItemState();
}

class _FolderGridItemState extends State<FolderGridItem> {
  bool _isHovering = false;
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
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

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

    // Call the selection handler with the appropriate modifiers
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: isCtrlPressed);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isBeingCut = ItemInteractionStyle.isBeingCut(widget.folder.path);

    // Colors for item background and thumbnail overlay (used by both mobile & desktop)
    final Color backgroundColor = ItemInteractionStyle.backgroundColor(
      theme: Theme.of(context),
      isDesktopMode: widget.isDesktopMode,
      isSelected: _visuallySelected,
      isHovering: _isHovering,
    );

    final Color thumbnailOverlayColor =
        ItemInteractionStyle.thumbnailOverlayColor(
      theme: Theme.of(context),
      isDesktopMode: widget.isDesktopMode,
      isSelected: _visuallySelected,
      isHovering: _isHovering,
    );

    // Flat layout for mobile without a label background.
    if (!widget.isDesktopMode) {
      return Opacity(
        opacity: isBeingCut ? ItemInteractionStyle.cutOpacity : 1.0,
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              _showFolderContextMenu(context, details.globalPosition),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compactCard =
                  constraints.maxHeight < 96 || constraints.maxWidth < 96;
              final double textHeight = compactCard ? 30.0 : 40.0;
              final double thumbPadding = compactCard ? 3.0 : 6.0;
              final double thumbRadius = compactCard ? 6.0 : 8.0;
              final double cardRadius = compactCard ? 5.0 : 6.0;
              final double fontSize = compactCard ? 10.5 : 12.0;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Thumbnail/Icon section — framed thumbnail + badge (mobile)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(thumbPadding),
                              child: LayoutBuilder(
                                builder: (context, thumbConstraints) {
                                  final double shortEdge = math.min(
                                    thumbConstraints.maxWidth,
                                    thumbConstraints.maxHeight,
                                  );
                                  final bool showBadge = shortEdge >= 34.0;
                                  final bool tinyThumb = shortEdge < 56.0;
                                  final double badgeInset =
                                      tinyThumb ? 2.0 : 6.0;
                                  final double badgePadding =
                                      tinyThumb ? 2.0 : 4.0;
                                  final double badgeRadius =
                                      tinyThumb ? 4.0 : 6.0;
                                  final double badgeIconSize =
                                      tinyThumb ? 10.0 : 14.0;

                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              thumbRadius),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.12),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              thumbRadius),
                                          child: FolderThumbnail(
                                              folder: widget.folder),
                                        ),
                                      ),
                                      if (thumbnailOverlayColor !=
                                          Colors.transparent)
                                        IgnorePointer(
                                          child: Container(
                                              color: thumbnailOverlayColor),
                                        ),
                                      if (showBadge)
                                        Positioned(
                                          top: badgeInset,
                                          left: badgeInset,
                                          child: Container(
                                            padding:
                                                EdgeInsets.all(badgePadding),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: 0.9),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      badgeRadius),
                                            ),
                                            child: Icon(
                                              Icons.folder,
                                              size: badgeIconSize,
                                              color: Colors.amber[600],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          // Text section
                          SizedBox(
                            height: textHeight,
                            width: double.infinity,
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildNameWidget(
                                  context,
                                  isDarkMode,
                                  fontSize: fontSize,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Interaction overlay
                      Positioned.fill(
                        child: OptimizedInteractionLayer(
                          onTap: () {
                            // Navigate to folder on mobile
                            widget.onNavigate(widget.folder.path);
                          },
                          onDoubleTap: () {
                            if (widget.clearSelectionMode != null) {
                              widget.clearSelectionMode!();
                            }
                            widget.onNavigate(widget.folder.path);
                          },
                          onLongPress: () =>
                              _showFolderContextMenu(context, null),
                        ),
                      ),

                      // Selected overlay tint (flat)
                      if (_visuallySelected)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: ItemInteractionStyle.thumbnailOverlayColor(
                                theme: Theme.of(context),
                                isDesktopMode: widget.isDesktopMode,
                                isSelected: true,
                                isHovering: false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Opacity(
      opacity: isBeingCut ? ItemInteractionStyle.cutOpacity : 1.0,
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showFolderContextMenu(context, details.globalPosition),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Thumbnail/Icon section — subtle framed thumbnail + folder badge
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Framed thumbnail to imply "folder" without outlining whole card
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.12),
                                  width: 1.0,
                                ),
                                // Slight background so folder thumbnails read as containers
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.02),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: FolderThumbnail(folder: widget.folder),
                              ),
                            ),

                            // Subtle overlay for selection/hover
                            if (thumbnailOverlayColor != Colors.transparent)
                              IgnorePointer(
                                child: Container(color: thumbnailOverlayColor),
                              ),

                            // Small folder badge to make it visually a folder
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(6.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.folder,
                                  size: 14,
                                  color: Colors.amber[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Text section
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildNameWidget(context, isDarkMode),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: OptimizedInteractionLayer(
                    onTap: () {
                      if (widget.isDesktopMode &&
                          widget.toggleFolderSelection != null) {
                        _handleFolderSelection();
                      } else {
                        widget.onNavigate(widget.folder.path);
                      }
                    },
                    onDoubleTap: () {
                      if (widget.clearSelectionMode != null) {
                        widget.clearSelectionMode!();
                      }
                      widget.onNavigate(widget.folder.path);
                    },
                    onLongPress: () => _showFolderContextMenu(context, null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset? globalPosition) {
    // Check for multiple selection
    try {
      final selectionBloc = context.read<SelectionBloc>();
      final selectionState = selectionBloc.state;

      if (selectionState.allSelectedPaths.length > 1 &&
          selectionState.allSelectedPaths.contains(widget.folder.path)) {
        showMultipleFilesContextMenu(
          context: context,
          selectedPaths: selectionState.allSelectedPaths,
          globalPosition: globalPosition ?? Offset.zero,
          onClearSelection: () {
            selectionBloc.add(ClearSelection());
          },
        );
        return;
      }
    } catch (e) {
      debugPrint('Error showing context menu: $e');
    }

    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onNavigate,
      folderTags: [], // Pass empty tags or fetch from database in real implementation
      globalPosition: globalPosition, // Pass position for desktop popup menu
    );
  }

  Widget _buildNameWidget(
    BuildContext context,
    bool isDarkMode, {
    double fontSize = 12.0,
  }) {
    // Check if this item is being renamed inline (desktop only)
    final renameController = InlineRenameScope.maybeOf(context);
    final isBeingRenamed = renameController != null &&
        renameController.renamingPath == widget.folder.path;

    final textWidget = Text(
      widget.folder.basename(),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        color: isDarkMode ? Colors.white : Colors.black87,
        fontWeight: _visuallySelected ? FontWeight.bold : FontWeight.w500,
      ),
    );

    if (isBeingRenamed && renameController.textController != null) {
      return Stack(
        children: [
          // Invisible text for layout sizing
          Opacity(opacity: 0, child: textWidget),
          // Positioned editable field on top
          Positioned.fill(
            child: InlineRenameField(
              controller: renameController,
              onCommit: () => renameController.commitRename(context),
              onCancel: () => renameController.cancelRename(),
              textStyle: TextStyle(
                fontSize: fontSize,
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight:
                    _visuallySelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      );
    }

    return textWidget;
  }
}
