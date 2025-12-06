import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:flutter/services.dart';
import '../../../components/common/shared_file_context_menu.dart';
import '../../../components/common/optimized_interaction_handler.dart';

class FolderDetailsItem extends StatefulWidget {
  final Directory folder;
  final Function(String)? onTap;
  final bool isSelected;
  final ColumnVisibility columnVisibility;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final Function()? clearSelectionMode;

  const FolderDetailsItem({
    Key? key,
    required this.folder,
    this.onTap,
    this.isSelected = false,
    required this.columnVisibility,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.clearSelectionMode,
  }) : super(key: key);

  @override
  State<FolderDetailsItem> createState() => _FolderDetailsItemState();
}

class _FolderDetailsItemState extends State<FolderDetailsItem> {
  bool _isHovering = false;
  bool _visuallySelected = false;
  FileStat? _fileStat;

  @override
  void initState() {
    super.initState();
    _visuallySelected = widget.isSelected;
    _loadFolderStats();
  }

  @override
  void didUpdateWidget(FolderDetailsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      setState(() {
        _visuallySelected = widget.isSelected;
      });
    }

    if (widget.folder.path != oldWidget.folder.path) {
      _loadFolderStats();
    }
  }

  Future<void> _loadFolderStats() async {
    try {
      final stat = await widget.folder.stat();
      if (mounted) {
        setState(() {
          _fileStat = stat;
        });
      }
    } catch (e) {
      debugPrint('Error loading folder stats: $e');
    }
  }

  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Check for Shift and Ctrl keys
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    // Log selection attempt
    debugPrint("Folder selection: ${widget.folder.path}");
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

    // Call toggleFolderSelection with appropriate parameters
    widget.toggleFolderSelection!(
      widget.folder.path,
      shiftSelect: isShiftPressed,
      ctrlSelect: isCtrlPressed,
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset? globalPosition) {
    // Use the shared folder context menu
    showFolderContextMenu(
      context: context,
      folder: widget.folder,
      onNavigate: widget.onTap,
      folderTags: [], // Pass empty tags or fetch from database in real implementation
      globalPosition: globalPosition, // Pass position for desktop popup menu
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate colors based on selection state
    final Color itemBackgroundColor = _visuallySelected
        ? Theme.of(context).primaryColor.withOpacity(0.15)
        : _isHovering && widget.isDesktopMode
            ? isDarkMode
                ? Colors.grey[800]!
                : Colors.grey[100]!
            : Colors.transparent;

    final BoxDecoration boxDecoration = _visuallySelected
        ? BoxDecoration(
            color: itemBackgroundColor,
          )
        : BoxDecoration(
            color: itemBackgroundColor,
          );

    return GestureDetector(
      onSecondaryTapDown: (details) => _showFolderContextMenu(context, details.globalPosition),
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
                          const Icon(remix.Remix.folder_3_line,
                              color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.folder.basename(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: _visuallySelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
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
                        child: const Text(
                          'Thư mục',
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
                        child: const Text(
                          '', // Folders don't typically show size in explorer
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
            // Replace with optimized interaction layer
            Positioned.fill(
              child: OptimizedInteractionLayer(
                onTap: () {
                  if (widget.isDesktopMode &&
                      widget.toggleFolderSelection != null) {
                    _handleFolderSelection();
                  } else if (widget.onTap != null) {
                    widget.onTap!(widget.folder.path);
                  }
                },
                onDoubleTap: () {
                  if (widget.clearSelectionMode != null) {
                    widget.clearSelectionMode!();
                  }
                  if (widget.onTap != null) {
                    widget.onTap!(widget.folder.path);
                  }
                },
                onLongPress: () {
                  if (widget.toggleFolderSelection != null) {
                    _handleFolderSelection();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
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

// Separate interaction layer to handle gestures without requiring content to rebuild
class _FolderInteractionLayer extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback? onLongPress;

  const _FolderInteractionLayer({
    required this.onTap,
    required this.onDoubleTap,
    this.onLongPress,
  });

  @override
  _FolderInteractionLayerState createState() => _FolderInteractionLayerState();
}

class _FolderInteractionLayerState extends State<_FolderInteractionLayer> {
  int _lastTapTime = 0;
  Offset? _lastTapPosition;
  static const int _doubleTapTimeout = 300; // milliseconds
  static const double _doubleTapMaxDistance = 40.0; // pixels

  void _handleTapDown(TapDownDetails details) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final position = details.globalPosition;

    // Always trigger onTap immediately
    widget.onTap();

    // Check if this could be a double tap
    if (_lastTapTime > 0) {
      final timeDiff = now - _lastTapTime;
      final distance = _lastTapPosition != null
          ? (position - _lastTapPosition!).distance
          : 0.0;

      // If within double tap time window and distance threshold
      if (timeDiff <= _doubleTapTimeout && distance <= _doubleTapMaxDistance) {
        widget.onDoubleTap();
        // Reset to prevent triple tap
        _lastTapTime = 0;
        _lastTapPosition = null;
        return;
      }
    }

    // Store info for potential next tap
    _lastTapTime = now;
    _lastTapPosition = position;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onLongPress: widget.onLongPress,
    );
  }
}
