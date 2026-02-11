import 'dart:io';

import 'package:flutter/services.dart';

/// Helper class for Windows-native file operations with progress dialog
class WindowsFileOperations {
  static const MethodChannel _channel =
      MethodChannel('cb_file_manager/file_operations');

  /// Check if native Windows file operations are available
  static bool get isAvailable => Platform.isWindows;

  /// Copy files/folders to destination using Windows native IFileOperation
  /// This shows the native Windows copy progress dialog
  static Future<bool> copyItems({
    required List<String> sources,
    required String destination,
  }) async {
    if (!isAvailable || sources.isEmpty) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'copyItems',
        {
          'sources': sources,
          'destination': destination,
        },
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Move files/folders to destination using Windows native IFileOperation
  /// This shows the native Windows move progress dialog
  static Future<bool> moveItems({
    required List<String> sources,
    required String destination,
  }) async {
    if (!isAvailable || sources.isEmpty) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'moveItems',
        {
          'sources': sources,
          'destination': destination,
        },
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
