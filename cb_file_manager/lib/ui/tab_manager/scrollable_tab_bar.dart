import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added import for HapticFeedback
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/config/app_theme.dart'; // Import app theme

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
        ? theme.scaffoldBackgroundColor.withOpacity(0.8)
        : theme.scaffoldBackgroundColor.withOpacity(0.7);
    final activeTabColor =
        isDarkMode ? theme.colorScheme.surface : theme.colorScheme.surface;
    final hoverColor = isDarkMode
        ? theme.colorScheme.surface.withOpacity(0.8)
        : theme.colorScheme.surface.withOpacity(0.8);

    return Container(
      decoration: BoxDecoration(
        color: tabBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          // Check if it's a mouse wheel event
          if (event is PointerScrollEvent && _scrollController.hasClients) {
            // Prevent the default behavior (vertical scrolling)
            GestureBinding.instance.pointerSignalResolver
                .register(event, (_) {});

            // Calculate the new scroll position
            final double newPosition =
                _scrollController.offset + event.scrollDelta.dy;

            // Smooth horizontal scrolling based on vertical mouse wheel delta
            _scrollController.animateTo(
              // Clamp value between min and max scroll extent
              newPosition.clamp(
                _scrollController.position.minScrollExtent,
                _scrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
        },
        // Use a SingleChildScrollView to enable horizontal scrolling with our controller
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: _ModernTabBar(
            controller: widget.controller,
            tabs: widget.tabs,
            labelColor: isDarkMode ? Colors.white : theme.colorScheme.primary,
            unselectedLabelColor:
                isDarkMode ? Colors.white70 : theme.colorScheme.onSurface,
            labelStyle: widget.labelStyle,
            unselectedLabelStyle: widget.unselectedLabelStyle,
            onTap: widget.onTap,
            activeTabColor: activeTabColor,
            hoverColor: hoverColor,
            tabBackgroundColor: tabBackgroundColor,
            onAddTabPressed: widget.onAddTabPressed, // Pass the callback
            onTabClose: widget.onTabClose, // Pass the callback
            theme: theme,
          ),
        ),
      ),
    );
  }
}

/// Modern tab bar implementation with softer, more elegant styling
class _ModernTabBar extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Function(int)? onTap;
  final Color activeTabColor;
  final Color hoverColor;
  final Color tabBackgroundColor;
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
  Widget build(BuildContext context) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          ...List.generate(tabs.length, (index) {
            final isActive = controller.index == index;
            return _ModernTab(
              isActive: isActive,
              onTap: () => onTap?.call(index),
              activeTabColor: activeTabColor,
              hoverColor: hoverColor,
              tabBackgroundColor: tabBackgroundColor,
              labelColor: isActive ? labelColor : unselectedLabelColor,
              labelStyle: isActive ? labelStyle : unselectedLabelStyle,
              child: tabs[index],
              onClose: () => onTabClose?.call(index),
              theme: theme,
            );
          }),

          // "New Tab" button with modern styling
          if (onAddTabPressed != null)
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Add new tab',
                child: Container(
                  margin: const EdgeInsets.only(left: 4, right: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onAddTabPressed,
                    hoverColor: hoverColor,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                      ),
                      child: Center(
                        child: Icon(
                          EvaIcons.plus,
                          size: 18,
                          color: isDarkMode
                              ? Colors.white70
                              : theme.colorScheme.primary,
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

    // Modern hover color with opacity
    final hoverColor = isDarkMode
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.04);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          // Check if middle button is clicked (button 2)
          if (event.buttons == 4 && widget.onClose != null) {
            widget.onClose?.call();
          }
        },
        child: GestureDetector(
          onTap: () {
            widget.onTap();
            HapticFeedback.lightImpact();
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: tabWidth,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? widget.activeTabColor
                      : (_isHovered ? widget.hoverColor : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isActive
                        ? (isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05))
                        : Colors.transparent,
                    width: 0.5,
                  ),
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
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
                                    padding: const EdgeInsets.only(right: 24.0),
                                    child: Center(child: widget.child),
                                  ),
                                ),
                                // Close button with modern styling
                                if (widget.onClose != null)
                                  AnimatedOpacity(
                                    opacity: (_isHovered || widget.isActive)
                                        ? 1.0
                                        : 0.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: GestureDetector(
                                      onTap: () {
                                        widget.onClose?.call();
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: _isHovered
                                                ? (isDarkMode
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : Colors.black
                                                        .withOpacity(0.05))
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            EvaIcons.close,
                                            size: 16,
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.black.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
