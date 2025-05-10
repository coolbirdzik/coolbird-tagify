import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowsAppIcon {
  static const MethodChannel _channel =
      MethodChannel('cb_file_manager/app_icon');

  /// Cache for extracted icons
  static final Map<String, ui.Image> _iconCache = {};

  /// Get the associated application for a file extension
  static Future<String?> getAssociatedAppPath(String extension) async {
    if (!Platform.isWindows) return null;

    try {
      final String? result =
          await _channel.invokeMethod<String>('getAssociatedAppPath', {
        'extension': extension,
      });
      return result;
    } catch (e) {
      debugPrint('Error getting associated app path: $e');
      return null;
    }
  }

  /// Extract icon from an executable file
  static Future<ui.Image?> extractIconFromFile(String exePath) async {
    if (!Platform.isWindows) return null;

    // Check cache first
    if (_iconCache.containsKey(exePath)) {
      return _iconCache[exePath];
    }

    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('extractIconFromFile', {
        'exePath': exePath,
      });

      if (result != null) {
        final Uint8List iconData = result['iconData'] as Uint8List;
        final int width = result['width'] as int;
        final int height = result['height'] as int;

        // Convert BGRA to RGBA format
        final Uint8List rgbaData = Uint8List(iconData.length);
        for (int i = 0; i < iconData.length; i += 4) {
          rgbaData[i] = iconData[i + 2]; // R (from B)
          rgbaData[i + 1] = iconData[i + 1]; // G
          rgbaData[i + 2] = iconData[i]; // B (from R)
          rgbaData[i + 3] = iconData[i + 3]; // A
        }

        final Completer<ui.Image> completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          rgbaData,
          width,
          height,
          ui.PixelFormat.rgba8888,
          completer.complete,
        );

        final ui.Image image = await completer.future;
        _iconCache[exePath] = image;
        return image;
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting icon: $e');
      return null;
    }
  }

  /// Get the application icon for a file extension
  static Future<ui.Image?> getIconForExtension(String extension) async {
    if (!Platform.isWindows) return null;

    final String? appPath = await getAssociatedAppPath(extension);
    if (appPath == null || appPath.isEmpty) return null;

    return extractIconFromFile(appPath);
  }
}
