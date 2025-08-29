import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:path_provider/path_provider.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// A utility class for managing file tags globally
///
/// Tags are stored in a central global tags file instead of per directory
/// or in ObjectBox database if enabled
class TagManager {
  // Singleton instance
  static TagManager? _instance;

  // In-memory cache to improve performance
  static final Map<String, List<String>> _tagsCache = {};

  // Global tags file name
  static const String globalTagsFilename = 'coolbird_global_tags.json';

  // Path to the global tags file (initialized lazily)
  static String? _globalTagsPath;

  // Database manager for ObjectBox storage
  static DatabaseManager? _databaseManager;

  // Flag to determine if we're using ObjectBox
  static bool _useObjectBox = false;

  // User preferences for checking if ObjectBox is enabled
  static final UserPreferences _preferences = UserPreferences.instance;

  // Thêm một StreamController để phát thông báo khi tags thay đổi
  static final StreamController<String> _tagChangeController =
      StreamController<String>.broadcast();

  // Stream công khai để lắng nghe thay đổi tag
  static Stream<String> get onTagChanged => _tagChangeController.stream;

  // Cache for tags to avoid constantly reading from files
  static final Map<String, List<String>> _tagCache = {};

  // Add a stream controller to notify tag changes globally
  final _tagChangesController = StreamController<String>.broadcast();

  // Stream for global tag changes that any widget can listen to
  Stream<String> get onGlobalTagChanged => _tagChangesController.stream;

  // Method to notify the app about tag changes
  void notifyTagChanged(String filePath) {
    debugPrint("TagManager: Notifying tag change for path: $filePath");
    // Add to instance stream
    _tagChangesController.add(filePath);

    // Also add to the static stream that FileGridItem is listening to
    _tagChangeController.add(filePath);
  }

  /// Dispose resources
  void dispose() {
    _tagChangesController.close();
    _tagChangeController.close();
  }

  // Private singleton constructor
  TagManager._();

  // Singleton instance getter
  static TagManager get instance {
    if (_instance == null) {
      _instance = TagManager._();
      initialize();
    }
    return _instance!;
  }

  /// Check if a file has a specific tag
  ///
  /// This is a synchronous version that uses the cache
  bool hasTag(FileSystemEntity entity, String tagQuery) {
    if (tagQuery.isEmpty) return false;
    if (_tagsCache.containsKey(entity.path)) {
      final tags = _tagsCache[entity.path]!;
      return tags
          .any((tag) => tag.toLowerCase().contains(tagQuery.toLowerCase()));
    }
    return false;
  }

  /// Get frequently used tags (most common tags in the system)
  /// Returns a map of tags with their usage count
  Future<Map<String, int>> getPopularTags({int limit = 10}) async {
    await initialize();

    final Map<String, int> tagFrequency = {};

    if (_useObjectBox && _databaseManager != null) {
      // Get all unique tags from ObjectBox
      final allUniqueTags = await _databaseManager!.getAllUniqueTags();

      // Count how many files each tag appears in
      for (final tag in allUniqueTags) {
        final files = await _databaseManager!.findFilesByTag(tag);
        tagFrequency[tag] = files.length;
      }
    } else {
      // Use original implementation for JSON file
      final tagsData = await _loadGlobalTags();

      // Count frequency of each tag
      for (final List<dynamic> tagList in tagsData.values) {
        for (final tag in tagList) {
          if (tag is String) {
            tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
          }
        }
      }
    }

    // Sort by frequency and take the top ones
    final sortedTags = tagFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, int> result = {};
    for (int i = 0; i < sortedTags.length && i < limit; i++) {
      result[sortedTags[i].key] = sortedTags[i].value;
    }

    return result;
  }

  /// Returns tags that match a query string
  Future<List<String>> searchTags(String query) async {
    if (query.isEmpty) return [];

    final allTags = await getAllUniqueTags("");
    return allTags
        .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Initialize the global tags system by determining the storage path
  static Future<void> initialize() async {
    try {
      // Check if ObjectBox is enabled from user preferences
      await _preferences.init();
      _useObjectBox = _preferences.isUsingObjectBox();

      if (_useObjectBox) {
        // Initialize database manager - get instance but check if it's already initialized
        _databaseManager = DatabaseManager.getInstance();
        if (!_databaseManager!.isInitialized()) {
          await _databaseManager!.initialize();
        }
      } else {
        if (_globalTagsPath != null) return; // Already initialized

        // Initialize JSON storage
        final appDir = await getApplicationDocumentsDirectory();
        final coolbirdDir = Directory('${appDir.path}/coolbird');

        // Create the directory if it doesn't exist
        if (!await coolbirdDir.exists()) {
          await coolbirdDir.create(recursive: true);
        }

        _globalTagsPath = '${coolbirdDir.path}/$globalTagsFilename';
      }
    } catch (e) {
      _useObjectBox = false;

      // Fallback to a location in the user's home directory
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      _globalTagsPath = '$home/$globalTagsFilename';
    }
  }

  /// Gets the path to the global tags file
  static Future<String> _getGlobalTagsFilePath() async {
    await initialize();
    return _globalTagsPath!;
  }

  /// Load all tags from the global tags file
  static Future<Map<String, dynamic>> _loadGlobalTags() async {
    final tagsFilePath = await _getGlobalTagsFilePath();
    final file = File(tagsFilePath);

    if (!await file.exists()) {
      return {};
    }

    try {
      final content = await file.readAsString();
      return json.decode(content);
    } catch (e) {
      return {};
    }
  }

  /// Save all tags to the global tags file
  static Future<bool> _saveGlobalTags(Map<String, dynamic> tagsData) async {
    final tagsFilePath = await _getGlobalTagsFilePath();
    final file = File(tagsFilePath);

    try {
      await file.writeAsString(json.encode(tagsData));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets all tags for a file
  ///
  /// Returns an empty list if no tags are found
  static Future<List<String>> getTags(String filePath) async {
    if (_tagsCache.containsKey(filePath)) {
      return List.from(_tagsCache[filePath]!);
    }

    await initialize();

    try {
      if (_useObjectBox && _databaseManager != null) {
        // Use ObjectBox to get tags
        final tags = await _databaseManager!.getTagsForFile(filePath);
        _tagsCache[filePath] = tags;
        return tags;
      } else {
        // Use original implementation for JSON file
        final tagsData = await _loadGlobalTags();

        // Use the absolute file path as the key in the global tags file
        if (tagsData.containsKey(filePath)) {
          final tags = List<String>.from(tagsData[filePath]);
          _tagsCache[filePath] = tags;
          return tags;
        }

        _tagsCache[filePath] = [];
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// List to keep track of recently used tags with timestamps
  static List<Map<String, dynamic>> _recentTags = [];
  static const int MAX_RECENT_TAGS = 40;

  /// Add a tag to recent tags list
  static void addToRecentTags(String tag) {
    // Remove tag if it already exists in recent tags
    _recentTags.removeWhere((item) => item['tag'] == tag);

    // Add tag to the beginning of the list with current timestamp
    _recentTags.insert(
        0, {'tag': tag, 'timestamp': DateTime.now().millisecondsSinceEpoch});

    // Limit the list size
    if (_recentTags.length > MAX_RECENT_TAGS) {
      _recentTags = _recentTags.sublist(0, MAX_RECENT_TAGS);
    }

    // Save recent tags to shared preferences for persistence
    _saveRecentTags();
  }

  /// Save recent tags to SharedPreferences
  static Future<void> _saveRecentTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_recentTags);
      await prefs.setString('recent_tags', jsonString);
    } catch (e) {}
  }

  /// Load recent tags from SharedPreferences
  static Future<void> _loadRecentTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('recent_tags');

      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        _recentTags =
            decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      _recentTags = [];
    }
  }

  /// Get recently added tags
  /// Returns a list of the most recently added tags
  static Future<List<String>> getRecentTags({int limit = 20}) async {
    await initialize();

    // Load recent tags if not already loaded
    if (_recentTags.isEmpty) {
      await _loadRecentTags();
    }

    // Extract tag names from the list and limit by count
    final List<String> recentTagNames =
        _recentTags.take(limit).map((item) => item['tag'] as String).toList();

    // If we don't have enough stored recent tags, supplement with popular tags
    if (recentTagNames.length < limit) {
      // Get popular tags excluding the ones we already have
      final popularTags =
          await TagManager.instance.getPopularTags(limit: limit * 2);

      for (final entry in popularTags.entries) {
        if (recentTagNames.length >= limit) break;
        if (!recentTagNames.contains(entry.key)) {
          recentTagNames.add(entry.key);
        }
      }
    }

    return recentTagNames;
  }

  /// Static wrapper for instance method
  static Future<bool> addTag(String filePath, String tag) async {
    try {
      await initialize();

      // Add to recent tags - use static method directly
      if (tag.trim().isNotEmpty) {
        addToRecentTags(tag.trim());
      }

      if (_useObjectBox && _databaseManager != null) {
        return await _databaseManager!.addTagToFile(filePath, tag);
      } else {
        Map<String, dynamic> tagsData = await _loadGlobalTags();

        // Get existing tags or create new list
        final tags = List<String>.from(tagsData[filePath] ?? []);
        if (!tags.contains(tag)) {
          tags.add(tag);
          tagsData[filePath] = tags;
          final success = await _saveGlobalTags(tagsData);

          if (success) {
            _tagsCache[filePath] = tags;
          }

          // Thông báo thay đổi qua Stream
          _tagChangeController.add(filePath);

          return success;
        }
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  /// Static wrapper for instance method
  static Future<bool> removeTag(String filePath, String tag) async {
    try {
      await initialize();

      if (_useObjectBox && _databaseManager != null) {
        return await _databaseManager!.removeTagFromFile(filePath, tag);
      } else {
        Map<String, dynamic> tagsData = await _loadGlobalTags();
        if (!tagsData.containsKey(filePath)) return true;

        final tags = List<String>.from(tagsData[filePath]);
        if (tags.contains(tag)) {
          tags.remove(tag);

          if (tags.isEmpty) {
            tagsData.remove(filePath);
          } else {
            tagsData[filePath] = tags;
          }

          final success = await _saveGlobalTags(tagsData);
          if (success) {
            if (tags.isEmpty) {
              _tagsCache.remove(filePath);
            } else {
              _tagsCache[filePath] = tags;
            }
          }

          // Thông báo thay đổi qua Stream
          _tagChangeController.add(filePath);

          return success;
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error removing tag from $filePath: $e');
      return false;
    }
  }

  /// Add tags to multiple files using static method
  static Future<bool> addTagToFiles(List<String> filePaths, String tag) async {
    bool success = true;
    for (final path in filePaths) {
      if (!await TagManager.addTag(path, tag)) {
        success = false;
      }
    }
    return success;
  }

  /// Remove tags from multiple files using static method
  static Future<bool> removeTagFromFiles(
      List<String> filePaths, String tag) async {
    bool success = true;
    for (final path in filePaths) {
      if (!await TagManager.removeTag(path, tag)) {
        success = false;
      }
    }
    return success;
  }

  /// Set the full set of tags for a file (replaces existing tags)
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> setTags(String filePath, List<String> tags) async {
    try {
      await initialize();

      // First validate tags (remove empty ones)
      final validTags = tags.where((tag) => tag.trim().isNotEmpty).toList();

      if (_useObjectBox && _databaseManager != null) {
        // Use ObjectBox to set tags
        final success =
            await _databaseManager!.setTagsForFile(filePath, validTags);

        if (success) {
          // Update cache
          if (validTags.isEmpty) {
            _tagsCache.remove(filePath);
          } else {
            _tagsCache[filePath] = validTags;
          }
        }

        // Thông báo thay đổi qua Stream
        _tagChangeController.add(filePath);

        return success;
      } else {
        // Use original implementation for JSON file
        Map<String, dynamic> tagsData = await _loadGlobalTags();

        if (validTags.isEmpty) {
          // Remove entry if no tags
          if (tagsData.containsKey(filePath)) {
            tagsData.remove(filePath);
          }
        } else {
          tagsData[filePath] = validTags;
        }

        final success = await _saveGlobalTags(tagsData);

        if (success) {
          // Update cache
          if (validTags.isEmpty) {
            _tagsCache.remove(filePath);
          } else {
            _tagsCache[filePath] = validTags;
          }
        }

        // Thông báo thay đổi qua Stream
        _tagChangeController.add(filePath);

        return success;
      }
    } catch (e) {
      debugPrint('Error setting tags for $filePath: $e');
      return false;
    }
  }

  /// Gets all unique tags across all files
  ///
  /// Returns a set of unique tags
  static Future<Set<String>> getAllUniqueTags(String directoryPath) async {
    // Note: directoryPath parameter is kept for backward compatibility
    // but is no longer used since tags are global

    final Set<String> allTags = {};

    try {
      await initialize();

      if (_useObjectBox && _databaseManager != null) {
        // Use ObjectBox to get all unique tags
        allTags.addAll(await _databaseManager!.getAllUniqueTags());
      } else {
        // Use original implementation for JSON file
        final tagsData = await _loadGlobalTags();

        for (final tags in tagsData.values) {
          if (tags is List) {
            for (final tag in tags) {
              if (tag is String) {
                allTags.add(tag);
              }
            }
          }
        }
      }

      return allTags;
    } catch (e) {
      debugPrint('Error getting all tags: $e');
      return allTags;
    }
  }

  /// Finds all files with a specific tag
  ///
  /// Returns a list of files with the tag (no longer includes directories)
  static Future<List<FileSystemEntity>> findFilesByTag(
      String directoryPath, String tag) async {
    final List<FileSystemEntity> results = [];
    final Set<String> addedPaths =
        {}; // Thêm Set để theo dõi file đã được thêm vào
    final String normalizedTag = tag.toLowerCase().trim();

    if (normalizedTag.isEmpty) {
      debugPrint('Tag is empty, returning empty results');
      return results;
    }

    try {
      await initialize();
      debugPrint(
          'Finding files with tag: "$normalizedTag" in directory: "$directoryPath"');

      // Normalize directory path
      String normalizedDirPath = directoryPath;
      if (!normalizedDirPath.endsWith(Platform.pathSeparator)) {
        normalizedDirPath += Platform.pathSeparator;
      }

      debugPrint('Normalized directory path: $normalizedDirPath');

      // Step 1: First search current directory (faster)
      if (_useObjectBox && _databaseManager != null) {
        // Use ObjectBox to find files by tag
        final filePaths = await _databaseManager!.findFilesByTag(normalizedTag);
        debugPrint(
            'Found ${filePaths.length} file paths with tag: "$normalizedTag"');

        // Only get paths belonging to current directory
        for (final path in filePaths) {
          if ((path.startsWith(normalizedDirPath) ||
                  path.startsWith(directoryPath)) &&
              !addedPaths.contains(path)) {
            try {
              // Only check for files, not directories
              final file = File(path);
              final isFile = await file.exists();

              if (isFile) {
                // It's a file
                results.add(file);
                addedPaths.add(path); // Đánh dấu path đã được thêm vào
                debugPrint('Added file to results: $path');
              }
            } catch (e) {
              debugPrint('Error checking entity type for $path: $e');
            }
          }
        }
      } else {
        // Use original implementation for JSON file
        final tagsData = await _loadGlobalTags();
        debugPrint('Loaded ${tagsData.length} entries with tags');

        // For each path in the global tags data
        for (final entityPath in tagsData.keys) {
          if (addedPaths.contains(entityPath)) continue; // Bỏ qua nếu đã thêm

          final tags = List<String>.from(tagsData[entityPath] ?? []);

          // Check if file has the matching tag
          final hasMatchingTag = tags.any((fileTag) {
            return fileTag.toLowerCase() == normalizedTag ||
                fileTag.toLowerCase().contains(normalizedTag);
          });

          // Only process if file has matching tag
          if (hasMatchingTag) {
            // Check if path is in the current directory
            if (entityPath.startsWith(normalizedDirPath) ||
                entityPath.startsWith(directoryPath)) {
              try {
                // Only check for files, not directories
                final file = File(entityPath);
                final isFile = await file.exists();

                if (isFile) {
                  // It's a file
                  results.add(file);
                  addedPaths.add(entityPath); // Đánh dấu path đã được thêm vào
                  debugPrint('Added file to results: $entityPath');
                }
              } catch (e) {
                debugPrint('Error checking entity type for $entityPath: $e');
              }
            }
          }
        }
      }

      // Step 2: Search in subdirectories (lazy approach)
      // Get immediate subdirectories from the current directory
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        try {
          // Get all subdirectories in the current directory
          final List<Directory> subdirectories = await directory
              .list()
              .where((entity) => entity is Directory)
              .map((entity) => entity as Directory)
              .toList();

          // Search in each subdirectory (first level only for laziness)
          for (final subdir in subdirectories) {
            // Get all files in the subdirectory (non-recursive)
            try {
              final subdirEntities = await subdir.list().toList();

              // Check tags for each file in the subdirectory
              for (final entity in subdirEntities) {
                if (entity is File && !addedPaths.contains(entity.path)) {
                  final fileTags = await getTags(entity.path);
                  if (fileTags.any((fileTag) =>
                      fileTag.toLowerCase() == normalizedTag ||
                      fileTag.toLowerCase().contains(normalizedTag))) {
                    results.add(entity);
                    addedPaths
                        .add(entity.path); // Đánh dấu path đã được thêm vào
                  }
                }
              }
            } catch (e) {
              debugPrint(
                  'Error listing files in subdirectory ${subdir.path}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error searching in subdirectories: $e');
        }
      }

      debugPrint('Found ${results.length} files with tag: "$normalizedTag"');
      return results;
    } catch (e) {
      debugPrint('Error finding files by tag: $e');
      return results;
    }
  }

  /// Find files with a specific tag anywhere in the file system
  ///
  /// Returns a list of files with the tag (no longer includes directories)
  static Future<List<FileSystemEntity>> findFilesByTagGlobally(
      String tag) async {
    final List<FileSystemEntity> results = [];
    final Set<String> addedPaths = {}; // Theo dõi file đã được thêm
    final String normalizedTag = tag.toLowerCase().trim();

    if (normalizedTag.isEmpty) {
      debugPrint('Tag is empty, returning empty results');
      return results;
    }

    try {
      await initialize();
      debugPrint('Finding files with tag: "$normalizedTag" globally');

      // Xóa cache để đảm bảo dữ liệu mới nhất
      clearCache();

      if (_useObjectBox && _databaseManager != null) {
        // Use ObjectBox to find files by tag - QUAN TRỌNG: Tìm kiếm chính xác dựa trên tag
        final filePaths = await _databaseManager!.findFilesByTag(normalizedTag);
        debugPrint(
            'Found ${filePaths.length} file paths with tag: "$normalizedTag"');

        // Convert paths to FileSystemEntity objects - only include files, not directories
        for (final path in filePaths) {
          if (addedPaths.contains(path)) continue; // Bỏ qua nếu đã thêm

          try {
            // Check if it's a file
            final file = File(path);
            final isFile = await file.exists();

            if (isFile) {
              // It's a file
              results.add(file);
              addedPaths.add(path); // Đánh dấu path đã được thêm
              debugPrint('Added file to results: $path');
            }
          } catch (e) {
            debugPrint('Error checking entity type for $path: $e');
          }
        }
      } else {
        // Use original implementation for JSON file
        final tagsData = await _loadGlobalTags();
        debugPrint('Loaded ${tagsData.length} entries with tags from JSON');

        // For each path in the global tags data
        for (final entityPath in tagsData.keys) {
          if (addedPaths.contains(entityPath)) continue;

          try {
            final tags = tagsData[entityPath];
            if (tags is! List) continue;

            final tagsList = List<String>.from(tags);

            // Check if file has the matching tag
            final hasMatchingTag = tagsList.any((fileTag) {
              return fileTag.toLowerCase() == normalizedTag ||
                  fileTag.toLowerCase().contains(normalizedTag);
            });

            if (hasMatchingTag) {
              // Check if it's a file
              final file = File(entityPath);
              final isFile = await file.exists();

              if (isFile) {
                // It's a file
                results.add(file);
                addedPaths.add(entityPath);
                debugPrint('Added file to results from JSON: $entityPath');
              }
            }
          } catch (e) {
            debugPrint('Error checking entity in JSON for $entityPath: $e');
          }
        }
      }

      debugPrint(
          'Found ${results.length} files with tag: "$normalizedTag" globally');
      return results;
    } catch (e) {
      debugPrint('Error finding files by tag globally: $e');
      return results;
    }
  }

  /// Clears the tags cache to free memory
  static void clearCache() {
    debugPrint("Clearing all tag caches...");

    // Clear all caches - make sure to clear all possible caches
    _tagsCache.clear();
    _tagCache.clear();

    // Clear global tags path to force reload
    _globalTagsPath = null;

    // Force re-initialize database connection
    if (_useObjectBox && _databaseManager != null) {
      try {
        // Chỉ log, không block luồng
        debugPrint("Resetting database connection...");
      } catch (e) {
        debugPrint("Error resetting database: $e");
      }
    }

    // Debugging output
    debugPrint("Tag caches cleared completely!");
  }

  /// Migrate from directory-based tags to global tags
  ///
  /// This function scans all .tags files in the specified root directory
  /// and its subdirectories, and migrates the tags to the global tags file.
  static Future<int> migrateToGlobalTags(String rootDirectory) async {
    int migratedFileCount = 0;

    try {
      await initialize();

      final rootDir = Directory(rootDirectory);
      if (!await rootDir.exists()) {
        return 0;
      }

      // Load the current global tags data
      Map<String, dynamic> globalTags = await _loadGlobalTags();

      // Find all .tags files
      await for (final entity in rootDir.list(recursive: true)) {
        if (entity is File && pathlib.basename(entity.path) == '.tags') {
          try {
            final content = await entity.readAsString();
            final Map<String, dynamic> localTagsJson = json.decode(content);
            final String dirPath = entity.parent.path;

            // Process each file in the local tags file
            for (final fileName in localTagsJson.keys) {
              if (localTagsJson[fileName] is List) {
                final tags = List<String>.from(localTagsJson[fileName]);
                if (tags.isNotEmpty) {
                  final filePath = pathlib.join(dirPath, fileName);
                  final file = File(filePath);

                  // Only migrate if the file exists
                  if (await file.exists()) {
                    if (_useObjectBox && _databaseManager != null) {
                      // Save to ObjectBox
                      await _databaseManager!.setTagsForFile(filePath, tags);
                    } else {
                      // Save to JSON file
                      globalTags[filePath] = tags;
                    }
                    migratedFileCount++;
                  }
                }
              }
            }

            // Delete the old .tags file after migration
            await entity.delete();
          } catch (e) {
            debugPrint('Error migrating tags from ${entity.path}: $e');
          }
        }
      }

      // Save the updated global tags if using JSON storage
      if (!_useObjectBox) {
        await _saveGlobalTags(globalTags);
      }

      return migratedFileCount;
    } catch (e) {
      debugPrint('Error during tags migration: $e');
      return migratedFileCount;
    }
  }

  /// Migrate from JSON file storage to ObjectBox database
  ///
  /// This function loads all tags from the global JSON file
  /// and migrates them to the ObjectBox database.
  static Future<int> migrateFromJsonToObjectBox() async {
    int migratedFileCount = 0;

    try {
      await initialize();

      if (!_useObjectBox || _databaseManager == null) {
        throw Exception('ObjectBox is not enabled');
      }

      // Load all tags from the JSON file
      final tagsData = await _loadGlobalTags();

      // Migrate each file's tags to ObjectBox
      for (final filePath in tagsData.keys) {
        final tags = List<String>.from(tagsData[filePath]);
        if (tags.isNotEmpty) {
          final success =
              await _databaseManager!.setTagsForFile(filePath, tags);
          if (success) {
            migratedFileCount++;
          }
        }
      }

      debugPrint('Migrated $migratedFileCount files to ObjectBox database');
      return migratedFileCount;
    } catch (e) {
      debugPrint('Error migrating from JSON to ObjectBox: $e');
      return migratedFileCount;
    }
  }

  /// Deletes a tag from all files in the system
  static Future<void> deleteTagGlobally(String tag) async {
    final instance = TagManager.instance;

    try {
      // Find all files with this tag
      final filePaths =
          await instance._findFilesByTagInternal(tag.toLowerCase().trim());

      // Remove tag from each file
      for (final path in filePaths) {
        await removeTag(path, tag);
      }

      // Clear cache to ensure fresh data
      clearCache();

      // Notify about the change through the global notification
      instance.notifyTagChanged("global:tag_deleted");
      // Also notify through the static stream if anyone is still using it
      _tagChangeController.add("global:tag_deleted");
    } catch (e) {
      debugPrint('Error deleting tag globally: $e');
      rethrow;
    }
  }

  /// Find all files that have a specific tag (internal implementation)
  Future<List<String>> _findFilesByTagInternal(String tag) async {
    try {
      // If using ObjectBox
      if (_useObjectBox && _databaseManager != null) {
        // Query the database for files with this tag
        final tagLowercase = tag.toLowerCase().trim();
        final results = await _databaseManager!.findFilesByTag(tagLowercase);
        return results;
      } else {
        // Use the file search implementation without ObjectBox
        return await _searchByTag(tag);
      }
    } catch (e) {
      debugPrint('Error finding files by tag: $e');
      return [];
    }
  }

  /// Search files by tag without using ObjectBox
  Future<List<String>> _searchByTag(String tag) async {
    final List<String> results = [];

    // This is a simple implementation to search all files in the system
    // In a real app, you'd use a more efficient approach
    try {
      // Use the tags cache to find files with this tag
      if (_tagCache.isNotEmpty) {
        final normalizedTag = tag.toLowerCase().trim();

        _tagCache.forEach((filePath, tags) {
          if (tags.map((t) => t.toLowerCase().trim()).contains(normalizedTag)) {
            results.add(filePath);
          }
        });
      }
    } catch (e) {
      debugPrint('Error searching for tag: $e');
    }

    return results;
  }
}
