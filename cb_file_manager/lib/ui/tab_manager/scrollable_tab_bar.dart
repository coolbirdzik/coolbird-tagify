import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A custom TabBar wrapper that translates vertical mouse wheel scrolling
/// to horizontal scrolling of the tab bar.
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
  final VoidCallback? onAddTabPressed; // Thêm callback cho nút thêm tab mới

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
    this.onAddTabPressed, // Thêm vào constructor
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
    // Tách thanh tab và nút thêm tab thành 2 thành phần riêng biệt
    return Row(
      children: [
        // Phần thanh tab có thể cuộn
        Expanded(
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

                // Scroll horizontally based on the vertical mouse wheel delta
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
              // Cho phép cuộn ngang bằng cách vuốt trên màn hình cảm ứng
              physics: const BouncingScrollPhysics(),
              child: TabBar(
                controller: widget.controller,
                isScrollable: true,
                labelPadding: widget.labelPadding,
                indicatorSize: widget.indicatorSize,
                indicator: widget.indicator,
                labelStyle: widget.labelStyle,
                unselectedLabelStyle: widget.unselectedLabelStyle,
                labelColor: widget.labelColor,
                unselectedLabelColor: widget.unselectedLabelColor,
                onTap: widget.onTap,
                tabs: widget.tabs,
              ),
            ),
          ),
        ),

        // Nút thêm tab mới luôn hiển thị bên phải thanh tab
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onAddTabPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Tooltip(
                message: 'Add new tab',
                child: Icon(Icons.add, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
