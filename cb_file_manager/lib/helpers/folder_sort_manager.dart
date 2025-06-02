import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';

/// Manages per-folder sorting preferences using JSON config files
class FolderSortManager {
  static final FolderSortManager _instance = FolderSortManager._internal();

  // Singleton constructor
  factory FolderSortManager() => _instance;

  FolderSortManager._internal();

  // Cache of sort options for each folder
  final Map<String, SortOption> _folderSortCache = {};

  // In-memory database for system paths
  final Map<String, Map<String, dynamic>> _systemPathConfigs = {};

  // Detect if a path is a system/virtual path (starts with #)
  bool _isSystemPath(String path) {
    return path.startsWith('#');
  }

  /// Get the sort option for a specific folder
  /// If a folder-specific option is found, it's returned
  /// Otherwise returns null (fallback to global preference)
  /// This method is designed to never throw exceptions to avoid blocking folder loading
  Future<SortOption?> getFolderSortOption(String folderPath) async {
    try {
      // Check cache first
      if (_folderSortCache.containsKey(folderPath)) {
        return _folderSortCache[folderPath];
      }

      SortOption? sortOption;

      // Use JSON config for all platforms and paths - NO TIMEOUT for faster loading
      try {
        sortOption = await _getMobileSortOption(folderPath);
      } catch (e) {
        debugPrint('JSON config method failed: $e');
        sortOption = null;
      }

      // Cache the result if found
      if (sortOption != null) {
        _folderSortCache[folderPath] = sortOption;
      }

      return sortOption;
    } catch (e) {
      // Ultimate safety net - never let this method throw exceptions
      debugPrint('Unexpected error in getFolderSortOption: $e');
      return null;
    }
  }

  /// Save the sort option for a specific folder
  /// This method is designed to never throw exceptions to avoid blocking folder operations
  Future<bool> saveFolderSortOption(
      String folderPath, SortOption sortOption) async {
    try {
      bool success = false;

      // Use JSON config for all platforms and paths - NO TIMEOUT for faster saving
      try {
        success = await _saveMobileSortOption(folderPath, sortOption);
        if (success) {
          debugPrint('Successfully saved sort option using JSON config');
        }
      } catch (e) {
        debugPrint('JSON save method failed: $e');
        success = false;
      }

      // Update cache if successful
      if (success) {
        _folderSortCache[folderPath] = sortOption;
      }

      return success;
    } catch (e) {
      // Ultimate safety net - never let this method throw exceptions
      debugPrint('Unexpected error in saveFolderSortOption: $e');
      // Still try to cache it in memory as a last resort
      _folderSortCache[folderPath] = sortOption;
      return false;
    }
  }

  /// Clear the sort option for a specific folder
  Future<bool> clearFolderSortOption(String folderPath) async {
    try {
      bool success = await _clearMobileSortOption(folderPath);

      // Remove from cache if successful
      if (success) {
        _folderSortCache.remove(folderPath);
      }

      return success;
    } catch (e) {
      debugPrint('Error clearing folder sort option: $e');
      return false;
    }
  }

  /// Get sorting option from cbfile_config.json file
  Future<SortOption?> _getMobileSortOption(String folderPath) async {
    try {
      // For system paths, use in-memory database
      if (_isSystemPath(folderPath)) {
        final config = _systemPathConfigs[folderPath];
        if (config != null && config.containsKey('sortOption')) {
          int sortIndex = config['sortOption'];
          if (sortIndex >= 0 && sortIndex < SortOption.values.length) {
            return SortOption.values[sortIndex];
          }
        }
        return null;
      }

      // Normal path - use file-based approach
      final configPath = pathlib.join(folderPath, '.cbfile_config.json');
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        return null;
      }

      final contents = await configFile.readAsString();
      final Map<String, dynamic> config = json.decode(contents);

      if (config.containsKey('sortOption')) {
        int sortIndex = config['sortOption'];
        if (sortIndex >= 0 && sortIndex < SortOption.values.length) {
          return SortOption.values[sortIndex];
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error reading sort option: $e');
      return null;
    }
  }

  /// Save sorting option to cbfile_config.json file
  Future<bool> _saveMobileSortOption(
      String folderPath, SortOption sortOption) async {
    try {
      // For system paths, use in-memory database
      if (_isSystemPath(folderPath)) {
        Map<String, dynamic> config = _systemPathConfigs[folderPath] ?? {};
        config['sortOption'] = sortOption.index;
        _systemPathConfigs[folderPath] = config;
        debugPrint('Saved sort option for system path in memory: $folderPath');
        return true;
      }

      // Normal path - use file-based approach
      final configPath = pathlib.join(folderPath, '.cbfile_config.json');
      final configFile = File(configPath);

      Map<String, dynamic> config = {};

      // Load existing config if it exists
      if (await configFile.exists()) {
        try {
          final contents = await configFile.readAsString();
          if (contents.isNotEmpty) {
            config = json.decode(contents);
          }
        } catch (e) {
          debugPrint('Error reading existing config file: $e');
          // Continue with empty config if there was an error
        }
      }

      // Update sort option
      config['sortOption'] = sortOption.index;

      // Make sure directory exists
      final directory = Directory(folderPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Delete the file first if it exists to avoid permission issues
      if (await configFile.exists()) {
        try {
          await configFile.delete();
        } catch (e) {
          debugPrint('Warning: Failed to delete existing config file: $e');
          // Continue anyway
        }
      }

      // Write config file with pretty printing for better debugging
      final jsonString = const JsonEncoder.withIndent('  ').convert(config);
      await configFile.writeAsString(jsonString);
      debugPrint(
          'Successfully saved config file with sort option: $jsonString');

      // Try to make the file hidden
      if (Platform.isWindows) {
        try {
          final result = await Process.run('attrib', ['+H', configPath]);
          debugPrint(
              'Set hidden attribute on config file (exit code: ${result.exitCode})');
        } catch (e) {
          // Ignore errors, this is just a nice-to-have
          debugPrint('Error making config file hidden: $e');
        }
      } else if (Platform.isAndroid) {
        try {
          // Create a .nomedia file in the same directory to prevent media scan
          final nomediaFile = File(pathlib.join(folderPath, '.nomedia'));
          if (!await nomediaFile.exists()) {
            await nomediaFile.create();
          }
        } catch (e) {
          // Ignore errors, this is just a nice-to-have
          debugPrint('Error creating .nomedia file: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error saving sort option: $e');
      return false;
    }
  }

  /// Clear mobile sort settings
  Future<bool> _clearMobileSortOption(String folderPath) async {
    try {
      // For system paths, use in-memory database
      if (_isSystemPath(folderPath)) {
        _systemPathConfigs.remove(folderPath);
        debugPrint(
            'Cleared sort option for system path from memory: $folderPath');
        return true;
      }

      // Normal path - use file-based approach
      final configPath = pathlib.join(folderPath, '.cbfile_config.json');
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        return true; // Nothing to clear
      }

      Map<String, dynamic> config = {};

      // Load existing config
      final contents = await configFile.readAsString();
      config = json.decode(contents);

      // Remove sort option
      config.remove('sortOption');

      // If config is now empty, delete the file
      if (config.isEmpty) {
        await configFile.delete();
      } else {
        // Otherwise, write back the updated config
        await configFile.writeAsString(json.encode(config));
      }

      return true;
    } catch (e) {
      debugPrint('Error clearing sort settings: $e');
      return false;
    }
  }
}
