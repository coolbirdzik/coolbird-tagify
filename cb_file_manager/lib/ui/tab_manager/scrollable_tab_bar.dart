import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added import for HapticFeedback
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/config/app_theme.dart'; // Import app theme
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'dart:io'; // Import dart:io for Platform check
import 'package:cb_file_manager/ui/components/window_caption_buttons.dart';

/// A custom TabBar wrapper that translates vertical mouse wheel scrolling
/// to horizontal scrolling of the tab bar, with modern styling.
class ScrollableTabBar extends StatefulWidget {
  final TabController controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final EdgeInsetsGeometry? labelPadding;
  final TabBarIndicatorSize? indicatorSize;
  final ScrollPhysics? physics;
  final Decoration? indicator;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Function(int)? onTap;
  final VoidCallback? onAddTabPressed;
  final Function(int)? onTabClose; // Added callback for tab closing

  const ScrollableTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
    this.isScrollable = true,
    this.labelPadding,
    this.indicatorSize,
    this.physics,
    this.indicator,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelColor,
    this.unselectedLabelColor,
    this.onTap,
    this.onAddTabPressed,
    this.onTabClose, // Added parameter
  }) : super(key: key);

  @override
  State<ScrollableTabBar> createState() => _ScrollableTabBarState();
}

class _ScrollableTabBarState extends State<ScrollableTabBar> {
  // Create a scroll controller for the horizontal scroll view
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Modern tab colors
    final tabBackgroundColor = isDarkMode
        ? theme.scaffoldBackgroundColor.withAlpha((0.8 * 255).round())
        : theme.scaffoldBackgroundColor.withAlpha((0.7 * 255).round());
    final activeTabColor =
        isDarkMode ? theme.colorScheme.surface : theme.colorScheme.surface;
    final hoverColor = isDarkMode
        ? theme.colorScheme.surface.withAlpha((0.8 * 255).round())
        : theme.colorScheme.surface.withAlpha((0.8 * 255).round());

    Widget windowCaptionButtons =
        Platform.isWindows ? WindowCaptionButtons(theme: theme) : const SizedBox.shrink();

    // Main container for the entire bar
    return Container(
      height: Platform.isWindows
          ? 48
          : null, // Provide a specific height for the custom title bar on Windows
      decoration: BoxDecoration(
        color: tabBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.02 * 255).round()),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      margin: Platform.isWindows
          ? const EdgeInsets.only(bottom: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: Platform.isWindows
          ? const EdgeInsets.only(
              left: 8.0) // Initial padding for the draggable area
          : EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Draggable area for tabs
          Expanded(
            child: DragToMoveArea(
              child: Listener(
                onPointerSignal: (PointerSignalEvent event) {
                  if (event is PointerScrollEvent &&
                      _scrollController.hasClients) {
                    GestureBinding.instance.pointerSignalResolver
                        .register(event, (_) {});
                    final double newPosition =
                        _scrollController.offset + event.scrollDelta.dy;
                    _scrollController.animateTo(
                      newPosition.clamp(
                        _scrollController.position.minScrollExtent,
                        _scrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _ModernTabBar(
                    controller: widget.controller,
                    tabs: widget.tabs,
                    labelColor:
                        isDarkMode ? Colors.white : theme.colorScheme.primary,
                    unselectedLabelColor: isDarkMode
                        ? Colors.white70
                        : theme.colorScheme.onSurface,
                    labelStyle: widget.labelStyle,
                    unselectedLabelStyle: widget.unselectedLabelStyle,
                    onTap: widget.onTap,
                    activeTabColor: activeTabColor,
                    hoverColor: hoverColor,
                    tabBackgroundColor:
                        tabBackgroundColor, // This is for individual tab bg, might need renaming or re-evaluation
                    onAddTabPressed: widget.onAddTabPressed,
                    onTabClose: widget.onTabClose,
                    theme: theme,
                  ),
                ),
              ),
            ),
          ),
          // Window caption buttons outside DragToMoveArea
          windowCaptionButtons,
        ],
      ),
    );
  }
}

/// Modern tab bar implementation with softer, more elegant styling
class _ModernTabBar extends StatefulWidget {
  final TabController controller;
  final List<Widget> tabs;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Function(int)? onTap;
  final Color activeTabColor;
  final Color hoverColor;
  final Color
      tabBackgroundColor; // This is the background of the tab itself, not the whole bar
  final VoidCallback? onAddTabPressed;
  final Function(int)? onTabClose;
  final ThemeData theme;

  const _ModernTabBar({
    Key? key,
    required this.controller,
    required this.tabs,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.onTap,
    required this.activeTabColor,
    required this.hoverColor,
    required this.tabBackgroundColor,
    this.onAddTabPressed,
    this.onTabClose,
    required this.theme,
  }) : super(key: key);

  @override
  State<_ModernTabBar> createState() => _ModernTabBarState();
}

class _ModernTabBarState extends State<_ModernTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabControllerChange);
  }

  @override
  void didUpdateWidget(_ModernTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onTabControllerChange);
      widget.controller.addListener(_onTabControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabControllerChange);
    super.dispose();
  }

  void _onTabControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;

    return Padding(
      // Padding to vertically center the tabs if the parent container has a fixed height (e.g., 48px)
      // _ModernTab height is 38px. (48-38)/2 = 5px vertical padding.
      // Horizontal padding is for spacing from the edges of the scroll area.
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize
            .min, // CRITICAL: This ensures the Row takes only the width of its children
        children: [
          ...List.generate(widget.tabs.length, (index) {
            final isActive = widget.controller.index == index;
            return _ModernTab(
              isActive: isActive,
              onTap: () => widget.onTap?.call(index),
              activeTabColor: widget.activeTabColor,
              hoverColor: widget.hoverColor,
              tabBackgroundColor: widget
                  .tabBackgroundColor, // This is for the individual tab's bg when active
              labelColor:
                  isActive ? widget.labelColor : widget.unselectedLabelColor,
              labelStyle:
                  isActive ? widget.labelStyle : widget.unselectedLabelStyle,
              child: widget.tabs[index],
              onClose: () => widget.onTabClose?.call(index),
              theme: widget.theme,
            );
          }),

          // "New Tab" button with modern styling and optimized interaction
          if (widget.onAddTabPressed != null)
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Add new tab',
                child: Container(
                  margin: const EdgeInsets.only(
                      left: 4, right: 4), // Keep existing margin
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _OptimizedButtonInteraction(
                      onTap: () {
                        widget.onAddTabPressed?.call();
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode
                              ? Colors.white.withAlpha((0.08 * 255).round())
                              : Colors.black.withAlpha((0.05 * 255).round()),
                        ),
                        child: Center(
                          child: Icon(
                            EvaIcons.plus,
                            size: 18,
                            color: isDarkMode
                                ? Colors.white70
                                : widget.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Individual modern tab with softer, more elegant styling
class _ModernTab extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  final Color activeTabColor;
  final Color hoverColor;
  final Color tabBackgroundColor;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final Widget child;
  final VoidCallback? onClose;
  final ThemeData theme;

  const _ModernTab({
    Key? key,
    required this.isActive,
    required this.onTap,
    required this.activeTabColor,
    required this.hoverColor,
    required this.tabBackgroundColor,
    this.labelColor,
    this.labelStyle,
    required this.child,
    this.onClose,
    required this.theme,
  }) : super(key: key);

  @override
  State<_ModernTab> createState() => _ModernTabState();
}

class _ModernTabState extends State<_ModernTab>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isCloseButtonHovered = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ModernTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tabWidth = 210.0;
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final primaryColor = widget.theme.colorScheme.primary;

    final hoverColor = isDarkMode
        ? Colors.white.withAlpha((0.04 * 255).round())
        : Colors.black.withAlpha((0.04 * 255).round());

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return _OptimizedTabInteraction(
            onTap: widget.onTap,
            onMiddleClick: widget.onClose != null ? widget.onClose! : null,
            child: Stack(
              children: [
                Container(
                  width: tabWidth,
                  height: 38,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? widget.activeTabColor
                        : (_isHovered && !_isCloseButtonHovered
                            ? widget.hoverColor
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isActive
                          ? (isDarkMode
                              ? Colors.white.withAlpha((0.1 * 255).round())
                              : Colors.black.withAlpha((0.05 * 255).round()))
                          : Colors.transparent,
                      width: 0.5,
                    ),
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color:
                                  Colors.black.withAlpha((0.03 * 255).round()),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Tab content
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                color: widget.labelColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ).merge(widget.labelStyle),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 24.0),
                                      child: Center(child: widget.child),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Hover effect - only show when not hovering the close button
                        if (_isHovered &&
                            !_isCloseButtonHovered &&
                            !widget.isActive)
                          Positioned.fill(
                            child: Material(
                              color: hoverColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                        // Active tab indicator - subtle left border
                        if (widget.isActive)
                          Positioned(
                            left: 0,
                            top: 6,
                            bottom: 6,
                            width: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Close button - positioned on top of tab
                if (widget.onClose != null)
                  Positioned(
                    top: (38 - 22) / 2, // Center vertically in the tab
                    right: 12, // Position from right edge
                    child: AnimatedOpacity(
                      opacity: (_isHovered || widget.isActive) ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 150),
                      child: Material(
                        color: Colors.transparent,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isCloseButtonHovered = true),
                          onExit: (_) =>
                              setState(() => _isCloseButtonHovered = false),
                          child: _OptimizedButtonInteraction(
                            onTap: () {
                              widget.onClose?.call();
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _isCloseButtonHovered
                                    ? (isDarkMode
                                        ? Colors.white
                                            .withAlpha((0.15 * 255).round())
                                        : Colors.black
                                            .withAlpha((0.08 * 255).round()))
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                EvaIcons.close,
                                size: 16,
                                color: isDarkMode
                                    ? Colors.white
                                        .withAlpha((0.7 * 255).round())
                                    : Colors.black
                                        .withAlpha((0.5 * 255).round()),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Optimized tab interaction handler that eliminates delay on tab clicks
class _OptimizedTabInteraction extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onMiddleClick;
  final Widget child;

  const _OptimizedTabInteraction({
    Key? key,
    required this.onTap,
    this.onMiddleClick,
    required this.child,
  }) : super(key: key);

  @override
  _OptimizedTabInteractionState createState() =>
      _OptimizedTabInteractionState();
}

class _OptimizedTabInteractionState extends State<_OptimizedTabInteraction> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // Primary mouse button (left click)
        if (event.buttons == kPrimaryMouseButton) {
          widget.onTap();
          HapticFeedback.lightImpact();
        }
        // Middle mouse button (wheel click)
        else if (event.buttons == kMiddleMouseButton &&
            widget.onMiddleClick != null) {
          widget.onMiddleClick!();
          HapticFeedback.lightImpact();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

/// Optimized button interaction handler for the close and add tab buttons
class _OptimizedButtonInteraction extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _OptimizedButtonInteraction({
    Key? key,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  _OptimizedButtonInteractionState createState() =>
      _OptimizedButtonInteractionState();
}

class _OptimizedButtonInteractionState
    extends State<_OptimizedButtonInteraction> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons == kPrimaryMouseButton) {
          widget.onTap();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

// New widget for window caption buttons
