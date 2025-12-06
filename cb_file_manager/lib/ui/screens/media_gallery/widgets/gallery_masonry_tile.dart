import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/tags_overlay.dart';

class GalleryMasonryTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool isSelectionMode;
  final List<String> tags;
  final int gridSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<double> Function(File) getAspectRatio;

  // PERFORMANCE: Static cache for aspect ratios to avoid FutureBuilder recalculation during scrolling
  static final Map<String, double> _aspectRatioCache = {};

  const GalleryMasonryTile({
    Key? key,
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.tags,
    required this.gridSize,
    required this.onTap,
    required this.onLongPress,
    required this.getAspectRatio,
  }) : super(key: key);

  /// Clear the aspect ratio cache (useful when switching directories)
  static void clearAspectRatioCache() {
    _aspectRatioCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = file.path.split(Platform.pathSeparator).last;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      // PERFORMANCE: Wrap in RepaintBoundary to isolate repaints
      child: RepaintBoundary(
        // PERFORMANCE: Check cache first to avoid FutureBuilder recalculation
        child: _aspectRatioCache.containsKey(file.path)
            ? _buildTileContent(_aspectRatioCache[file.path]!, theme, fileName)
            : FutureBuilder<double>(
                // PERFORMANCE: Use file path as key to cache aspect ratio results
                key: ValueKey('aspect-${file.path}'),
                future: getAspectRatio(file),
                builder: (context, snapshot) {
                  final ratio = snapshot.data ?? 1.0;
                  // Cache the aspect ratio once calculated
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    _aspectRatioCache[file.path] = ratio;
                  }
                  return _buildTileContent(ratio, theme, fileName);
                },
              ),
      ),
    );
  }

  Widget _buildTileContent(double ratio, ThemeData theme, String fileName) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Hero(
                tag: file.path,
                child: ThumbnailLoader(
                  filePath: file.path,
                  isVideo: false,
                  isImage: true,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                  fallbackBuilder: () => Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Filename label at bottom with gradient background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        if (tags.isNotEmpty) TagsOverlay(tags: tags, gridSize: gridSize),
        if (isSelectionMode)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}
