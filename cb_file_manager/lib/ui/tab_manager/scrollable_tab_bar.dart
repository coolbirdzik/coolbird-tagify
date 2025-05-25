import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added import for HapticFeedback
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/config/app_theme.dart'; // Import app theme
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'dart:io'; // Import dart:io for Platform check

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

    Widget windowCaptionButtons = Platform.isWindows
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add a small spacer to avoid buttons being too close to the tabs or window edge
              const SizedBox(width: 8),
              _WindowCaptionButton(
                icon: EvaIcons.minus,
                onPressed: () async => await windowManager.minimize(),
                tooltip: 'Minimize',
                theme: theme,
              ),
              _WindowCaptionButton(
                // Icon and tooltip will be updated by its state
                icon: EvaIcons.squareOutline,
                onPressed: () async {
                  bool isMaximized = await windowManager.isMaximized();
                  if (isMaximized) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                tooltip: 'Maximize',
                theme: theme,
              ),
              _WindowCaptionButton(
                icon: EvaIcons.close,
                onPressed: () async => await windowManager.close(),
                tooltip: 'Close',
                isCloseButton: true,
                theme: theme,
              ),
              const SizedBox(width: 6), // Consistent with previous spacing
            ],
          )
        : const SizedBox.shrink(); // Use SizedBox.shrink for non-Windows

    return DragToMoveArea(
      child: Container(
        height: Platform.isWindows
            ? 48
            : null, // Provide a specific height for the custom title bar on Windows
        decoration: BoxDecoration(
          color: tabBackgroundColor,
          // Removed borderRadius for a flush look on Windows title bar
          // borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.02 * 255).round()),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        // Adjust margin for Windows to be flush at the top
        margin: Platform.isWindows
            ? const EdgeInsets.only(
                bottom: 1) // Minimal bottom margin to keep shadow visible maybe
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // Padding to align content within the new title bar structure
        padding: Platform.isWindows
            ? const EdgeInsets.only(
                left: 8.0) // Padding for the draggable area before tabs start
            : EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment
              .center, // Vertically align tabs and caption buttons
          children: [
            Expanded(
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
            windowCaptionButtons,
          ],
        ),
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

          // "New Tab" button with modern styling
          if (widget.onAddTabPressed != null)
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Add new tab',
                child: Container(
                  margin: const EdgeInsets.only(
                      left: 4, right: 4), // Keep existing margin
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: widget.onAddTabPressed,
                    hoverColor: widget
                        .hoverColor, // Use the general hover color passed down
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
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

  // Variables for custom tap detection
  PointerDownEvent? _pointerDownEvent;
  bool _isTapCandidate = false;
  static const double _kTapSlop =
      kDoubleTapSlop / 2.0; // Max distance for a tap
  static const int _kTapTimeoutMilliseconds = 200; // Max time for a tap

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

  void _resetTapCandidateState() {
    _isTapCandidate = false;
    _pointerDownEvent = null;
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
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        // Outer listener for middle mouse button close
        onPointerDown: (PointerDownEvent event) {
          if (event.buttons == kMiddleMouseButton) {
            // kMiddleMouseButton is 4
            widget.onClose?.call();
          }
        },
        child: Listener(
          // Inner listener for custom tap detection
          onPointerDown: (PointerDownEvent event) {
            if (event.buttons == kPrimaryMouseButton) {
              // kPrimaryMouseButton is 1
              _isTapCandidate = true;
              _pointerDownEvent = event;
            }
          },
          onPointerMove: (PointerMoveEvent event) {
            if (_isTapCandidate && _pointerDownEvent != null) {
              final Offset delta = event.position - _pointerDownEvent!.position;
              if (delta.distanceSquared > _kTapSlop * _kTapSlop) {
                _resetTapCandidateState();
              }
            }
          },
          onPointerUp: (PointerUpEvent event) {
            if (_isTapCandidate && _pointerDownEvent != null) {
              // Calculate duration between pointer down and up directly from their timestamps
              final Duration timeSinceDown =
                  event.timeStamp - _pointerDownEvent!.timeStamp;
              final Offset delta = event.position - _pointerDownEvent!.position;
              if (timeSinceDown.inMilliseconds < _kTapTimeoutMilliseconds &&
                  delta.distanceSquared <= _kTapSlop * _kTapSlop &&
                  !_isCloseButtonHovered) {
                // Only activate tab if not clicking on close button
                widget.onTap();
                HapticFeedback.lightImpact();
              }
            }
            _resetTapCandidateState();
          },
          onPointerCancel: (PointerCancelEvent event) {
            _resetTapCandidateState();
          },
          child: AnimatedBuilder(
            // GestureDetector removed, tap handled by Listener above
            animation: _animation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    width: tabWidth,
                    height: 38,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? widget.activeTabColor
                          : (_isHovered
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
                                color: Colors.black
                                    .withAlpha((0.03 * 255).round()),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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

                          // Hover effect
                          if (_isHovered && !widget.isActive)
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
                      top: 3 + (38 - 22) / 2, // Center vertically in the tab
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
                            child: GestureDetector(
                              onTap: () {
                                widget.onClose?.call();
                                HapticFeedback
                                    .lightImpact(); // Add haptic feedback
                              },
                              behavior: HitTestBehavior
                                  .opaque, // Intercept all pointer events
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
                                      : (_isHovered
                                          ? (isDarkMode
                                              ? Colors.white.withAlpha(
                                                  (0.1 * 255).round())
                                              : Colors.black.withAlpha(
                                                  (0.05 * 255).round()))
                                          : Colors.transparent),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

// New widget for window caption buttons
class _WindowCaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isCloseButton;
  final ThemeData theme;

  const _WindowCaptionButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isCloseButton = false,
    required this.theme,
  }) : super(key: key);

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _isHovered = false;
  IconData? _currentMaximizeIcon;
  String? _currentMaximizeTooltip;
  _MyWindowListener? _windowListener;

  @override
  void initState() {
    super.initState();
    // Listen to window state changes only for the maximize/restore button
    if (widget.tooltip == 'Maximize' || widget.tooltip == 'Restore') {
      _windowListener =
          _MyWindowListener(onWindowStateChange: _updateMaximizeButtonVisuals);
      windowManager.addListener(_windowListener!);
      _updateMaximizeButtonVisuals(); // Initial check
    }
  }

  @override
  void dispose() {
    if (_windowListener != null) {
      windowManager.removeListener(_windowListener!);
    }
    super.dispose();
  }

  Future<void> _updateMaximizeButtonVisuals() async {
    if (!mounted) return;
    bool isMaximized = await windowManager.isMaximized();
    setState(() {
      _currentMaximizeIcon =
          isMaximized ? EvaIcons.collapseOutline : EvaIcons.expandOutline;
      _currentMaximizeTooltip = isMaximized ? 'Restore' : 'Maximize';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final hoverBackgroundColor = widget.isCloseButton
        ? Colors.red.withAlpha((0.9 * 255).round())
        : (isDarkMode
            ? Colors.white.withAlpha((0.1 * 255).round())
            : Colors.black.withAlpha((0.08 * 255).round()));
    final hoverIconColor = widget.isCloseButton
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black);

    return Tooltip(
      message: _currentMaximizeTooltip ?? widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _isHovered ? hoverBackgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _currentMaximizeIcon ?? widget.icon,
              size: 18,
              color: _isHovered ? hoverIconColor : iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// Define a class that extends WindowListener
class _MyWindowListener extends WindowListener {
  final VoidCallback onWindowStateChange;

  _MyWindowListener({required this.onWindowStateChange});

  @override
  void onWindowMaximize() {
    onWindowStateChange();
  }

  @override
  void onWindowUnmaximize() {
    onWindowStateChange();
  }

  @override
  void onWindowRestore() {
    onWindowStateChange();
  }
  // You can override other methods if needed:
  // onWindowFocus, onWindowBlur, onWindowMove, onWindowResize,
  // onWindowMinimize, onWindowEnterFullScreen, onWindowLeaveFullScreen, onWindowClose
}
