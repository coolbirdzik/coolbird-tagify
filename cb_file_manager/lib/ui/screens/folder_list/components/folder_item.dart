import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cb_file_manager/helpers/core/io_extensions.dart';
import '../../../components/common/shared_file_context_menu.dart';
import 'package:remixicon/remixicon.dart' as remix;
import '../../../components/common/optimized_interaction_handler.dart';

class FolderItem extends StatefulWidget {
  final Directory folder;
  final Function(String)? onTap;
  final bool isSelected;
  final Function(String, {bool shiftSelect, bool ctrlSelect})?
      toggleFolderSelection;
  final bool isDesktopMode;
  final String? lastSelectedPath;
  final Function()? clearSelectionMode;

  const FolderItem({
    Key? key,
    required this.folder,
    this.onTap,
    this.isSelected = false,
    this.toggleFolderSelection,
    this.isDesktopMode = false,
    this.lastSelectedPath,
    this.clearSelectionMode,
  }) : super(key: key);

  @override
  State<FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<FolderItem> {
  // Use ValueNotifier for hover state to reduce rebuilds
  final ValueNotifier<bool> _isHovering = ValueNotifier<bool>(false);

  // Lazy, cached folder stat to avoid I/O during fast scrolls
  late Future<FileStat> _folderStatFuture;
  static final Map<String, FileStat> _folderStatCache = <String, FileStat>{};
  static const int _maxCacheSize = 100;

  @override
  void initState() {
    super.initState();
    _folderStatFuture = _getFolderStatLazy();
  }

  @override
  void dispose() {
    _isHovering.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FolderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder.path != widget.folder.path) {
      _folderStatFuture = _getFolderStatLazy();
    }
  }

  Future<FileStat> _getFolderStatLazy() async {
    final path = widget.folder.path;

    // Skip stat for virtual network paths to prevent errors and jank
    if (path.startsWith('#network/')) {
      return Future.error('Network folder - no stat needed');
    }

    // Serve from cache if available
    final cached = _folderStatCache[path];
    if (cached != null) return cached;

    // Small delay to prioritize smooth scrolling
    await Future.delayed(const Duration(milliseconds: 100));

    final stat = await widget.folder.stat();
    // Cache with simple size cap
    if (_folderStatCache.length >= _maxCacheSize) {
      _folderStatCache.remove(_folderStatCache.keys.first);
    }
    _folderStatCache[path] = stat;
    return stat;
  }

  void _handleFolderSelection() {
    if (widget.toggleFolderSelection == null) return;

    // Check for Shift and Ctrl keys
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isShiftPressed = keyboard.isShiftPressed;
    final bool isCtrlPressed =
        keyboard.isControlPressed || keyboard.isMetaPressed;

    // Trong mobile mode, luôn sử dụng ctrlSelect để add to selection
    final bool shouldCtrlSelect = widget.isDesktopMode ? isCtrlPressed : true;

    // Call toggleFolderSelection with appropriate parameters
    widget.toggleFolderSelection!(widget.folder.path,
        shiftSelect: isShiftPressed, ctrlSelect: shouldCtrlSelect);
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
    return ValueListenableBuilder<bool>(
      valueListenable: _isHovering,
      builder: (context, isHovering, _) {
        final Color backgroundColor = widget.isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : isHovering && widget.isDesktopMode
                ? Theme.of(context).colorScheme.surface.withOpacity(0.6)
                : Colors.transparent;

        return GestureDetector(
          onSecondaryTapDown: (details) => _showFolderContextMenu(context, details.globalPosition),
          child: MouseRegion(
            onEnter: (_) => _isHovering.value = true,
            onExit: (_) => _isHovering.value = false,
            cursor: SystemMouseCursors.click,
            child: Container(
              margin: EdgeInsets.symmetric(
                  horizontal: widget.isDesktopMode ? 8.0 : 0,
                  vertical: widget.isDesktopMode ? 4.0 : 0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: widget.isDesktopMode
                    ? BorderRadius.circular(12)
                    : BorderRadius.zero,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              remix.Remix.folder_3_line,
                              color: Colors.amber[600],
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.folder.basename(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<FileStat>(
                                future: _folderStatFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      snapshot.data!.modified
                                          .toString()
                                          .split('.')[0],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                    );
                                  } else if (snapshot.hasError) {
                                    // For network folders or stat errors
                                    return Text(
                                      '—',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                    );
                                  }
                                  return Text(
                                    'Loading...',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Interactive layer cho icon (select)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 80, // Vùng icon + padding
                    child: OptimizedInteractionLayer(
                      onTap: () {
                        // Click vào icon sẽ select item
                        if (widget.toggleFolderSelection != null) {
                          _handleFolderSelection();
                        }
                      },
                      onLongPress: () {
                        if (widget.toggleFolderSelection != null) {
                          _handleFolderSelection();
                        }
                      },
                    ),
                  ),
                  // Interactive layer cho tên (navigate)
                  Positioned(
                    left: 80,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: OptimizedInteractionLayer(
                      onTap: () {
                        // Click vào tên sẽ navigate
                        if (widget.onTap != null) {
                          widget.onTap!(widget.folder.path);
                        }
                      },
                      onDoubleTap: widget.isDesktopMode
                          ? () {
                              if (widget.clearSelectionMode != null) {
                                widget.clearSelectionMode!();
                              }
                              widget.onTap?.call(widget.folder.path);
                            }
                          : null,
                    ),
                  ),
                  // Selection indicator
                  if (widget.isSelected)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: widget.isDesktopMode
                              ? const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                )
                              : BorderRadius.zero,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
