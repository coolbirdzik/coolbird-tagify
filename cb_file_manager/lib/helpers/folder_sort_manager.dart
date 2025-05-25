import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';

/// Manages per-folder sorting preferences
/// On Windows, uses desktop.ini
/// On other platforms, uses a hidden cbfile_config.json file
class FolderSortManager {
  static final FolderSortManager _instance = FolderSortManager._internal();

  // Singleton constructor
  factory FolderSortManager() => _instance;

  FolderSortManager._internal();

  // Check if the device is running Windows
  bool get isWindows => Platform.isWindows;

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
  Future<SortOption?> getFolderSortOption(String folderPath) async {
    // Check cache first
    if (_folderSortCache.containsKey(folderPath)) {
      return _folderSortCache[folderPath];
    }

    SortOption? sortOption;

    // For system paths like #tags or #tag:xyz, always use the mobile approach
    if (_isSystemPath(folderPath)) {
      sortOption = await _getMobileSortOption(folderPath);
    } else if (isWindows) {
      // On Windows, try both methods for maximum reliability
      sortOption = await _getWindowsSortOption(folderPath);

      // If Windows desktop.ini method failed, try the JSON config file as fallback
      if (sortOption == null) {
        debugPrint(
            'Windows desktop.ini method failed, trying JSON config fallback');
        sortOption = await _getMobileSortOption(folderPath);
      }
    } else {
      sortOption = await _getMobileSortOption(folderPath);
    }

    // Cache the result if found
    if (sortOption != null) {
      _folderSortCache[folderPath] = sortOption;
    }

    return sortOption;
  }

  /// Save the sort option for a specific folder
  Future<bool> saveFolderSortOption(
      String folderPath, SortOption sortOption) async {
    bool success = false;

    // For system paths like #tags or #tag:xyz, always use the mobile approach
    if (_isSystemPath(folderPath)) {
      // For system paths, we'll just store in memory
      _folderSortCache[folderPath] = sortOption;
      success = true;
      debugPrint(
          'Saved sort option for system path: $folderPath (in memory only)');
    } else if (isWindows) {
      success = await _saveWindowsSortOption(folderPath, sortOption);
    } else {
      success = await _saveMobileSortOption(folderPath, sortOption);
    }

    // Update cache if successful
    if (success) {
      _folderSortCache[folderPath] = sortOption;
    }

    return success;
  }

  /// Clear the sort option for a specific folder
  Future<bool> clearFolderSortOption(String folderPath) async {
    bool success = false;

    // For system paths, just remove from cache
    if (_isSystemPath(folderPath)) {
      _folderSortCache.remove(folderPath);
      success = true;
      debugPrint('Cleared sort option for system path: $folderPath');
    } else if (isWindows) {
      success = await _clearWindowsSortOption(folderPath);
    } else {
      success = await _clearMobileSortOption(folderPath);
    }

    // Remove from cache if successful
    if (success) {
      _folderSortCache.remove(folderPath);
    }

    return success;
  }

  /// Get sorting option from Windows desktop.ini file
  Future<SortOption?> _getWindowsSortOption(String folderPath) async {
    try {
      final desktopIniPath = pathlib.join(folderPath, 'desktop.ini');
      final desktopIniFile = File(desktopIniPath);

      if (!await desktopIniFile.exists()) {
        debugPrint('desktop.ini not found in $folderPath');
        return null;
      }

      final contents = await desktopIniFile.readAsString();
      debugPrint('Reading desktop.ini from $folderPath: \n$contents');

      final lines = contents.split('\n');

      // Parse the INI file format
      String? sortBy;
      String? sortDescending;
      bool inShellClassInfo = false;

      for (var line in lines) {
        line = line.trim();

        // Kiểm tra xem có đang ở trong section ShellClassInfo hay không
        if (line == '[.ShellClassInfo]') {
          inShellClassInfo = true;
          continue;
        } else if (line.startsWith('[') && line.endsWith(']')) {
          inShellClassInfo = false;
          continue;
        }

        // Chỉ đọc các cài đặt sắp xếp từ section .ShellClassInfo
        if (inShellClassInfo) {
          if (line.startsWith('SortByAttribute=')) {
            sortBy = line.substring('SortByAttribute='.length).trim();
            debugPrint('Found SortByAttribute=$sortBy');
          } else if (line.startsWith('SortDescending=')) {
            sortDescending = line.substring('SortDescending='.length).trim();
            debugPrint('Found SortDescending=$sortDescending');
          }
        }
      }

      // Nếu không tìm thấy trong section, thử tìm bất kỳ nơi nào trong file
      if (sortBy == null) {
        for (var line in lines) {
          line = line.trim();
          if (line.contains('SortByAttribute=')) {
            sortBy = line.split('=')[1].trim();
            debugPrint('Found SortByAttribute=$sortBy outside of section');
          } else if (line.contains('SortDescending=')) {
            sortDescending = line.split('=')[1].trim();
            debugPrint(
                'Found SortDescending=$sortDescending outside of section');
          }
        }
      }

      // Convert Windows Explorer sort settings to our SortOption
      if (sortBy != null) {
        // Mặc định là sắp xếp tăng dần nếu không có giá trị
        bool descending = sortDescending == '1';
        debugPrint(
            'Converting Windows sort: sortBy=$sortBy, descending=$descending');

        switch (sortBy) {
          case '0': // Sort by name
            return descending ? SortOption.nameDesc : SortOption.nameAsc;
          case '1': // Sort by size
            return descending ? SortOption.sizeDesc : SortOption.sizeAsc;
          case '2': // Sort by type
            return descending ? SortOption.typeDesc : SortOption.typeAsc;
          case '3': // Sort by date modified
            return descending ? SortOption.dateDesc : SortOption.dateAsc;
          case '4': // Sort by date created
            return descending
                ? SortOption.dateCreatedDesc
                : SortOption.dateCreatedAsc;
          case '5': // Sort by attributes
            return descending
                ? SortOption.attributesDesc
                : SortOption.attributesAsc;
          default:
            // Thử phân tích số nếu có ký tự không mong muốn
            try {
              int numericValue =
                  int.parse(sortBy.replaceAll(RegExp(r'[^0-9]'), ''));
              switch (numericValue) {
                case 0:
                  return descending ? SortOption.nameDesc : SortOption.nameAsc;
                case 1:
                  return descending ? SortOption.sizeDesc : SortOption.sizeAsc;
                case 2:
                  return descending ? SortOption.typeDesc : SortOption.typeAsc;
                case 3:
                  return descending ? SortOption.dateDesc : SortOption.dateAsc;
                case 4:
                  return descending
                      ? SortOption.dateCreatedDesc
                      : SortOption.dateCreatedAsc;
                case 5:
                  return descending
                      ? SortOption.attributesDesc
                      : SortOption.attributesAsc;
                default:
                  debugPrint('Unknown numeric sortBy value: $numericValue');
                  return null;
              }
            } catch (e) {
              debugPrint('Failed to parse sortBy value: $sortBy, error: $e');
              return null;
            }
        }
      }

      debugPrint('No sort settings found in desktop.ini');
      return null;
    } catch (e) {
      debugPrint('Error reading desktop.ini: $e');
      return null;
    }
  }

  /// Save sorting option to Windows desktop.ini file
  Future<bool> _saveWindowsSortOption(
      String folderPath, SortOption sortOption) async {
    try {
      final desktopIniPath = pathlib.join(folderPath, 'desktop.ini');
      final desktopIniFile = File(desktopIniPath);

      debugPrint('Saving sort option ${sortOption.name} to $desktopIniPath');

      // Map our SortOption to Windows Explorer settings
      String sortBy = '0'; // Default to name sort
      String sortDescending = '0'; // Default to ascending

      switch (sortOption) {
        case SortOption.nameAsc:
          sortBy = '0';
          sortDescending = '0';
          break;
        case SortOption.nameDesc:
          sortBy = '0';
          sortDescending = '1';
          break;
        case SortOption.sizeAsc:
          sortBy = '1';
          sortDescending = '0';
          break;
        case SortOption.sizeDesc:
          sortBy = '1';
          sortDescending = '1';
          break;
        case SortOption.typeAsc:
          sortBy = '2';
          sortDescending = '0';
          break;
        case SortOption.typeDesc:
          sortBy = '2';
          sortDescending = '1';
          break;
        case SortOption.dateAsc:
          sortBy = '3';
          sortDescending = '0';
          break;
        case SortOption.dateDesc:
          sortBy = '3';
          sortDescending = '1';
          break;
        case SortOption.dateCreatedAsc:
          sortBy = '4'; // Windows supports date created
          sortDescending = '0';
          break;
        case SortOption.dateCreatedDesc:
          sortBy = '4'; // Windows supports date created
          sortDescending = '1';
          break;
        case SortOption.extensionAsc:
          sortBy = '2'; // Use type (same as extension in Windows)
          sortDescending = '0';
          break;
        case SortOption.extensionDesc:
          sortBy = '2'; // Use type (same as extension in Windows)
          sortDescending = '1';
          break;
        case SortOption.attributesAsc:
          sortBy = '5'; // Special sort for attributes
          sortDescending = '0';
          break;
        case SortOption.attributesDesc:
          sortBy = '5'; // Special sort for attributes
          sortDescending = '1';
          break;
      }

      debugPrint(
          'Mapped sort option to: SortByAttribute=$sortBy, SortDescending=$sortDescending');

      // Simpler approach: Just create a new desktop.ini file with the required settings
      // This avoids issues with parsing and manipulating the existing file
      String fileContent = '''[.ShellClassInfo]
IconFile=
IconIndex=0
ConfirmFileOp=0
InfoTip=
SortByAttribute=$sortBy
SortDescending=$sortDescending
''';

      // Make sure the directory exists before saving the file
      final directory = Directory(folderPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Try to delete the file first to avoid any permission issues with overwriting
      if (await desktopIniFile.exists()) {
        try {
          await desktopIniFile.delete();
          debugPrint('Deleted existing desktop.ini file');
        } catch (e) {
          debugPrint('Error deleting existing desktop.ini file: $e');
          // Continue anyway, we'll try to overwrite it
        }
      }

      // Write the new file
      await desktopIniFile.writeAsString(fileContent);
      debugPrint(
          'Successfully wrote desktop.ini file with content:\n$fileContent');

      // As a backup, also save the sort option to our config file format
      // This ensures we have a fallback if desktop.ini doesn't work
      await _saveMobileSortOption(folderPath, sortOption);

      // Set file attributes (hidden, system) using more robust method
      if (Platform.isWindows) {
        try {
          // First, make the folder have the system attribute
          final folderResult = await Process.run('attrib', ['+S', folderPath]);
          debugPrint(
              'Set attribute +S on folder $folderPath (exit code: ${folderResult.exitCode})');
          debugPrint('Result: ${folderResult.stdout}');
          if (folderResult.stderr.isNotEmpty) {
            debugPrint('Error output: ${folderResult.stderr}');
          }

          // Then set attributes on the desktop.ini file
          final fileResult =
              await Process.run('attrib', ['+S', '+H', desktopIniPath]);
          debugPrint(
              'Set attributes +S +H on $desktopIniPath (exit code: ${fileResult.exitCode})');
          debugPrint('Result: ${fileResult.stdout}');
          if (fileResult.stderr.isNotEmpty) {
            debugPrint('Error output: ${fileResult.stderr}');
          }
        } catch (e) {
          debugPrint('Error setting desktop.ini attributes: $e');
          // Continue anyway as the settings might still work
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error saving desktop.ini: $e');
      return false;
    }
  }

  /// Clear Windows sort settings from desktop.ini
  Future<bool> _clearWindowsSortOption(String folderPath) async {
    try {
      final desktopIniPath = pathlib.join(folderPath, 'desktop.ini');
      final desktopIniFile = File(desktopIniPath);

      if (!await desktopIniFile.exists()) {
        return true; // Nothing to clear
      }

      final contents = await desktopIniFile.readAsString();
      final lines = contents.split('\n');

      List<String> newLines = [];
      for (var line in lines) {
        if (!line.contains('SortByAttribute=') &&
            !line.contains('SortDescending=')) {
          newLines.add(line);
        }
      }

      // Only write back if file had sortable content
      if (newLines.length != lines.length) {
        await desktopIniFile.writeAsString(newLines.join('\n'));
      }

      return true;
    } catch (e) {
      debugPrint('Error clearing desktop.ini sort settings: $e');
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
