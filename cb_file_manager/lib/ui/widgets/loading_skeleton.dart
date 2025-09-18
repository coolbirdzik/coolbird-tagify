import 'package:flutter/material.dart';

/// Enhanced skeleton placeholders with smooth shimmer effects for list and grid views.
class LoadingSkeleton {
  static Widget list({int itemCount = 12}) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(), // Smoother scrolling on mobile
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      itemCount: itemCount,
      cacheExtent: 500, // Better performance
      itemBuilder: (context, index) => _ListTileSkeleton(index: index),
    );
  }

  static Widget grid({required int crossAxisCount, int itemCount = 12}) {
    return GridView.builder(
      physics: const ClampingScrollPhysics(), // Smoother scrolling on mobile
      padding: const EdgeInsets.all(6.0),
      cacheExtent: 800, // Better performance for grid
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => _GridTileSkeleton(index: index),
    );
  }
}

class _ListTileSkeleton extends StatelessWidget {
  final int index;
  const _ListTileSkeleton({required this.index});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Row(
          children: [
            _ShimmerBox(
              width: 48, 
              height: 48, 
              borderRadius: BorderRadius.circular(12),
              delay: Duration(milliseconds: (index * 80).clamp(0, 800)), // Optimized staggered animation
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    width: double.infinity, 
                    height: 16, 
                    borderRadius: BorderRadius.circular(6),
                    delay: Duration(milliseconds: (index * 80 + 40).clamp(0, 840)),
                  ),
                  const SizedBox(height: 10),
                  _ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.45, 
                    height: 14, 
                    borderRadius: BorderRadius.circular(6),
                    delay: Duration(milliseconds: (index * 80 + 80).clamp(0, 880)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTileSkeleton extends StatelessWidget {
  final int index;
  const _GridTileSkeleton({required this.index});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _ShimmerBox(
                width: double.infinity, 
                height: double.infinity,
                delay: Duration(milliseconds: (index * 60).clamp(0, 600)), // Optimized timing
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ShimmerBox(
            width: double.infinity, 
            height: 14, 
            borderRadius: BorderRadius.circular(8),
            delay: Duration(milliseconds: (index * 60 + 30).clamp(0, 630)),
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            width: 85, 
            height: 12, 
            borderRadius: BorderRadius.circular(8),
            delay: Duration(milliseconds: (index * 60 + 60).clamp(0, 660)),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration delay;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
    this.delay = Duration.zero,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;
  bool _isDelayComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500),
    );
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _isDelayComplete = true;
        });
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = _skeletonColor(context);
    final highlightColor = theme.brightness == Brightness.dark 
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.8);

    if (!_isDelayComplete) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

Color _skeletonColor(BuildContext context) {
  final theme = Theme.of(context);
  // Use a surfaceVariant-like tone for better theming
  return theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.6);
}

