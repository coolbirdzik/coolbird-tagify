import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';

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
    final List<BreadcrumbItem> pathParts = _getPathParts(currentPath);
    final List<Widget> breadcrumbs = [];

    // Build breadcrumbs
    for (int i = 0; i < pathParts.length; i++) {
      final isLast = i == pathParts.length - 1;
      final partPath = pathParts[i].path;
      final displayName = pathParts[i].displayName;

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
            displayName,
            style: TextStyle(
              color: isLast ? Colors.grey[700] : Colors.blue,
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(children: breadcrumbs),
        ),
      ),
    );
  }

  List<BreadcrumbItem> _getPathParts(String path) {
    List<BreadcrumbItem> result = [];

    // Special case for root
    if (path == '/') {
      return [BreadcrumbItem('/', 'Root')];
    }

    // Special case for Windows drives
    if (Platform.isWindows && path.contains(':\\')) {
      String driveLetter = path.split(r'\')[0];
      result.add(BreadcrumbItem('$driveLetter\\', driveLetter));

      final parts = path.substring(3).split(r'\');
      String currentPath = '$driveLetter\\';

      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        currentPath += '${parts[i]}\\';
        result.add(BreadcrumbItem(currentPath, parts[i]));
      }

      return result;
    }

    // For Unix-like paths
    final parts = path.split('/');

    // Add root item
    result.add(BreadcrumbItem('/', 'Root'));

    // Special handling for common Android paths
    if (parts.length > 2 && parts[1] == 'storage') {
      if (parts.length > 3 && parts[2] == 'emulated' && parts[3] == '0') {
        // /storage/emulated/0 -> Internal Storage
        String currentPath = '/storage/emulated/0';
        result.add(BreadcrumbItem(currentPath, 'Internal Storage'));

        for (int i = 4; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          currentPath += '/${parts[i]}';
          result.add(BreadcrumbItem(currentPath, parts[i]));
        }

        return result;
      } else if (parts.length > 2 && parts[2] != 'emulated') {
        // /storage/XXXX-XXXX -> SD Card
        String sdName = parts[2];
        String currentPath = '/storage/$sdName';
        result.add(BreadcrumbItem(currentPath, 'SD Card ($sdName)'));

        for (int i = 3; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          currentPath += '/${parts[i]}';
          result.add(BreadcrumbItem(currentPath, parts[i]));
        }

        return result;
      }
    }

    // Default handling for all other paths
    String currentPath = '';
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      currentPath += '/${parts[i]}';
      result.add(BreadcrumbItem(currentPath, parts[i]));
    }

    return result;
  }
}

/// Class to hold both the complete path and display name for breadcrumb items
class BreadcrumbItem {
  final String path;
  final String displayName;

  BreadcrumbItem(this.path, this.displayName);
}
