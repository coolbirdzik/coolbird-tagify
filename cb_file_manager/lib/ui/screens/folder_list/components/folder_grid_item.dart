import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/ui/components/shared_file_context_menu.dart';
import 'folder_thumbnail.dart';
import 'package:cb_file_manager/ui/components/optimized_interaction_handler.dart';

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
          child: Stack(
            children: [
              Column(
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
              Positioned.fill(
                child: OptimizedInteractionLayer(
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
                  onDoubleTap: () {
                    // Clear selection mode when navigating via double click
                    if (widget.clearSelectionMode != null) {
                      widget.clearSelectionMode!();
                    }
                    widget.onNavigate(widget.folder.path);
                  },
                  onLongPress: () => _showFolderContextMenu(context),
                ),
              ),
            ],
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
      folderTags: [], // Pass empty tags or fetch from database in real implementation
    );
  }
}
