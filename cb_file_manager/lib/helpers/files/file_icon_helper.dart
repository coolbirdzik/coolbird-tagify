import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'external_app_helper.dart';
import 'windows_app_icon.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

/// Helper class to get file icons, including app icons for file types
class FileIconHelper {
  // Cache for file extensions icons
  static final Map<String, Widget> _iconCache = {};

  // Cache for app paths by extension
  static final Map<String, String> _appPathCache = {};

  /// Get an icon for a file. If possible, return the icon of the default application.
  /// If no default app is found, return an appropriate icon based on file type.
  static Future<Widget> getIconForFile(File file, {double size = 24}) async {
    final String extension = _getFileExtension(file);

    // Check if we already have a cached icon for this extension
    final String cacheKey = '${extension}_$size';
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }

    // For images and videos, return a generic icon
    if (_isImageFile(extension)) {
      final icon = Icon(EvaIcons.imageOutline, size: size, color: Colors.blue);
      _iconCache[cacheKey] = icon;
      return icon;
    }

    if (_isVideoFile(extension)) {
      final icon = Icon(EvaIcons.videoOutline, size: size, color: Colors.red);
      _iconCache[cacheKey] = icon;
      return icon;
    }

    // Try to get the application icon for this file type
    try {
      String? appPath;

      // Check cache first
      if (_appPathCache.containsKey(extension)) {
        appPath = _appPathCache[extension];
      } else {
        // Get the default application path for this extension
        appPath = await WindowsAppIcon.getAssociatedAppPath(extension);
        if (appPath != null && appPath.isNotEmpty) {
          _appPathCache[extension] = appPath;
        }
      }

      if (appPath != null && appPath.isNotEmpty) {
        // Get the default app info
        final apps = await ExternalAppHelper.getInstalledAppsForFile(file.path);
        if (apps.isNotEmpty) {
          // Use the first app icon
          final Widget appIcon = SizedBox(
            width: size,
            height: size,
            child: apps[0].icon,
          );
          _iconCache[cacheKey] = appIcon;
          return appIcon;
        }
      }
    } catch (e) {
      debugPrint('Error getting app icon: $e');
    }

    // Fallback to generic file type icons
    Widget icon;

    if (_isAudioFile(extension)) {
      icon = Icon(EvaIcons.musicOutline, size: size, color: Colors.purple);
    } else if (_isDocumentFile(extension)) {
      icon = Icon(EvaIcons.fileTextOutline, size: size, color: Colors.indigo);
    } else if (_isSpreadsheetFile(extension)) {
      icon = Icon(EvaIcons.gridOutline, size: size, color: Colors.green);
    } else if (_isPresentationFile(extension)) {
      icon = Icon(EvaIcons.fileOutline, size: size, color: Colors.orange);
    } else if (_isPdfFile(extension)) {
      icon = Icon(EvaIcons.fileOutline, size: size, color: Colors.red[800]);
    } else {
      icon = Icon(EvaIcons.fileOutline, size: size, color: Colors.grey);
    }

    _iconCache[cacheKey] = icon;
    return icon;
  }

  /// Get the default application icon for a file extension
  static Future<Widget?> getDefaultAppIconForExtension(String extension,
      {double size = 24}) async {
    try {
      String? appPath;

      // Check cache first
      if (_appPathCache.containsKey(extension)) {
        appPath = _appPathCache[extension];
      } else {
        // Get the default application path for this extension
        appPath = await WindowsAppIcon.getAssociatedAppPath(extension);
        if (appPath != null && appPath.isNotEmpty) {
          _appPathCache[extension] = appPath;
        }
      }

      if (appPath != null && appPath.isNotEmpty) {
        // Sử dụng phương thức public để lấy biểu tượng ứng dụng
        final tempFile =
            File('temp.$extension'); // Dummy file với extension cần thiết
        final apps =
            await ExternalAppHelper.getInstalledAppsForFile(tempFile.path);
        if (apps.isNotEmpty) {
          return SizedBox(
            width: size,
            height: size,
            child: apps[0].icon,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting default app icon: $e');
    }

    return null;
  }

  /// Clear the icon cache
  static void clearCache() {
    _iconCache.clear();
  }

  // Helper methods to identify file types using FileTypeUtils
  static String _getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  static bool _isImageFile(String extension) {
    return FileTypeUtils.isImageFile('dummy.$extension');
  }

  static bool _isVideoFile(String extension) {
    return FileTypeUtils.isVideoFile('dummy.$extension');
  }

  static bool _isAudioFile(String extension) {
    return FileTypeUtils.isAudioFile('dummy.$extension');
  }

  static bool _isDocumentFile(String extension) {
    return FileTypeUtils.isDocumentFile('dummy.$extension');
  }

  static bool _isSpreadsheetFile(String extension) {
    return FileTypeUtils.isSpreadsheetFile('dummy.$extension');
  }

  static bool _isPresentationFile(String extension) {
    return FileTypeUtils.isPresentationFile('dummy.$extension');
  }

  static bool _isPdfFile(String extension) {
    return FileTypeUtils.isDocumentFile('dummy.$extension') &&
        extension == 'pdf';
  }
}
