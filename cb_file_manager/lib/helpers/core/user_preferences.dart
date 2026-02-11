import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// Theme mode preference options
enum ThemePreference {
  system, // Follow system theme
  light, // Force light theme
  dark // Force dark theme
}

/// A class to manage user preferences for the application
class UserPreferences {
  // Singleton instance with getter
  static final UserPreferences _instance = UserPreferences._internal();
  static UserPreferences get instance => _instance;

  SharedPreferences? _preferences;
  bool _initialized = false;

  // Database manager for storing preferences in ObjectBox
  DatabaseManager? _databaseManager;
  bool _useObjectBox = true;

  // Stream controller for theme changes
  final StreamController<ThemeMode> _themeChangeController =
      StreamController<ThemeMode>.broadcast();

  // Stream that can be listened to for theme changes
  Stream<ThemeMode> get themeChangeStream => _themeChangeController.stream;

  // Shared preferences keys
  static const String _viewModeKey = 'view_mode';
  static const String _sortOptionKey = 'sort_option';
  static const String _gridZoomLevelKey = 'grid_zoom_level';
  static const String _lastFolderKey = 'last_accessed_folder';
  static const String _imageGalleryThumbnailSizeKey =
      'image_gallery_thumbnail_size';
  static const String _videoGalleryThumbnailSizeKey =
      'video_gallery_thumbnail_size';
  static const String _videoPlayerVolumeKey = 'video_player_volume';
  static const String _videoPlayerMuteKey = 'video_player_mute';
  static const String _drawerPinnedKey = 'drawer_pinned';
  static const String _themePreferenceKey = 'theme_preference';
  static const String _keySearchTipShown = 'search_tip_shown';
  static const String _videoThumbnailTimestampKey = 'video_thumbnail_timestamp';
  static const String _videoThumbnailPercentageKey =
      'video_thumbnail_percentage';
  static const String _useObjectBoxKey = 'use_objectbox_storage';
  static const String _columnVisibilityKey = 'column_visibility';
  static const String _showFileTagsKey = 'show_file_tags';
  static const String _previewPaneVisibleKey = 'preview_pane_visible';
  static const String _thumbnailModeKey = 'thumbnail_mode';
  static const String _maxThumbnailConcurrencyKey = 'max_thumbnail_concurrency';
  static const String _previewPaneWidthKey = 'preview_pane_width';
  static const String _useSystemDefaultForVideoKey =
      'use_system_default_for_video';
  static const String _preferredVideoPlayerAppKey =
      'preferred_video_player_app';
  static const String _recentPathsKey = 'recent_paths';

  // Constants for grid zoom level
  static const int minGridZoomLevel = 2; // Largest thumbnails (2 per row)
  static const int maxGridZoomLevel = 15; // Smallest thumbnails (15 per row)
  static const int defaultGridZoomLevel = 4; // Default (4 per row)
  static const double defaultPreviewPaneWidth = 360.0;

  // Constants for thumbnail sizes
  static const double minThumbnailSize = 2.0;
  static const double maxThumbnailSize = 10.0;
  static const double defaultThumbnailSize = 3.0;

  // Constants for video thumbnail timestamp (in seconds)
  static const int defaultVideoThumbnailTimestamp = 1;
  static const int minVideoThumbnailTimestamp = 0;
  static const int maxVideoThumbnailTimestamp = 60;

  // Constants for video thumbnail position (in percentage)
  static const int defaultVideoThumbnailPercentage =
      10; // 10% of video duration
  static const int minVideoThumbnailPercentage = 0; // Start of video
  static const int maxVideoThumbnailPercentage = 100; // End of video

  // Constants for thumbnail generation mode
  // 'fast' = use OS built-in methods (Windows shell, Android/iOS MediaStore)
  // 'custom' = use FFmpeg with user-configurable timestamp
  static const String defaultThumbnailMode = 'custom';

  // Constants for thumbnail generation concurrency
  static const int minThumbnailConcurrency = 1;
  static const int maxThumbnailConcurrency = 32;
  static const int defaultThumbnailConcurrency = 8;

  // Constants for recent paths
  static const int maxRecentPaths = 20;

  // Private constructor for singleton
  UserPreferences._internal();

  /// Initialize the preferences
  Future<void> init() async {
    // Skip initialization if already done
    if (_initialized) return;

    try {
      // Khởi tạo SharedPreferences trước
      _preferences ??= await SharedPreferences.getInstance();

      // Kiểm tra thiết lập hiện tại từ SharedPreferences
      _useObjectBox = _preferences?.getBool(_useObjectBoxKey) ?? false;

      // Khởi tạo ObjectBox chỉ nếu cần thiết và cẩn thận để tránh vòng lặp
      if (_useObjectBox) {
        _databaseManager = DatabaseManager.getInstance();

        // QUAN TRỌNG: Chỉ khởi tạo nếu chưa được khởi tạo
        // Tránh việc gọi lại như trước đây, chỉ sử dụng phiên bản đã khởi tạo
        if (_databaseManager != null && !_databaseManager!.isInitialized()) {
          // Đánh dấu đã khởi tạo trước để tránh vòng lặp
          _initialized = true;
        }
      }

      _initialized = true;
    } catch (e) {
      // Fallback to SharedPreferences nếu có lỗi
      _useObjectBox = false;
      await _preferences?.setBool(_useObjectBoxKey, false);
      _initialized = true; // Vẫn đánh dấu là đã khởi tạo để tránh lặp lại
    }
  }

  /// Check if preferences have been initialized
  bool isInitialized() {
    return _initialized;
  }

  /// Migrate existing preferences from SharedPreferences to ObjectBox
  Future<void> _migratePreferencesToObjectBox() async {
    try {
      // Only migrate if not already done
      final migrationDone = await _databaseManager!.getBoolPreference(
        'migration_done',
        defaultValue: false,
      );

      if (migrationDone != true) {
        // View mode
        final viewMode = await getViewMode();
        await _databaseManager!.saveIntPreference(_viewModeKey, viewMode.index);

        // Sort option
        final sortOption = await getSortOption();
        await _databaseManager!
            .saveIntPreference(_sortOptionKey, sortOption.index);

        // Grid zoom level
        final gridZoom = await getGridZoomLevel();
        await _databaseManager!.saveIntPreference(_gridZoomLevelKey, gridZoom);

        // Last folder
        final lastFolder = await getLastAccessedFolder();
        if (lastFolder != null) {
          await _databaseManager!
              .saveStringPreference(_lastFolderKey, lastFolder);
        }

        // Image gallery thumbnail size
        final imageGallerySize = await getImageGalleryThumbnailSize();
        await _databaseManager!.saveDoublePreference(
          _imageGalleryThumbnailSizeKey,
          imageGallerySize,
        );

        // Video gallery thumbnail size
        final videoGallerySize = await getVideoGalleryThumbnailSize();
        await _databaseManager!.saveDoublePreference(
          _videoGalleryThumbnailSizeKey,
          videoGallerySize,
        );

        // Video player volume
        final volume = await getVideoPlayerVolume();
        await _databaseManager!
            .saveDoublePreference(_videoPlayerVolumeKey, volume);

        // Video player mute
        final mute = await getVideoPlayerMute();
        await _databaseManager!.saveBoolPreference(_videoPlayerMuteKey, mute);

        // Drawer pinned
        final drawerPinned = await getDrawerPinned();
        await _databaseManager!
            .saveBoolPreference(_drawerPinnedKey, drawerPinned);

        // Theme preference
        final theme = await getThemePreference();
        await _databaseManager!
            .saveIntPreference(_themePreferenceKey, theme.index);

        // Search tip shown
        final searchTipShown = await getSearchTipShown();
        await _databaseManager!
            .saveBoolPreference(_keySearchTipShown, searchTipShown);

        // Video thumbnail settings
        final timestamp = await getVideoThumbnailTimestamp();
        await _databaseManager!
            .saveIntPreference(_videoThumbnailTimestampKey, timestamp);

        final percentage = await getVideoThumbnailPercentage();
        await _databaseManager!
            .saveIntPreference(_videoThumbnailPercentageKey, percentage);

        // Show file tags setting
        final showFileTags = await getShowFileTags();
        await _databaseManager!
            .saveBoolPreference(_showFileTagsKey, showFileTags);

        // Preview pane settings
        final previewPaneVisible = await getPreviewPaneVisible();
        await _databaseManager!
            .saveBoolPreference(_previewPaneVisibleKey, previewPaneVisible);
        final previewPaneWidth = await getPreviewPaneWidth();
        await _databaseManager!
            .saveDoublePreference(_previewPaneWidthKey, previewPaneWidth);

        // Mark migration as done
        await _databaseManager!.saveBoolPreference('migration_done', true);
      }
    } catch (e) {
      // Fallback to SharedPreferences
      _useObjectBox = false;
      await _preferences?.setBool(_useObjectBoxKey, false);
    }
  }

  /// Enable or disable ObjectBox as the preference storage
  Future<bool> setUseObjectBox(bool useObjectBox) async {
    if (useObjectBox == _useObjectBox) return true;

    try {
      // Initialize ObjectBox if we're enabling it
      if (useObjectBox) {
        // Make sure database manager is initialized
        _databaseManager ??= DatabaseManager.getInstance();
        await _databaseManager!.initialize();
        await _migratePreferencesToObjectBox();
      }

      _useObjectBox = useObjectBox;
      return await _preferences?.setBool(_useObjectBoxKey, useObjectBox) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Enable or disable ObjectBox as the preference storage
  Future<bool> setUsingObjectBox(bool useObjectBox) async {
    if (useObjectBox == _useObjectBox) return true;

    try {
      // Initialize ObjectBox if we're enabling it
      if (useObjectBox) {
        // Make sure database manager is initialized
        _databaseManager ??= DatabaseManager.getInstance();
        await _databaseManager!.initialize();
        await _migratePreferencesToObjectBox();
      }

      _useObjectBox = useObjectBox;
      return await _preferences?.setBool(_useObjectBoxKey, useObjectBox) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Set whether cloud sync is enabled
  Future<bool> setCloudSyncEnabled(bool enabled) async {
    try {
      await _databaseManager!.initialize();
      _databaseManager!.setCloudSyncEnabled(enabled);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if we're using ObjectBox for storage
  bool isUsingObjectBox() {
    return _useObjectBox;
  }

  /// Generic method to get a preference value
  /// Automatically handles SharedPreferences and ObjectBox storage backends
  Future<T?> _getPreference<T>(
    String key, {
    T? defaultValue,
  }) async {
    if (_useObjectBox && _databaseManager != null) {
      // Handle ObjectBox storage
      if (T == int) {
        return await _databaseManager!.getIntPreference(
          key,
          defaultValue: defaultValue as int?,
        ) as T?;
      } else if (T == double) {
        return await _databaseManager!.getDoublePreference(
          key,
          defaultValue: defaultValue as double?,
        ) as T?;
      } else if (T == bool) {
        return await _databaseManager!.getBoolPreference(
          key,
          defaultValue: defaultValue as bool?,
        ) as T?;
      } else if (T == String) {
        return await _databaseManager!.getStringPreference(
          key,
          defaultValue: defaultValue as String?,
        ) as T?;
      }
    } else {
      // Handle SharedPreferences storage
      if (T == int) {
        return _preferences?.getInt(key) as T? ?? defaultValue;
      } else if (T == double) {
        return _preferences?.getDouble(key) as T? ?? defaultValue;
      } else if (T == bool) {
        return _preferences?.getBool(key) as T? ?? defaultValue;
      } else if (T == String) {
        return _preferences?.getString(key) as T? ?? defaultValue;
      }
    }
    return defaultValue;
  }

  /// Generic method to save a preference value
  /// Automatically handles SharedPreferences and ObjectBox storage backends
  Future<bool> _savePreference<T>(
    String key,
    T value,
  ) async {
    if (_useObjectBox && _databaseManager != null) {
      // Handle ObjectBox storage
      if (value is int) {
        return await _databaseManager!.saveIntPreference(key, value);
      } else if (value is double) {
        return await _databaseManager!.saveDoublePreference(key, value);
      } else if (value is bool) {
        return await _databaseManager!.saveBoolPreference(key, value);
      } else if (value is String) {
        return await _databaseManager!.saveStringPreference(key, value);
      }
    } else {
      // Handle SharedPreferences storage
      if (value is int) {
        return await _preferences?.setInt(key, value) ?? false;
      } else if (value is double) {
        return await _preferences?.setDouble(key, value) ?? false;
      } else if (value is bool) {
        return await _preferences?.setBool(key, value) ?? false;
      } else if (value is String) {
        return await _preferences?.setString(key, value) ?? false;
      }
    }
    return false;
  }

  /// Generic method to delete a preference
  Future<bool> _deletePreference(String key) async {
    if (_useObjectBox && _databaseManager != null) {
      return await _databaseManager!.deletePreference(key);
    } else {
      return await _preferences?.remove(key) ?? false;
    }
  }

  /// Get image gallery thumbnail size (as grid count - higher means smaller thumbnails)
  Future<double> getImageGalleryThumbnailSize() async {
    return await _getPreference<double>(
          _imageGalleryThumbnailSizeKey,
          defaultValue: defaultThumbnailSize,
        ) ??
        defaultThumbnailSize;
  }

  /// Set image gallery thumbnail size
  Future<bool> setImageGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);
    return await _savePreference<double>(
        _imageGalleryThumbnailSizeKey, validSize);
  }

  /// Get video gallery thumbnail size (as grid count - higher means smaller thumbnails)
  Future<double> getVideoGalleryThumbnailSize() async {
    return await _getPreference<double>(
          _videoGalleryThumbnailSizeKey,
          defaultValue: defaultThumbnailSize,
        ) ??
        defaultThumbnailSize;
  }

  /// Set video gallery thumbnail size
  Future<bool> setVideoGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);
    return await _savePreference<double>(
        _videoGalleryThumbnailSizeKey, validSize);
  }

  /// Get the last accessed folder path with validation
  Future<String?> getLastAccessedFolder() async {
    String? folderPath = await _getPreference<String>(_lastFolderKey);

    // Add validation to ensure the folder exists before returning it
    if (folderPath != null) {
      try {
        final directory = Directory(folderPath);
        // Only return the path if the directory exists and is accessible
        if (directory.existsSync()) {
          return folderPath;
        } else {
          // If directory doesn't exist, clear the preference
          await _deletePreference(_lastFolderKey);
          return null;
        }
      } catch (e) {
        // If there's an error, clear the preference
        await _deletePreference(_lastFolderKey);
        return null;
      }
    }
    return null;
  }

  /// Save the last accessed folder path with validation
  Future<bool> setLastAccessedFolder(String folderPath) async {
    try {
      // Verify the folder exists before saving it
      final directory = Directory(folderPath);
      if (await directory.exists()) {
        return await _savePreference<String>(_lastFolderKey, folderPath);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clear the last accessed folder preference
  Future<bool> clearLastAccessedFolder() async {
    return await _deletePreference(_lastFolderKey);
  }

  bool _pathsEqual(String a, String b) {
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase();
    }
    return a == b;
  }

  bool _isVirtualPath(String value) {
    return value.startsWith('#');
  }

  /// Get recently visited filesystem paths.
  ///
  /// Virtual paths (e.g. "#search?tag=") are excluded.
  Future<List<String>> getRecentPaths({
    int limit = maxRecentPaths,
    bool validateDirectories = true,
  }) async {
    final jsonString = await _getPreference<String>(_recentPathsKey);
    if (jsonString == null || jsonString.trim().isEmpty) return <String>[];

    try {
      final decoded = json.decode(jsonString);
      if (decoded is! List) return <String>[];

      final rawPaths = decoded
          .whereType<String>()
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty && !_isVirtualPath(p))
          .toList(growable: false);

      if (!validateDirectories) {
        return rawPaths.take(limit).toList(growable: false);
      }

      final List<String> validPaths = <String>[];
      bool changed = false;
      for (final p in rawPaths) {
        try {
          if (Directory(p).existsSync()) {
            validPaths.add(p);
          } else {
            changed = true;
          }
        } catch (_) {
          changed = true;
        }
      }

      if (changed) {
        await _savePreference<String>(_recentPathsKey, json.encode(validPaths));
      }

      return validPaths.take(limit).toList(growable: false);
    } catch (_) {
      return <String>[];
    }
  }

  /// Add a filesystem path to the recent paths list.
  ///
  /// Virtual paths (e.g. "#search?tag=") are ignored.
  Future<bool> addRecentPath(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_isVirtualPath(trimmed)) return false;

    final existing = await getRecentPaths(
      limit: maxRecentPaths,
      validateDirectories: false,
    );

    final List<String> updated = <String>[];
    updated.add(trimmed);
    for (final p in existing) {
      if (_pathsEqual(p, trimmed)) continue;
      updated.add(p);
      if (updated.length >= maxRecentPaths) break;
    }

    return await _savePreference<String>(_recentPathsKey, json.encode(updated));
  }

  /// Clear all stored recent paths.
  Future<bool> clearRecentPaths() async {
    return await _deletePreference(_recentPathsKey);
  }

  /// Get current view mode preference (list or grid)
  Future<ViewMode> getViewMode() async {
    int viewModeIndex = await _getPreference<int>(
          _viewModeKey,
          defaultValue: 0,
        ) ??
        0;
    if (viewModeIndex < 0 || viewModeIndex >= ViewMode.values.length) {
      return ViewMode.list;
    }
    return ViewMode.values[viewModeIndex];
  }

  /// Save view mode preference
  Future<bool> setViewMode(ViewMode viewMode) async {
    return await _savePreference<int>(_viewModeKey, viewMode.index);
  }

  /// Get current sort option preference
  Future<SortOption> getSortOption() async {
    int sortOptionIndex = await _getPreference<int>(
          _sortOptionKey,
          defaultValue: 0,
        ) ??
        0;
    return SortOption.values[sortOptionIndex];
  }

  /// Save sort option preference
  Future<bool> setSortOption(SortOption sortOption) async {
    return await _savePreference<int>(_sortOptionKey, sortOption.index);
  }

  /// Get grid zoom level preference
  Future<int> getGridZoomLevel() async {
    return await _getPreference<int>(
          _gridZoomLevelKey,
          defaultValue: defaultGridZoomLevel,
        ) ??
        defaultGridZoomLevel;
  }

  /// Save grid zoom level preference
  Future<bool> setGridZoomLevel(int zoomLevel) async {
    // Ensure the zoom level is within bounds
    final validZoom = zoomLevel.clamp(minGridZoomLevel, maxGridZoomLevel);
    return await _savePreference<int>(_gridZoomLevelKey, validZoom);
  }

  /// Get video player volume preference (0-100)
  Future<double> getVideoPlayerVolume() async {
    return await _getPreference<double>(
          _videoPlayerVolumeKey,
          defaultValue: 70.0,
        ) ??
        70.0;
  }

  /// Save video player volume preference (0-100)
  Future<bool> setVideoPlayerVolume(double volume) async {
    // Ensure volume is within bounds (0 to 100)
    double validVolume = volume.clamp(0.0, 100.0);
    return await _savePreference<double>(_videoPlayerVolumeKey, validVolume);
  }

  /// Get video player mute state
  Future<bool> getVideoPlayerMute() async {
    return await _getPreference<bool>(
          _videoPlayerMuteKey,
          defaultValue: false,
        ) ??
        false;
  }

  /// Save video player mute state
  Future<bool> setVideoPlayerMute(bool isMuted) async {
    return await _savePreference<bool>(_videoPlayerMuteKey, isMuted);
  }

  /// Get drawer pinned state
  Future<bool> getDrawerPinned() async {
    return await _getPreference<bool>(
          _drawerPinnedKey,
          defaultValue: false,
        ) ??
        false;
  }

  /// Save drawer pinned state
  Future<bool> setDrawerPinned(bool isPinned) async {
    return await _savePreference<bool>(_drawerPinnedKey, isPinned);
  }

  /// Get current theme preference
  Future<ThemePreference> getThemePreference() async {
    int themeIndex = await _getPreference<int>(
          _themePreferenceKey,
          defaultValue: 0,
        ) ??
        0;
    return ThemePreference.values[themeIndex];
  }

  /// Get ThemeMode based on theme preference
  Future<ThemeMode> getThemeMode() async {
    final preference = await getThemePreference();
    switch (preference) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
      default:
        return ThemeMode.system;
    }
  }

  /// Save theme preference and notify listeners
  Future<bool> setThemePreference(ThemePreference preference) async {
    bool result =
        await _savePreference<int>(_themePreferenceKey, preference.index);

    if (result) {
      // Notify listeners about the theme change
      final themeMode = await getThemeMode();
      _themeChangeController.add(themeMode);
    }
    return result;
  }

  /// Get video thumbnail timestamp preference (in seconds)
  Future<int> getVideoThumbnailTimestamp() async {
    return await _getPreference<int>(
          _videoThumbnailTimestampKey,
          defaultValue: defaultVideoThumbnailTimestamp,
        ) ??
        defaultVideoThumbnailTimestamp;
  }

  /// Save video thumbnail timestamp preference
  Future<bool> setVideoThumbnailTimestamp(int seconds) async {
    // Ensure the timestamp is within bounds
    final validTimestamp =
        seconds.clamp(minVideoThumbnailTimestamp, maxVideoThumbnailTimestamp);
    return await _savePreference<int>(
        _videoThumbnailTimestampKey, validTimestamp);
  }

  /// Get video thumbnail position preference (as percentage of video duration)
  Future<int> getVideoThumbnailPercentage() async {
    return await _getPreference<int>(
          _videoThumbnailPercentageKey,
          defaultValue: defaultVideoThumbnailPercentage,
        ) ??
        defaultVideoThumbnailPercentage;
  }

  /// Save video thumbnail position preference (as percentage of video duration)
  Future<bool> setVideoThumbnailPercentage(int percentage) async {
    // Ensure the percentage is within bounds
    final validPercentage = percentage.clamp(
        minVideoThumbnailPercentage, maxVideoThumbnailPercentage);
    return await _savePreference<int>(
        _videoThumbnailPercentageKey, validPercentage);
  }

  /// Get thumbnail generation mode preference
  /// Returns 'fast' for OS built-in methods, 'custom' for FFmpeg with timestamp
  Future<String> getThumbnailMode() async {
    return await _getPreference<String>(
          _thumbnailModeKey,
          defaultValue: defaultThumbnailMode,
        ) ??
        defaultThumbnailMode;
  }

  /// Save thumbnail generation mode preference
  /// mode: 'fast' for OS built-in, 'custom' for FFmpeg with user timestamp
  Future<bool> setThumbnailMode(String mode) async {
    // Validate mode value
    final validMode =
        (mode == 'fast' || mode == 'custom') ? mode : defaultThumbnailMode;
    return await _savePreference<String>(_thumbnailModeKey, validMode);
  }

  /// Get max thumbnail generation concurrency
  Future<int> getMaxThumbnailConcurrency() async {
    return await _getPreference<int>(
          _maxThumbnailConcurrencyKey,
          defaultValue: defaultThumbnailConcurrency,
        ) ??
        defaultThumbnailConcurrency;
  }

  /// Save max thumbnail generation concurrency
  Future<bool> setMaxThumbnailConcurrency(int concurrency) async {
    final validConcurrency =
        concurrency.clamp(minThumbnailConcurrency, maxThumbnailConcurrency);
    return await _savePreference<int>(
        _maxThumbnailConcurrencyKey, validConcurrency);
  }

  /// Search tip shown preference
  Future<bool> getSearchTipShown() async {
    return await _getPreference<bool>(
          _keySearchTipShown,
          defaultValue: false,
        ) ??
        false;
  }

  Future<void> setSearchTipShown(bool shown) async {
    await _savePreference<bool>(_keySearchTipShown, shown);
  }

  // Generic methods for video player settings
  Future<void> setVideoPlayerString(String key, String value) async {
    await _savePreference<String>(key, value);
  }

  Future<String?> getVideoPlayerString(String key,
      {String? defaultValue}) async {
    return await _getPreference<String>(key, defaultValue: defaultValue);
  }

  Future<void> setVideoPlayerBool(String key, bool value) async {
    await _savePreference<bool>(key, value);
  }

  Future<bool?> getVideoPlayerBool(String key, {bool? defaultValue}) async {
    return await _getPreference<bool>(key, defaultValue: defaultValue);
  }

  Future<void> setVideoPlayerInt(String key, int value) async {
    await _savePreference<int>(key, value);
  }

  Future<int?> getVideoPlayerInt(String key, {int? defaultValue}) async {
    return await _getPreference<int>(key, defaultValue: defaultValue);
  }

  /// Export preferences to a JSON file with custom destination
  Future<String?> exportPreferences({String? customPath}) async {
    try {
      // Get all settings
      final settingsMap = getAllSettings();
      final jsonData = jsonEncode(settingsMap);

      String filePath;

      if (customPath != null) {
        // Use the provided custom path
        filePath = customPath;
      } else {
        // Generate a default path in app documents directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        filePath =
            path.join(directory.path, 'coolbird_preferences_$timestamp.json');
      }

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonData);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Import preferences from a JSON file
  Future<bool> importPreferences() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> preferencesMap = jsonDecode(jsonString);

        for (final key in preferencesMap.keys) {
          final value = preferencesMap[key];
          if (value is int) {
            await _preferences?.setInt(key, value);
          } else if (value is double) {
            await _preferences?.setDouble(key, value);
          } else if (value is bool) {
            await _preferences?.setBool(key, value);
          } else if (value is String) {
            await _preferences?.setString(key, value);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Export all data (preferences and database) to a user-selected location
  Future<String?> exportAllData() async {
    try {
      // Ask user to select export directory
      String? customDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save backup',
      );

      if (customDir == null) {
        return null; // User cancelled
      }

      // Create a directory to store all export files
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportDirName = 'coolbird_export_$timestamp';
      final exportDir = Directory(path.join(customDir, exportDirName));

      // Create the directory if it doesn't exist
      await exportDir.create();

      // Export preferences
      final Map<String, dynamic> preferencesMap = getAllSettings();
      final prefsJsonString = jsonEncode(preferencesMap);
      final prefsFilePath = path.join(exportDir.path, 'preferences.json');
      final prefsFile = File(prefsFilePath);
      await prefsFile.writeAsString(prefsJsonString);

      // Export database
      bool databaseExported = false;
      if (_useObjectBox) {
        _databaseManager ??= DatabaseManager.getInstance();
        if (_databaseManager!.isInitialized()) {
          // Get all tags in the system
          final Map<String, List<String>> tagsData = {};
          final uniqueTags = await _databaseManager!.getAllUniqueTags();

          // For each tag, get all files with that tag
          for (final tag in uniqueTags) {
            final files = await _databaseManager!.findFilesByTag(tag);
            tagsData[tag] = files;
          }

          // Create a data structure to export
          final Map<String, dynamic> exportData = {
            'tags': tagsData,
            'exportDate': DateTime.now().toIso8601String(),
            'version': '1.0'
          };

          // Convert to JSON
          final dbJsonString = jsonEncode(exportData);
          final dbFilePath = path.join(exportDir.path, 'database.json');
          final dbFile = File(dbFilePath);
          await dbFile.writeAsString(dbJsonString);
          databaseExported = true;
        }
      }

      // Create a manifest file
      final manifestData = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'components': {'preferences': true, 'database': databaseExported}
      };

      final manifestJsonString = jsonEncode(manifestData);
      final manifestFilePath = path.join(exportDir.path, 'manifest.json');
      final manifestFile = File(manifestFilePath);
      await manifestFile.writeAsString(manifestJsonString);

      return exportDir.path;
    } catch (e) {
      return null;
    }
  }

  /// Import all data (preferences and database) from a user-selected location
  Future<bool> importAllData() async {
    try {
      // Ask user to select the export directory to import from
      String? importDirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select backup folder to import',
      );

      if (importDirPath == null) {
        return false; // User cancelled
      }

      final importDir = Directory(importDirPath);
      if (!await importDir.exists()) {
        return false;
      }

      // Check for manifest file
      final manifestFile = File(path.join(importDirPath, 'manifest.json'));
      if (!await manifestFile.exists()) {
        // Try to look for individual files even without manifest
      } else {
        // Read manifest to verify contents
        final String manifestContent = await manifestFile.readAsString();
        jsonDecode(manifestContent);
      }

      // Try to import preferences
      bool prefsImported = false;
      final prefsFile = File(path.join(importDirPath, 'preferences.json'));
      if (await prefsFile.exists()) {
        final String prefsContent = await prefsFile.readAsString();
        try {
          final Map<String, dynamic> prefsData = jsonDecode(prefsContent);

          // Save all preferences
          for (final key in prefsData.keys) {
            final dynamic value = prefsData[key];

            if (value is String) {
              await _preferences?.setString(key, value);
            } else if (value is int) {
              await _preferences?.setInt(key, value);
            } else if (value is double) {
              await _preferences?.setDouble(key, value);
            } else if (value is bool) {
              await _preferences?.setBool(key, value);
            }
            // Skip other types as SharedPreferences doesn't support them
          }

          prefsImported = true;
        } catch (e) {
          debugPrint('Error importing preferences: $e');
        }
      }

      // Try to import database
      bool dbImported = false;
      final dbFile = File(path.join(importDirPath, 'database.json'));
      if (await dbFile.exists()) {
        try {
          // Make sure database manager is initialized
          _databaseManager ??= DatabaseManager.getInstance();
          await _databaseManager!.initialize();

          // Read database file
          final String dbContent = await dbFile.readAsString();
          final Map<String, dynamic> dbData = jsonDecode(dbContent);

          // Check that tags exist in the data
          if (dbData.containsKey('tags')) {
            final Map<String, dynamic> tagsData = dbData['tags'];

            // Import each tag and its associated files
            for (final tag in tagsData.keys) {
              final List<dynamic> files = tagsData[tag];

              // Add the tag to each file
              for (final file in files) {
                if (file is String) {
                  // Check if file exists before adding tag
                  final fileExists = File(file).existsSync();
                  if (fileExists) {
                    await _databaseManager!.addTagToFile(file, tag);
                  }
                }
              }
            }
            dbImported = true;
          }
        } catch (e) {
          debugPrint('Error importing database: $e');
        }
      }

      return prefsImported || dbImported;
    } catch (e) {
      return false;
    }
  }

  /// Get all settings as a Map
  Map<String, dynamic> getAllSettings() {
    final Map<String, dynamic> settings = {};

    if (_preferences != null) {
      settings.addAll(
          _preferences!.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
        map[key] = _preferences!.get(key);
        return map;
      }));
    }

    return settings;
  }

  /// Dispose resources
  void dispose() {
    _themeChangeController.close();
  }

  /// Get column visibility settings for details view
  Future<ColumnVisibility> getColumnVisibility() async {
    String? columnVisibilityJson =
        await _getPreference<String>(_columnVisibilityKey);

    if (columnVisibilityJson == null) {
      return const ColumnVisibility(); // Use default
    }

    try {
      final Map<String, dynamic> map =
          json.decode(columnVisibilityJson) as Map<String, dynamic>;
      return ColumnVisibility.fromMap(map);
    } catch (e) {
      return const ColumnVisibility(); // Use default on error
    }
  }

  /// Save column visibility settings
  Future<bool> setColumnVisibility(ColumnVisibility visibility) async {
    final String jsonData = json.encode(visibility.toMap());
    return await _savePreference<String>(_columnVisibilityKey, jsonData);
  }

  /// Get show file tags setting
  Future<bool> getShowFileTags() async {
    return await _getPreference<bool>(
          _showFileTagsKey,
          defaultValue: true, // Default to showing tags
        ) ??
        true;
  }

  /// Save show file tags setting
  Future<bool> setShowFileTags(bool showTags) async {
    return await _savePreference<bool>(_showFileTagsKey, showTags);
  }

  /// Use system default app for video (when true). Default false = use in-app player.
  Future<bool> getUseSystemDefaultForVideo() async {
    return await _getPreference<bool>(
          _useSystemDefaultForVideoKey,
          defaultValue: false,
        ) ??
        false;
  }

  Future<bool> setUseSystemDefaultForVideo(bool value) async {
    return await _savePreference<bool>(_useSystemDefaultForVideoKey, value);
  }

  /// Preferred external app identifier for video playback.
  /// Android: package name, Windows: executable path, null/empty: no override.
  Future<String?> getPreferredVideoPlayerApp() async {
    final value = await _getPreference<String>(_preferredVideoPlayerAppKey);
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<bool> setPreferredVideoPlayerApp(String appIdentifier) async {
    final normalized = appIdentifier.trim();
    if (normalized.isEmpty) {
      return await _deletePreference(_preferredVideoPlayerAppKey);
    }
    return await _savePreference<String>(
      _preferredVideoPlayerAppKey,
      normalized,
    );
  }

  Future<bool> clearPreferredVideoPlayerApp() async {
    return await _deletePreference(_preferredVideoPlayerAppKey);
  }

  /// Get preview pane visibility
  Future<bool> getPreviewPaneVisible() async {
    return await _getPreference<bool>(
          _previewPaneVisibleKey,
          defaultValue: true,
        ) ??
        true;
  }

  /// Save preview pane visibility
  Future<bool> setPreviewPaneVisible(bool visible) async {
    return await _savePreference<bool>(_previewPaneVisibleKey, visible);
  }

  /// Get preview pane width
  Future<double> getPreviewPaneWidth() async {
    return await _getPreference<double>(
          _previewPaneWidthKey,
          defaultValue: defaultPreviewPaneWidth,
        ) ??
        defaultPreviewPaneWidth;
  }

  /// Save preview pane width
  Future<bool> setPreviewPaneWidth(double width) async {
    return await _savePreference<double>(_previewPaneWidthKey, width);
  }
}
