import 'package:flutter/material.dart';

class BreadcrumbNavigation extends StatelessWidget {
  final String currentPath;
  final Function(String) onPathTap;

  const BreadcrumbNavigation({
    Key? key,
    required this.currentPath,
    required this.onPathTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> pathParts = _getPathParts(currentPath);
    final List<Widget> breadcrumbs = [];

    // Build breadcrumbs
    for (int i = 0; i < pathParts.length; i++) {
      final isLast = i == pathParts.length - 1;
      final partPath = _buildPartialPath(pathParts, i);

      // Add separator except for the first item
      if (i > 0) {
        breadcrumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(Icons.chevron_right, size: 16),
          ),
        );
      }

      breadcrumbs.add(
        InkWell(
          onTap: isLast ? null : () => onPathTap(partPath),
          child: Text(
            i == 0 ? 'Home' : pathParts[i],
            style: TextStyle(
              color: isLast ? Colors.grey[700] : Colors.blue,
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(children: breadcrumbs),
      ),
    );
  }

  List<String> _getPathParts(String path) {
    final parts = path.split('/');
    // Filter out empty parts and normalize
    return parts.where((part) => part.isNotEmpty).toList();
  }

  String _buildPartialPath(List<String> parts, int endIndex) {
    final selectedParts = parts.sublist(0, endIndex + 1);
    return '/${selectedParts.join('/')}';
  }
}
