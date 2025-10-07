import 'package:flutter/material.dart';
import 'skeleton.dart';

/// Helper class for easy skeleton usage
class SkeletonHelper {
  /// Create a file list skeleton (using album design)
  static Widget fileList({int itemCount = 12}) {
    return Skeleton(
      type: SkeletonType.albumList,
      itemCount: itemCount,
      isAlbum: true,
    );
  }

  /// Create a file grid skeleton (using album design)
  static Widget fileGrid({
    int crossAxisCount = 3,
    int itemCount = 12,
  }) {
    return Skeleton(
      type: SkeletonType.albumGrid,
      crossAxisCount: crossAxisCount,
      itemCount: itemCount,
      isAlbum: true,
    );
  }

  /// Create an album list skeleton
  static Widget albumList({int itemCount = 12}) {
    return Skeleton(
      type: SkeletonType.albumList,
      itemCount: itemCount,
      isAlbum: true,
    );
  }

  /// Create an album grid skeleton
  static Widget albumGrid({
    int crossAxisCount = 3,
    int itemCount = 12,
  }) {
    return Skeleton(
      type: SkeletonType.albumGrid,
      crossAxisCount: crossAxisCount,
      itemCount: itemCount,
      isAlbum: true,
    );
  }

  /// Create a single skeleton box
  static Widget box({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return Skeleton(
      type: SkeletonType.single,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Create a responsive skeleton based on screen size
  /// Always uses album design for better visual consistency
  static Widget responsive({
    required bool isGridView,
    required bool isAlbum,
    int? crossAxisCount,
    int itemCount = 12,
  }) {
    if (isGridView) {
      return albumGrid(
        crossAxisCount: crossAxisCount ?? 3,
        itemCount: itemCount,
      );
    } else {
      return albumList(itemCount: itemCount);
    }
  }
}
