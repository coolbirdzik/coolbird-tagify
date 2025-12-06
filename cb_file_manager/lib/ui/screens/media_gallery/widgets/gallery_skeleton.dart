import 'dart:io';
import 'package:flutter/material.dart';
import '../../../components/common/skeleton.dart';

/// Gallery skeleton for image/video gallery screens
class GallerySkeleton extends StatelessWidget {
  final bool isGrid;
  final double thumbnailSize;

  const GallerySkeleton({
    Key? key,
    required this.isGrid,
    required this.thumbnailSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;

    if (isGrid) {
      // Grid skeleton - single item with shimmer animation
      final columns = thumbnailSize.round();
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = (screenWidth - 16 - ((columns - 1) * 8)) / columns;
      final itemHeight = itemWidth * 0.75; // Portrait aspect ratio

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ShimmerBox(
              width: itemWidth,
              height: itemHeight,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      // List skeleton - single item with shimmer animation
      final listTile = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ShimmerBox(
              width: 60,
              height: 60,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: 120,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: isMobile
            ? listTile
            : Card(
                margin: EdgeInsets.zero,
                child: listTile,
              ),
      );
    }
  }
}
