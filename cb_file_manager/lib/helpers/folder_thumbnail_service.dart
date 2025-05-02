import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';

class FolderThumbnailService {
  static const String _customThumbnailsKey = 'folder_custom_thumbnails';
  static final FolderThumbnailService _instance =
      FolderThumbnailService._internal();

  // In-memory cache for thumbnails with a limit to prevent memory leaks
  final Map<String, String> _thumbnailCache = {};
  // Maximum number of folder thumbnails to keep in cache
  static const int _maxCacheSize = 50;
  // List to track LRU order (most recently used at the end)
  final List<String> _cacheAccessOrder = [];

  // In-memory cache for custom thumbnail settings
  Map<String, String> _customThumbnailSettings = {};

  // Last cache cleanup timestamp
  DateTime _lastCacheCleanup = DateTime.now();

  // Singleton pattern
  factory FolderThumbnailService() {
    return _instance;
  }

  FolderThumbnailService._internal();

  // Initialize the service and load saved preferences
  Future<void> initialize() async {
    await _loadCustomThumbnailSettings();
    debugPrint('FolderThumbnailService initialized');
  }

  // Load custom thumbnail settings from SharedPreferences
  Future<void> _loadCustomThumbnailSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(_customThumbnailsKey);

      if (settingsJson != null) {
        _customThumbnailSettings = Map<String, String>.from(settingsJson
            .split('|')
            .map((item) {
              final parts = item.split('::');
              return parts.length == 2 ? MapEntry(parts[0], parts[1]) : null;
            })
            .where((item) => item != null)
            .fold({}, (map, item) {
              map[item!.key] = item.value;
              return map;
            }));
      }
    } catch (e) {
      debugPrint('Error loading custom thumbnail settings: $e');
      _customThumbnailSettings = {};
    }
  }

  // Save custom thumbnail settings to SharedPreferences
  Future<void> _saveCustomThumbnailSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String settingsJson = _customThumbnailSettings.entries
          .map((entry) => '${entry.key}::${entry.value}')
          .join('|');

      await prefs.setString(_customThumbnailsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving custom thumbnail settings: $e');
    }
  }

  // Set a custom thumbnail for a folder
  Future<void> setCustomThumbnail(String folderPath, String filePath) async {
    _customThumbnailSettings[folderPath] = filePath;
    await _saveCustomThumbnailSettings();
    // Clear from cache to force regeneration
    _removeFromCache(folderPath);
  }

  // Clear custom thumbnail for a folder
  Future<void> clearCustomThumbnail(String folderPath) async {
    _customThumbnailSettings.remove(folderPath);
    await _saveCustomThumbnailSettings();
    // Clear from cache to force regeneration
    _removeFromCache(folderPath);
  }

  // Get custom thumbnail path for a folder (if set)
  String? getCustomThumbnailPath(String folderPath) {
    return _customThumbnailSettings[folderPath];
  }

  // Check if a folder has custom thumbnail
  bool hasCustomThumbnail(String folderPath) {
    return _customThumbnailSettings.containsKey(folderPath);
  }

  // Add to cache with LRU management
  void _addToCache(String key, String value) {
    // If the key is already in cache, remove it from the access order
    if (_thumbnailCache.containsKey(key)) {
      _cacheAccessOrder.remove(key);
    } else if (_thumbnailCache.length >= _maxCacheSize) {
      // If cache is full, remove the least recently used item
      final lruKey = _cacheAccessOrder.removeAt(0);
      _thumbnailCache.remove(lruKey);
      debugPrint('FolderThumbnailService: Removed LRU cache entry: $lruKey');
    }

    // Add/update the cache and mark as most recently used
    _thumbnailCache[key] = value;
    _cacheAccessOrder.add(key);

    // Periodically check for video cache cleanup
    _performMaintenanceIfNeeded();
  }

  // Remove from cache if exists
  void _removeFromCache(String key) {
    _thumbnailCache.remove(key);
    _cacheAccessOrder.remove(key);
  }

  // Perform cache maintenance operations periodically
  void _performMaintenanceIfNeeded() {
    final now = DateTime.now();
    // Only perform cleanup once per hour
    if (now.difference(_lastCacheCleanup).inHours >= 1) {
      _lastCacheCleanup = now;
      // Trim VideoThumbnailHelper cache to prevent it from growing too large
      unawaited(VideoThumbnailHelper.trimCache());
    }
  }

  // Get thumbnail for a folder
  Future<String?> getFolderThumbnail(String folderPath) async {
    // Check if we have a cached thumbnail
    if (_thumbnailCache.containsKey(folderPath)) {
      final cachedPath = _thumbnailCache[folderPath];

      // Update the LRU order
      _cacheAccessOrder.remove(folderPath);
      _cacheAccessOrder.add(folderPath);

      return cachedPath;
    }

    // Check if there is a custom thumbnail
    if (_customThumbnailSettings.containsKey(folderPath)) {
      final customPath = _customThumbnailSettings[folderPath];

      // Handle video custom thumbnails
      if (customPath!.startsWith('video::')) {
        final videoPath = customPath.substring(7);
        if (File(videoPath).existsSync()) {
          // Generate actual thumbnail for the video file
          final thumbnailPath =
              await VideoThumbnailHelper.generateThumbnail(videoPath);
          if (thumbnailPath != null) {
            // Still keep the video:: prefix to identify it's a video
            // Store the original video path with the thumbnail path for reference
            final result = 'video::$videoPath::$thumbnailPath';
            _addToCache(folderPath, result);
            return result;
          }
          // Fallback to original path if thumbnail generation fails
          _addToCache(folderPath, customPath);
          return customPath;
        }
      } else if (await File(customPath).exists()) {
        _addToCache(folderPath, customPath);
        return customPath;
      }
    }

    // Find and generate thumbnail from folder content
    String? thumbnailPath;
    try {
      thumbnailPath = await _findFirstMediaFileInFolder(folderPath);
      debugPrint('Found media thumbnail: $thumbnailPath');
    } catch (e) {
      debugPrint('Error finding media in folder: $e');
    }

    if (thumbnailPath != null) {
      _addToCache(folderPath, thumbnailPath);
    }

    return thumbnailPath;
  }

  // Find the first media file in a folder (direct implementation)
  Future<String?> _findFirstMediaFileInFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      return null;
    }

    try {
      final List<FileSystemEntity> entities = await directory.list().toList();
      debugPrint('Found ${entities.length} items in directory $folderPath');

      // First look for images
      for (final entity in entities) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp']
              .contains(ext)) {
            debugPrint('Found image file: ${entity.path}');
            return entity.path;
          }
        }
      }

      // Then look for videos
      for (final entity in entities) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (VideoThumbnailHelper.isSupportedVideoFormat(entity.path)) {
            debugPrint('Found video file: ${entity.path}');

            // Generate thumbnail for video
            final videoPath = entity.path;
            final thumbnailPath =
                await VideoThumbnailHelper.generateThumbnail(videoPath);

            if (thumbnailPath != null) {
              debugPrint('Generated video thumbnail: $thumbnailPath');
              // Store both video path and thumbnail path for better reference
              return 'video::$videoPath::$thumbnailPath';
            }

            // Fallback to original video path if thumbnail generation fails
            return 'video::${entity.path}';
          }
        }
      }

      debugPrint('No media files found in folder: $folderPath');
    } catch (e) {
      debugPrint('Error scanning folder: $e');
    }

    return null;
  }

  // Get all media files in a folder for thumbnail selection
  Future<List<File>> getMediaFilesForThumbnailSelection(
      String folderPath) async {
    final directory = Directory(folderPath);
    final List<File> mediaFiles = [];

    if (!await directory.exists()) {
      return [];
    }

    try {
      final List<FileSystemEntity> entities = await directory.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();

          // Check for supported media files
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(extension) ||
              VideoThumbnailHelper.isSupportedVideoFormat(entity.path)) {
            mediaFiles.add(entity);
          }
        }
      }

      debugPrint(
          'Found ${mediaFiles.length} media files in folder $folderPath');
    } catch (e) {
      debugPrint('Error getting media files: $e');
    }

    return mediaFiles;
  }

  // Clear the in-memory cache
  void clearCache() {
    _thumbnailCache.clear();
    _cacheAccessOrder.clear();
    debugPrint('FolderThumbnailService: Cache cleared');

    // Also clear the VideoThumbnailHelper cache
    unawaited(VideoThumbnailHelper.clearCache());
  }
}
