import 'package:flutter/material.dart';

/// Unified skeleton component for file and album loading
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Duration duration;
  final SkeletonType type;
  final int? itemCount;
  final int? crossAxisCount;
  final bool isAlbum;

  const Skeleton({
    Key? key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1600),
    this.type = SkeletonType.single,
    this.itemCount = 12,
    this.crossAxisCount = 3,
    this.isAlbum = false,
  }) : super(key: key);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

enum SkeletonType {
  single,
  list,
  grid,
  albumGrid,
  albumList,
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case SkeletonType.single:
        return _buildSingleSkeleton(context);
      case SkeletonType.list:
        return _buildListSkeleton(context);
      case SkeletonType.grid:
        return _buildGridSkeleton(context);
      case SkeletonType.albumGrid:
        return _buildAlbumGridSkeleton(context);
      case SkeletonType.albumList:
        return _buildAlbumListSkeleton(context);
    }
  }

  Widget _buildSingleSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceVariant.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.6);
    final midColor = cs.surfaceVariant.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.45);
    final highlightColor = cs.surface.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.28);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double shift = (_controller.value * 2) - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment(-1.2 + shift, -0.3),
              end: Alignment(1.2 + shift, 0.3),
              colors: [
                baseColor,
                midColor,
                highlightColor,
                midColor,
                baseColor
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.08),
              width: 0.6,
            ),
          ),
        );
      },
    );
  }

  Widget _buildListSkeleton(BuildContext context) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: widget.itemCount ?? 12,
      cacheExtent: 500,
      itemBuilder: (context, index) => _SkeletonListItem(
        index: index,
        controller: _controller,
      ),
    );
  }

  Widget _buildGridSkeleton(BuildContext context) {
    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8.0),
      cacheExtent: 800,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount ?? 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0, // Always use album ratio
      ),
      itemCount: widget.itemCount ?? 12,
      itemBuilder: (context, index) => _SkeletonGridItem(
        index: index,
        controller: _controller,
      ),
    );
  }

  Widget _buildAlbumGridSkeleton(BuildContext context) {
    return _buildGridSkeleton(context);
  }

  Widget _buildAlbumListSkeleton(BuildContext context) {
    return _buildListSkeleton(context);
  }
}

/// Skeleton list item with album design
class _SkeletonListItem extends StatelessWidget {
  final int index;
  final AnimationController controller;

  const _SkeletonListItem({
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]?.withOpacity(0.3)
              : Colors.grey[100]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            _ShimmerBox(
              width: 56, // Always use album size for consistency
              height: 56,
              borderRadius: BorderRadius.circular(16),
              controller: controller,
              delay: Duration(milliseconds: (index * 80).clamp(0, 800)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    width: double.infinity,
                    height: 18, // Always use album size
                    borderRadius: BorderRadius.circular(8),
                    controller: controller,
                    delay:
                        Duration(milliseconds: (index * 80 + 40).clamp(0, 840)),
                  ),
                  const SizedBox(height: 12),
                  _ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 16, // Always use album size
                    borderRadius: BorderRadius.circular(8),
                    controller: controller,
                    delay:
                        Duration(milliseconds: (index * 80 + 80).clamp(0, 880)),
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBox(
                    width: 120,
                    height: 12,
                    borderRadius: BorderRadius.circular(6),
                    controller: controller,
                    delay: Duration(
                        milliseconds: (index * 80 + 120).clamp(0, 920)),
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

/// Skeleton grid item with album design
class _SkeletonGridItem extends StatelessWidget {
  final int index;
  final AnimationController controller;

  const _SkeletonGridItem({
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]?.withOpacity(0.2)
              : Colors.grey[50]?.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(12), // Always use album style
                child: _ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  controller: controller,
                  delay: Duration(milliseconds: (index * 60).clamp(0, 600)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ShimmerBox(
              width: double.infinity,
              height: 16, // Always use album size
              borderRadius: BorderRadius.circular(8),
              controller: controller,
              delay: Duration(milliseconds: (index * 60 + 30).clamp(0, 630)),
            ),
            const SizedBox(height: 8),
            _ShimmerBox(
              width: 100, // Always use album size
              height: 14, // Always use album size
              borderRadius: BorderRadius.circular(8),
              controller: controller,
              delay: Duration(milliseconds: (index * 60 + 60).clamp(0, 660)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer effect box with animation
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration delay;
  final AnimationController controller;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
    this.delay = Duration.zero,
    required this.controller,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> {
  bool _isDelayComplete = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _isDelayComplete = true;
        });
      }
    });
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
      animation: widget.controller,
      builder: (context, child) {
        final double value = widget.controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
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
  return theme.colorScheme.surfaceVariant
      .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.6);
}
