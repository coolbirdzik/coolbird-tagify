import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'windows_app_icon.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

class AppInfo {
  final String packageName;
  final String appName;
  final Widget icon;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.icon,
  });
}

class ExternalAppHelper {
  static const MethodChannel _channel =
      MethodChannel('cb_file_manager/external_apps');

  /// Cache for Windows app icons
  static final Map<String, Widget> _windowsAppIconCache = {};

  /// Get list of installed apps that can handle this file type
  static Future<List<AppInfo>> getInstalledAppsForFile(String filePath) async {
    if (Platform.isAndroid) {
      return _getAndroidAppsForFile(filePath);
    } else if (Platform.isWindows) {
      return _getWindowsAppsForFile(filePath);
    }
    return [];
  }

  /// Open file with a specific app
  static Future<bool> openFileWithApp(
      String filePath, String packageName) async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('openFileWithApp', {
          'filePath': filePath,
          'packageName': packageName,
        });
        return result ?? false;
      } else if (Platform.isWindows) {
        // Special case for shell_open
        if (packageName == 'shell_open') {
          final process = await Process.start('explorer', [filePath]);
          await process.exitCode;
          return true;
        } else {
          // On Windows, the packageName is actually the path to the executable
          final result = Process.runSync(packageName, [filePath]);
          return result.exitCode == 0;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error opening file with app: $e');
      return false;
    }
  }

  /// Get Android apps that can handle this file type
  static Future<List<AppInfo>> _getAndroidAppsForFile(String filePath) async {
    try {
      final extension = filePath.split('.').last.toLowerCase();
      final List<dynamic> result =
          await _channel.invokeMethod('getInstalledAppsForFile', {
        'filePath': filePath,
        'extension': extension,
      });

      return result.map((app) {
        return AppInfo(
          packageName: app['packageName'],
          appName: app['appName'],
          icon: app['iconBytes'] != null
              ? Image.memory(app['iconBytes'], width: 36, height: 36)
              : Icon(Icons.android, size: 36),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting Android apps: $e');
      return [];
    }
  }

  /// Get Windows apps that can handle this file type
  static Future<List<AppInfo>> _getWindowsAppsForFile(String filePath) async {
    try {
      final List<AppInfo> apps = [];
      final extension = filePath.split('.').last.toLowerCase();

      // First, get the officially associated app
      String? associatedAppPath =
          await WindowsAppIcon.getAssociatedAppPath(extension);
      if (associatedAppPath != null && associatedAppPath.isNotEmpty) {
        final String appName = _getAppNameFromPath(associatedAppPath);
        final Widget appIcon = await _getWindowsAppIcon(associatedAppPath);

        apps.add(AppInfo(
          packageName: associatedAppPath,
          appName: appName,
          icon: appIcon,
        ));
      }

      // Add common applications based on file type
      List<Map<String, String>> appPaths = [];

      if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
        appPaths = [
          {'path': 'C:\\Windows\\system32\\mspaint.exe', 'name': 'Paint'},
          {
            'path':
                'C:\\Program Files\\Microsoft Office\\root\\Office16\\OfficeLens.exe',
            'name': 'Office Lens'
          },
          {
            'path': 'C:\\Program Files\\Windows Photo Viewer\\PhotoViewer.dll',
            'name': 'Photo Viewer'
          },
        ];
      } else if (['mp4', 'avi', 'mkv', 'mov', 'wmv'].contains(extension)) {
        appPaths = [
          {
            'path': 'C:\\Program Files\\Windows Media Player\\wmplayer.exe',
            'name': 'Windows Media Player'
          },
          {
            'path': 'C:\\Program Files\\VideoLAN\\VLC\\vlc.exe',
            'name': 'VLC Media Player'
          },
          {
            'path': 'C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe',
            'name': 'VLC Media Player'
          },
        ];
      } else if (['pdf'].contains(extension)) {
        appPaths = [
          {
            'path':
                'C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe',
            'name': 'Adobe Acrobat'
          },
          {
            'path':
                'C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe',
            'name': 'Adobe Reader'
          },
          {
            'path':
                'C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE',
            'name': 'Microsoft Word'
          },
        ];
      } else if (['doc', 'docx'].contains(extension)) {
        appPaths = [
          {
            'path':
                'C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE',
            'name': 'Microsoft Word'
          },
          {
            'path':
                'C:\\Program Files (x86)\\Microsoft Office\\root\\Office16\\WINWORD.EXE',
            'name': 'Microsoft Word'
          },
        ];
      } else if (['xls', 'xlsx'].contains(extension)) {
        appPaths = [
          {
            'path':
                'C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE',
            'name': 'Microsoft Excel'
          },
          {
            'path':
                'C:\\Program Files (x86)\\Microsoft Office\\root\\Office16\\EXCEL.EXE',
            'name': 'Microsoft Excel'
          },
        ];
      } else if (['ppt', 'pptx'].contains(extension)) {
        appPaths = [
          {
            'path':
                'C:\\Program Files\\Microsoft Office\\root\\Office16\\POWERPNT.EXE',
            'name': 'Microsoft PowerPoint'
          },
          {
            'path':
                'C:\\Program Files (x86)\\Microsoft Office\\root\\Office16\\POWERPNT.EXE',
            'name': 'Microsoft PowerPoint'
          },
        ];
      }

      // Add applications if they exist on the system
      for (final appInfo in appPaths) {
        await _addWindowsAppIfExists(apps, appInfo['path']!, appInfo['name']!);
      }

      // Add default "Open with" option that uses shell execution
      apps.add(AppInfo(
        packageName: 'shell_open',
        appName: 'Default Program',
        icon: const Icon(Icons.open_in_new, size: 36),
      ));

      return apps;
    } catch (e) {
      debugPrint('Error getting Windows apps: $e');
      return [];
    }
  }

  /// Add a Windows app to the list if it exists
  static Future<void> _addWindowsAppIfExists(
      List<AppInfo> apps, String execPath, String appName) async {
    if (File(execPath).existsSync()) {
      apps.add(AppInfo(
        packageName: execPath,
        appName: appName,
        icon: await _getWindowsAppIcon(execPath),
      ));
    }
  }

  /// Get icon for a Windows app
  static Future<Widget> _getWindowsAppIcon(String execPath) async {
    // Check cache first
    if (_windowsAppIconCache.containsKey(execPath)) {
      return _windowsAppIconCache[execPath]!;
    }

    try {
      // Try to extract native icon
      ui.Image? nativeIcon = await WindowsAppIcon.extractIconFromFile(execPath);

      if (nativeIcon != null) {
        // Create image widget using the native icon
        final Widget iconWidget = RawImage(
          image: nativeIcon,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        );

        _windowsAppIconCache[execPath] = iconWidget;
        return iconWidget;
      }
    } catch (e) {
      debugPrint('Error getting Windows app icon: $e');
    }

    // Fallback to using appropriate built-in icons based on app name
    IconData iconData;
    final String filename = execPath.split('\\').last.toLowerCase();

    if (filename.contains('paint')) {
      iconData = Icons.brush;
    } else if (filename.contains('word')) {
      iconData = Icons.description;
    } else if (filename.contains('excel')) {
      iconData = Icons.table_chart;
    } else if (filename.contains('powerpnt')) {
      iconData = Icons.slideshow;
    } else if (filename.contains('vlc') || filename.contains('wmplayer')) {
      iconData = Icons.video_library;
    } else if (filename.contains('acrobat') || filename.contains('reader')) {
      iconData = Icons.picture_as_pdf;
    } else {
      iconData = Icons.app_shortcut;
    }

    final Widget iconWidget = Icon(iconData, size: 36);
    _windowsAppIconCache[execPath] = iconWidget;
    return iconWidget;
  }

  /// Get application name from executable path
  static String _getAppNameFromPath(String execPath) {
    try {
      // Extract filename without extension
      final filename = execPath.split('\\').last;
      final appName = filename.split('.').first;

      // Try to make it more readable
      String readable = appName.replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (Match m) => '${m[1]} ${m[2]}');

      // Capitalize first letter of each word
      readable = readable.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');

      return readable;
    } catch (e) {
      return execPath.split('\\').last;
    }
  }

  /// Open file with Android system chooser dialog
  static Future<bool> openWithSystemChooser(String filePath) async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }

      final result = await _channel.invokeMethod('openWithSystemChooser', {
        'filePath': filePath,
      });

      return result ?? false;
    } catch (e) {
      debugPrint('Error opening file with system chooser: $e');
      return false;
    }
  }
}
