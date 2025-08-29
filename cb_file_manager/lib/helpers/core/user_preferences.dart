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

  // Constants for grid zoom level
  static const int minGridZoomLevel = 2; // Largest thumbnails (2 per row)
  static const int maxGridZoomLevel = 15; // Smallest thumbnails (15 per row)
  static const int defaultGridZoomLevel = 4; // Default (4 per row)

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

  /// Get image gallery thumbnail size (as grid count - higher means smaller thumbnails)
  Future<double> getImageGalleryThumbnailSize() async {
    if (_useObjectBox) {
      return await _databaseManager!.getDoublePreference(
            _imageGalleryThumbnailSizeKey,
            defaultValue: defaultThumbnailSize,
          ) ??
          defaultThumbnailSize;
    }
    return _preferences?.getDouble(_imageGalleryThumbnailSizeKey) ??
        defaultThumbnailSize;
  }

  /// Set image gallery thumbnail size
  Future<bool> setImageGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);

    if (_useObjectBox) {
      return await _databaseManager!.saveDoublePreference(
        _imageGalleryThumbnailSizeKey,
        validSize,
      );
    }

    return await _preferences?.setDouble(
            _imageGalleryThumbnailSizeKey, validSize) ??
        false;
  }

  /// Get video gallery thumbnail size (as grid count - higher means smaller thumbnails)
  Future<double> getVideoGalleryThumbnailSize() async {
    if (_useObjectBox) {
      return await _databaseManager!.getDoublePreference(
            _videoGalleryThumbnailSizeKey,
            defaultValue: defaultThumbnailSize,
          ) ??
          defaultThumbnailSize;
    }

    return _preferences?.getDouble(_videoGalleryThumbnailSizeKey) ??
        defaultThumbnailSize;
  }

  /// Set video gallery thumbnail size
  Future<bool> setVideoGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);

    if (_useObjectBox) {
      return await _databaseManager!.saveDoublePreference(
        _videoGalleryThumbnailSizeKey,
        validSize,
      );
    }

    return await _preferences?.setDouble(
            _videoGalleryThumbnailSizeKey, validSize) ??
        false;
  }

  /// Get the last accessed folder path with validation
  Future<String?> getLastAccessedFolder() async {
    String? folderPath;

    if (_useObjectBox) {
      folderPath = await _databaseManager!.getStringPreference(_lastFolderKey);
    } else {
      folderPath = _preferences?.getString(_lastFolderKey);
    }

    // Add validation to ensure the folder exists before returning it
    if (folderPath != null) {
      try {
        final directory = Directory(folderPath);
        // Only return the path if the directory exists and is accessible
        if (directory.existsSync()) {
          return folderPath;
        } else {
          // If directory doesn't exist, clear the preference
          if (_useObjectBox) {
            await _databaseManager!.deletePreference(_lastFolderKey);
          } else {
            await _preferences?.remove(_lastFolderKey);
          }
          return null;
        }
      } catch (e) {
        // If there's an error, clear the preference
        if (_useObjectBox) {
          await _databaseManager!.deletePreference(_lastFolderKey);
        } else {
          await _preferences?.remove(_lastFolderKey);
        }
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
        if (_useObjectBox) {
          return await _databaseManager!.saveStringPreference(
            _lastFolderKey,
            folderPath,
          );
        }

        return await _preferences?.setString(_lastFolderKey, folderPath) ??
            false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clear the last accessed folder preference
  Future<bool> clearLastAccessedFolder() async {
    if (_useObjectBox) {
      return await _databaseManager!.deletePreference(_lastFolderKey);
    }

    return await _preferences?.remove(_lastFolderKey) ?? false;
  }

  /// Get current view mode preference (list or grid)
  Future<ViewMode> getViewMode() async {
    int viewModeIndex;

    if (_useObjectBox) {
      viewModeIndex = await _databaseManager!.getIntPreference(
            _viewModeKey,
            defaultValue: 0,
          ) ??
          0;
    } else {
      viewModeIndex = _preferences?.getInt(_viewModeKey) ?? 0;
    }

    return ViewMode.values[viewModeIndex];
  }

  /// Save view mode preference
  Future<bool> setViewMode(ViewMode viewMode) async {
    if (_useObjectBox) {
      return await _databaseManager!.saveIntPreference(
        _viewModeKey,
        viewMode.index,
      );
    }

    return await _preferences?.setInt(_viewModeKey, viewMode.index) ?? false;
  }

  /// Get current sort option preference
  Future<SortOption> getSortOption() async {
    int sortOptionIndex;

    if (_useObjectBox) {
      sortOptionIndex = await _databaseManager!.getIntPreference(
            _sortOptionKey,
            defaultValue: 0,
          ) ??
          0;
    } else {
      sortOptionIndex = _preferences?.getInt(_sortOptionKey) ?? 0;
    }

    return SortOption.values[sortOptionIndex];
  }

  /// Save sort option preference
  Future<bool> setSortOption(SortOption sortOption) async {
    if (_useObjectBox) {
      return await _databaseManager!.saveIntPreference(
        _sortOptionKey,
        sortOption.index,
      );
    }

    return await _preferences?.setInt(_sortOptionKey, sortOption.index) ??
        false;
  }

  /// Get grid zoom level preference
  Future<int> getGridZoomLevel() async {
    if (_useObjectBox) {
      return await _databaseManager!.getIntPreference(
            _gridZoomLevelKey,
            defaultValue: defaultGridZoomLevel,
          ) ??
          defaultGridZoomLevel;
    }

    return _preferences?.getInt(_gridZoomLevelKey) ?? defaultGridZoomLevel;
  }

  /// Save grid zoom level preference
  Future<bool> setGridZoomLevel(int zoomLevel) async {
    // Ensure the zoom level is within bounds
    final validZoom = zoomLevel.clamp(minGridZoomLevel, maxGridZoomLevel);

    if (_useObjectBox) {
      return await _databaseManager!.saveIntPreference(
        _gridZoomLevelKey,
        validZoom,
      );
    }

    return await _preferences?.setInt(_gridZoomLevelKey, validZoom) ?? false;
  }

  /// Get video player volume preference (0-100)
  Future<double> getVideoPlayerVolume() async {
    if (_useObjectBox) {
      return await _databaseManager!.getDoublePreference(
            _videoPlayerVolumeKey,
            defaultValue: 70.0,
          ) ??
          70.0;
    }

    return _preferences?.getDouble(_videoPlayerVolumeKey) ?? 70.0;
  }

  /// Save video player volume preference (0-100)
  Future<bool> setVideoPlayerVolume(double volume) async {
    // Ensure volume is within bounds (0 to 100)
    double validVolume = volume.clamp(0.0, 100.0);

    if (_useObjectBox) {
      return await _databaseManager!.saveDoublePreference(
        _videoPlayerVolumeKey,
        validVolume,
      );
    }

    return await _preferences?.setDouble(_videoPlayerVolumeKey, validVolume) ??
        false;
  }

  /// Get video player mute state
  Future<bool> getVideoPlayerMute() async {
    if (_useObjectBox) {
      return await _databaseManager!.getBoolPreference(
            _videoPlayerMuteKey,
            defaultValue: false,
          ) ??
          false;
    }

    return _preferences?.getBool(_videoPlayerMuteKey) ?? false;
  }

  /// Save video player mute state
  Future<bool> setVideoPlayerMute(bool isMuted) async {
    if (_useObjectBox) {
      return await _databaseManager!.saveBoolPreference(
        _videoPlayerMuteKey,
        isMuted,
      );
    }

    return await _preferences?.setBool(_videoPlayerMuteKey, isMuted) ?? false;
  }

  /// Get drawer pinned state
  Future<bool> getDrawerPinned() async {
    if (_useObjectBox) {
      return await _databaseManager!.getBoolPreference(
            _drawerPinnedKey,
            defaultValue: false,
          ) ??
          false;
    }

    return _preferences?.getBool(_drawerPinnedKey) ?? false;
  }

  /// Save drawer pinned state
  Future<bool> setDrawerPinned(bool isPinned) async {
    if (_useObjectBox) {
      return await _databaseManager!.saveBoolPreference(
        _drawerPinnedKey,
        isPinned,
      );
    }

    return await _preferences?.setBool(_drawerPinnedKey, isPinned) ?? false;
  }

  /// Get current theme preference
  Future<ThemePreference> getThemePreference() async {
    int themeIndex;

    if (_useObjectBox) {
      themeIndex = await _databaseManager!.getIntPreference(
            _themePreferenceKey,
            defaultValue: 0,
          ) ??
          0;
    } else {
      themeIndex = _preferences?.getInt(_themePreferenceKey) ?? 0;
    }

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
    bool result;

    if (_useObjectBox) {
      result = await _databaseManager!.saveIntPreference(
        _themePreferenceKey,
        preference.index,
      );
    } else {
      result =
          await _preferences?.setInt(_themePreferenceKey, preference.index) ??
              false;
    }

    if (result) {
      // Notify listeners about the theme change
      final themeMode = await getThemeMode();
      _themeChangeController.add(themeMode);
    }
    return result;
  }

  /// Get video thumbnail timestamp preference (in seconds)
  Future<int> getVideoThumbnailTimestamp() async {
    if (_useObjectBox) {
      return await _databaseManager!.getIntPreference(
            _videoThumbnailTimestampKey,
            defaultValue: defaultVideoThumbnailTimestamp,
          ) ??
          defaultVideoThumbnailTimestamp;
    }

    return _preferences?.getInt(_videoThumbnailTimestampKey) ??
        defaultVideoThumbnailTimestamp;
  }

  /// Save video thumbnail timestamp preference
  Future<bool> setVideoThumbnailTimestamp(int seconds) async {
    // Ensure the timestamp is within bounds
    final validTimestamp =
        seconds.clamp(minVideoThumbnailTimestamp, maxVideoThumbnailTimestamp);

    if (_useObjectBox) {
      return await _databaseManager!.saveIntPreference(
        _videoThumbnailTimestampKey,
        validTimestamp,
      );
    }

    return await _preferences?.setInt(
            _videoThumbnailTimestampKey, validTimestamp) ??
        false;
  }

  /// Get video thumbnail position preference (as percentage of video duration)
  Future<int> getVideoThumbnailPercentage() async {
    if (_useObjectBox) {
      return await _databaseManager!.getIntPreference(
            _videoThumbnailPercentageKey,
            defaultValue: defaultVideoThumbnailPercentage,
          ) ??
          defaultVideoThumbnailPercentage;
    }

    return _preferences?.getInt(_videoThumbnailPercentageKey) ??
        defaultVideoThumbnailPercentage;
  }

  /// Save video thumbnail position preference (as percentage of video duration)
  Future<bool> setVideoThumbnailPercentage(int percentage) async {
    // Ensure the percentage is within bounds
    final validPercentage = percentage.clamp(
        minVideoThumbnailPercentage, maxVideoThumbnailPercentage);

    if (_useObjectBox) {
      return await _databaseManager!.saveIntPreference(
        _videoThumbnailPercentageKey,
        validPercentage,
      );
    }

    return await _preferences?.setInt(
            _videoThumbnailPercentageKey, validPercentage) ??
        false;
  }

  /// Search tip shown preference
  Future<bool> getSearchTipShown() async {
    if (_useObjectBox) {
      return await _databaseManager!.getBoolPreference(
            _keySearchTipShown,
            defaultValue: false,
          ) ??
          false;
    }

    return _preferences?.getBool(_keySearchTipShown) ?? false;
  }

  Future<void> setSearchTipShown(bool shown) async {
    if (_useObjectBox) {
      await _databaseManager!.saveBoolPreference(_keySearchTipShown, shown);
    } else {
      await _preferences?.setBool(_keySearchTipShown, shown);
    }
  }

  // Generic methods for video player settings
  Future<void> setVideoPlayerString(String key, String value) async {
    if (_useObjectBox) {
      await _databaseManager!.saveStringPreference(key, value);
    } else {
      await _preferences?.setString(key, value);
    }
  }

  Future<String?> getVideoPlayerString(String key, {String? defaultValue}) async {
    if (_useObjectBox) {
      return await _databaseManager!.getStringPreference(key, defaultValue: defaultValue);
    } else {
      return _preferences?.getString(key) ?? defaultValue;
    }
  }

  Future<void> setVideoPlayerBool(String key, bool value) async {
    if (_useObjectBox) {
      await _databaseManager!.saveBoolPreference(key, value);
    } else {
      await _preferences?.setBool(key, value);
    }
  }

  Future<bool?> getVideoPlayerBool(String key, {bool? defaultValue}) async {
    if (_useObjectBox) {
      return await _databaseManager!.getBoolPreference(key, defaultValue: defaultValue);
    } else {
      return _preferences?.getBool(key) ?? defaultValue;
    }
  }

  Future<void> setVideoPlayerInt(String key, int value) async {
    if (_useObjectBox) {
      await _databaseManager!.saveIntPreference(key, value);
    } else {
      await _preferences?.setInt(key, value);
    }
  }

  Future<int?> getVideoPlayerInt(String key, {int? defaultValue}) async {
    if (_useObjectBox) {
      return await _databaseManager!.getIntPreference(key, defaultValue: defaultValue);
    } else {
      return _preferences?.getInt(key) ?? defaultValue;
    }
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
    String? columnVisibilityJson;

    if (_useObjectBox) {
      columnVisibilityJson = await _databaseManager!.getStringPreference(
        _columnVisibilityKey,
      );
    } else {
      columnVisibilityJson = _preferences?.getString(_columnVisibilityKey);
    }

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

    if (_useObjectBox) {
      return await _databaseManager!.saveStringPreference(
        _columnVisibilityKey,
        jsonData,
      );
    }

    return await _preferences?.setString(_columnVisibilityKey, jsonData) ??
        false;
  }
}
