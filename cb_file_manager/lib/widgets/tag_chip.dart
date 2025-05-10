import 'package:flutter/material.dart';
import 'package:cb_file_manager/config/app_theme.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';

/// A reusable tag chip widget for consistent tag styling across the app
class TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool isCompact;
  final Color? customColor;

  const TagChip({
    Key? key,
    required this.tag,
    this.onTap,
    this.onDeleted,
    this.isCompact = false,
    this.customColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Tách tag name (trường hợp tag có dạng "name (count)")
    String tagName = tag;
    if (tag.contains(" (") && tag.endsWith(")")) {
      tagName = tag.substring(0, tag.lastIndexOf(" ("));
    }

    // Get an appropriate tag color based on the theme
    final Color tagColor =
        customColor ?? TagColorManager.instance.getTagColor(tagName);

    // Tăng độ sáng cho tag color trong dark mode
    final Color displayColor = isDarkMode
        ? Color.alphaBlend(Colors.white.withOpacity(0.3), tagColor)
        : tagColor;

    // Add subtle shadow for better visibility in both themes
    final BoxShadow shadow = isDarkMode
        ? BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1))
        : BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1));

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [shadow],
        ),
        child: Chip(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelStyle: TextStyle(
            fontSize: isCompact ? 11 : 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          label: Text(tag),
          backgroundColor: displayColor,
          visualDensity: isCompact ? VisualDensity.compact : null,
          padding:
              isCompact ? const EdgeInsets.all(1) : const EdgeInsets.all(2),
          deleteIconColor: Colors.white,
          deleteIcon:
              onDeleted != null ? const Icon(Icons.close, size: 14) : null,
          onDeleted: onDeleted,
          elevation: 0, // No additional elevation as we have our own shadow
          side: BorderSide(
            color:
                isDarkMode ? Colors.white.withOpacity(0.1) : Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
