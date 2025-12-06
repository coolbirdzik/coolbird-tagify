import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/widgets/tags_overlay.dart';

class GalleryTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool isSelectionMode;
  final List<String> tags;
  final int gridSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GalleryTile({
    Key? key,
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.tags,
    required this.gridSize,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = file.path.split(Platform.pathSeparator).last;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
          
          // Tags overlay
          if (tags.isNotEmpty) 
            TagsOverlay(tags: tags, gridSize: gridSize),
          
          // Selection overlay
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
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
