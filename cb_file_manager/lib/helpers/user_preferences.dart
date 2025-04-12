import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';

/// A class to manage user preferences for the application
class UserPreferences {
  static final UserPreferences _instance = UserPreferences._internal();
  SharedPreferences? _preferences;

  // Shared preferences keys
  static const String _viewModeKey = 'view_mode';
  static const String _sortOptionKey = 'sort_option';
  static const String _gridZoomLevelKey = 'grid_zoom_level';
  static const String _lastFolderKey = 'last_accessed_folder';
  static const String _imageGalleryThumbnailSizeKey =
      'image_gallery_thumbnail_size';
  static const String _videoGalleryThumbnailSizeKey =
      'video_gallery_thumbnail_size';

  // Constants for grid zoom level
  static const int minGridZoomLevel = 2; // Largest thumbnails (2 per row)
  static const int maxGridZoomLevel = 15; // Smallest thumbnails (15 per row)
  static const int defaultGridZoomLevel = 4; // Default (4 per row)

  // Constants for thumbnail sizes
  static const double minThumbnailSize = 2.0;
  static const double maxThumbnailSize = 10.0;
  static const double defaultThumbnailSize = 3.0;

  factory UserPreferences() {
    return _instance;
  }

  UserPreferences._internal();

  /// Initialize the preferences
  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  /// Get image gallery thumbnail size (as grid count - higher means smaller thumbnails)
  double getImageGalleryThumbnailSize() {
    return _preferences?.getDouble(_imageGalleryThumbnailSizeKey) ??
        defaultThumbnailSize;
  }

  /// Set image gallery thumbnail size
  Future<bool> setImageGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);
    return await _preferences?.setDouble(
            _imageGalleryThumbnailSizeKey, validSize) ??
        false;
  }

  /// Get video gallery thumbnail size (as grid count - higher means smaller thumbnails)
  double getVideoGalleryThumbnailSize() {
    return _preferences?.getDouble(_videoGalleryThumbnailSizeKey) ??
        defaultThumbnailSize;
  }

  /// Set video gallery thumbnail size
  Future<bool> setVideoGalleryThumbnailSize(double size) async {
    // Ensure the size is within bounds
    double validSize = size.clamp(minThumbnailSize, maxThumbnailSize);
    return await _preferences?.setDouble(
            _videoGalleryThumbnailSizeKey, validSize) ??
        false;
  }

  /// Get the last accessed folder path with validation
  String? getLastAccessedFolder() {
    final folderPath = _preferences?.getString(_lastFolderKey);

    // Add validation to ensure the folder exists before returning it
    if (folderPath != null) {
      try {
        final directory = Directory(folderPath);
        // Only return the path if the directory exists and is accessible
        if (directory.existsSync()) {
          return folderPath;
        } else {
          // If directory doesn't exist, clear the preference
          _preferences?.remove(_lastFolderKey);
          return null;
        }
      } catch (e) {
        print('Error validating last accessed folder: $e');
        // If there's an error, clear the preference
        _preferences?.remove(_lastFolderKey);
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
        return await _preferences?.setString(_lastFolderKey, folderPath) ??
            false;
      }
      return false;
    } catch (e) {
      print('Error saving last accessed folder: $e');
      return false;
    }
  }

  /// Clear the last accessed folder preference
  Future<bool> clearLastAccessedFolder() async {
    return await _preferences?.remove(_lastFolderKey) ?? false;
  }

  /// Get current view mode preference (list or grid)
  ViewMode getViewMode() {
    final int viewModeIndex = _preferences?.getInt(_viewModeKey) ?? 0;
    return ViewMode.values[viewModeIndex];
  }

  /// Save view mode preference
  Future<bool> setViewMode(ViewMode viewMode) async {
    return await _preferences?.setInt(_viewModeKey, viewMode.index) ?? false;
  }

  /// Get current sort option preference
  SortOption getSortOption() {
    final int sortOptionIndex = _preferences?.getInt(_sortOptionKey) ?? 0;
    return SortOption.values[sortOptionIndex];
  }

  /// Save sort option preference
  Future<bool> setSortOption(SortOption sortOption) async {
    return await _preferences?.setInt(_sortOptionKey, sortOption.index) ??
        false;
  }

  /// Get grid zoom level preference
  int getGridZoomLevel() {
    return _preferences?.getInt(_gridZoomLevelKey) ?? defaultGridZoomLevel;
  }

  /// Save grid zoom level preference
  Future<bool> setGridZoomLevel(int zoomLevel) async {
    // Ensure the zoom level is within bounds
    final validZoom = zoomLevel.clamp(minGridZoomLevel, maxGridZoomLevel);
    return await _preferences?.setInt(_gridZoomLevelKey, validZoom) ?? false;
  }
}
