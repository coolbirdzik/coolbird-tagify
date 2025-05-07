import 'dart:io';
import 'package:cb_file_manager/models/database/database_provider.dart';
import 'package:cb_file_manager/models/objectbox/file_tag.dart';
import 'package:cb_file_manager/models/objectbox/user_preference.dart';
import 'package:objectbox/objectbox.dart';
import '../../objectbox.g.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// ObjectBox database provider
class ObjectBoxDatabaseProvider implements IDatabaseProvider {
  // Static store instance shared across all instances
  static Store? _sharedStore;
  static final Map<String, bool> _openingStores = {};
  static final Object _storeLock = Object();

  /// ObjectBox store
  Store? _store;

  /// Box for file tags
  Box<FileTag>? _fileTagBox;

  /// Box for user preferences
  Box<UserPreference>? _preferenceBox;

  /// Flag to indicate if cloud sync is enabled
  bool _isCloudSyncEnabled = false;

  /// Flag to indicate if the provider is initialized
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(path.join(dir.path, 'CBFileManager'));

      if (!dbDir.existsSync()) {
        dbDir.createSync(recursive: true);
      }

      // Use synchronized access to the shared store
      await _initSharedStore(dbDir.path);

      // Initialize the boxes
      _fileTagBox = _store!.box<FileTag>();
      _preferenceBox = _store!.box<UserPreference>();

      _isInitialized = true;
      print('ObjectBox provider initialized successfully');
    } catch (e) {
      print('Error initializing ObjectBox: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Initialize the shared store
  Future<void> _initSharedStore(String dbPath) async {
    // If we already have a local store reference, use it
    if (_store != null) return;

    // Simple retry mechanism
    int retries = 0;
    const maxRetries = 5;

    while (retries < maxRetries) {
      // Check if shared store is already available
      if (_sharedStore != null) {
        _store = _sharedStore;
        print('Using existing shared ObjectBox store');
        return;
      }

      // Try to create the store if no one else is doing it
      String storeKey = dbPath;
      bool canOpenStore = false;

      // Use synchronized block for thread safety
      synchronized(_storeLock, () {
        if (!_openingStores.containsKey(storeKey) ||
            !_openingStores[storeKey]!) {
          _openingStores[storeKey] = true;
          canOpenStore = true;
        }
      });

      if (canOpenStore) {
        try {
          // Double-check that another thread didn't create it while we were waiting
          if (_sharedStore != null) {
            _store = _sharedStore;
            _openingStores[storeKey] = false;
            return;
          }

          // Make sure the directory exists
          Directory dir = Directory(dbPath);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }

          // Clear any potential lock files that might be stuck
          _clearLockFiles(dbPath);

          // Open new store with increased timeout
          _sharedStore = await openStore(directory: dbPath);
          _store = _sharedStore;
          print('ObjectBox store initialized successfully at: $dbPath');
          _openingStores[storeKey] = false;
          return;
        } catch (e) {
          print('Error opening ObjectBox store (attempt ${retries + 1}): $e');
          _openingStores[storeKey] = false;
          retries++;
          if (retries >= maxRetries) {
            print('Failed to initialize ObjectBox after $maxRetries attempts');
            rethrow;
          }

          // Exponential backoff - wait longer between retries
          await Future.delayed(Duration(milliseconds: 500 * (1 << retries)));
        }
      } else {
        // Wait a bit if someone else is opening the store
        await Future.delayed(Duration(milliseconds: 300));
        retries++;
      }
    }
  }

  /// Helper method to clear any lock files that might be preventing database open
  void _clearLockFiles(String dbPath) {
    try {
      final lockFile = File('$dbPath/data.mdb.lock');
      if (lockFile.existsSync()) {
        print('Found stale lock file, removing: ${lockFile.path}');
        lockFile.deleteSync();
      }
    } catch (e) {
      print('Error clearing lock files: $e');
    }
  }

  /// Helper method for synchronized blocks (simplified version)
  void synchronized(Object lock, Function() action) {
    action();
  }

  @override
  bool isInitialized() {
    return _isInitialized;
  }

  @override
  Future<void> close() async {
    // We don't close the shared store from individual providers
    _isInitialized = false;
  }

  // Static method to close the shared store - call this when app shutting down
  static void closeSharedStore() {
    if (_sharedStore != null) {
      _sharedStore!.close();
      _sharedStore = null;
    }
  }

  @override
  Future<bool> addTagToFile(String filePath, String tag) async {
    if (!_isInitialized) await initialize();

    try {
      // Find if tag already exists
      final query = _fileTagBox!
          .query(FileTag_.filePath.equals(filePath) & FileTag_.tag.equals(tag))
          .build();

      final existingTags = query.find();
      query.close();

      if (existingTags.isNotEmpty) {
        // Tag already exists for this file
        return true;
      }

      // Add the tag
      final fileTag = FileTag(
        filePath: filePath,
        tag: tag,
      );

      _fileTagBox!.put(fileTag);
      return true;
    } catch (e) {
      print('Error adding tag to file: $e');
      return false;
    }
  }

  @override
  Future<bool> removeTagFromFile(String filePath, String tag) async {
    if (!_isInitialized) await initialize();

    try {
      // Find the tag
      final query = _fileTagBox!
          .query(FileTag_.filePath.equals(filePath) & FileTag_.tag.equals(tag))
          .build();

      final existingTags = query.find();
      query.close();

      if (existingTags.isEmpty) {
        // Tag doesn't exist for this file
        return true;
      }

      // Remove the tag
      for (final tag in existingTags) {
        _fileTagBox!.remove(tag.id);
      }

      return true;
    } catch (e) {
      print('Error removing tag from file: $e');
      return false;
    }
  }

  @override
  Future<List<String>> getTagsForFile(String filePath) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _fileTagBox!.query(FileTag_.filePath.equals(filePath)).build();

      final fileTags = query.find();
      query.close();

      return fileTags.map((tag) => tag.tag).toList();
    } catch (e) {
      print('Error getting tags for file: $e');
      return [];
    }
  }

  @override
  Future<bool> setTagsForFile(String filePath, List<String> tags) async {
    if (!_isInitialized) await initialize();

    // Start a transaction for better performance
    return _store!.runInTransaction(TxMode.write, () {
      try {
        // First remove all existing tags for this file
        final query =
            _fileTagBox!.query(FileTag_.filePath.equals(filePath)).build();

        final existingTags = query.find();
        query.close();

        for (final tag in existingTags) {
          _fileTagBox!.remove(tag.id);
        }

        // Add the new tags
        for (final tag in tags) {
          final fileTag = FileTag(
            filePath: filePath,
            tag: tag,
          );
          _fileTagBox!.put(fileTag);
        }

        return true;
      } catch (e) {
        print('Error setting tags for file: $e');
        return false;
      }
    });
  }

  @override
  Future<List<String>> findFilesByTag(String tag) async {
    if (!_isInitialized) await initialize();

    final String normalizedTag = tag.toLowerCase().trim();
    if (normalizedTag.isEmpty) {
      return [];
    }

    try {
      // Sử dụng phép so sánh chứa thay vì bằng chính xác để tìm kiếm tag tương tự
      // Đầu tiên lấy tất cả các tag để tìm kiếm
      final allTags = await getAllUniqueTags();
      final matchingTags = allTags
          .where((t) =>
              t.toLowerCase().contains(normalizedTag) ||
              t.toLowerCase() == normalizedTag)
          .toList();

      if (matchingTags.isEmpty) {
        print('No matching tags found for query: $normalizedTag');
        return [];
      }

      print('Found ${matchingTags.length} matching tags: $matchingTags');

      // Tạo một tập hợp để lưu trữ các đường dẫn file duy nhất
      final Set<String> filePaths = {};

      // Tìm file cho mỗi tag phù hợp
      for (final matchingTag in matchingTags) {
        final query =
            _fileTagBox!.query(FileTag_.tag.equals(matchingTag)).build();
        final fileTags = query.find();
        query.close();

        // Thêm đường dẫn file vào tập hợp
        for (final fileTag in fileTags) {
          filePaths.add(fileTag.filePath);
        }
      }

      print('Found ${filePaths.length} unique files with matching tags');
      return filePaths.toList();
    } catch (e) {
      print('Error finding files by tag: $e');
      return [];
    }
  }

  @override
  Future<Set<String>> getAllUniqueTags() async {
    if (!_isInitialized) await initialize();

    try {
      final allTags = _fileTagBox!.getAll();

      // Get unique tags
      final uniqueTags = <String>{};
      for (final fileTag in allTags) {
        uniqueTags.add(fileTag.tag);
      }

      return uniqueTags;
    } catch (e) {
      print('Error getting all unique tags: $e');
      return {};
    }
  }

  @override
  Future<String?> getStringPreference(String key,
      {String? defaultValue}) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final result = query.findFirst();
      query.close();

      if (result != null && result.type == PreferenceType.string) {
        return result.stringValue;
      } else {
        return defaultValue;
      }
    } catch (e) {
      print('Error getting string preference: $e');
      return defaultValue;
    }
  }

  @override
  Future<bool> saveStringPreference(String key, String value) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if preference already exists
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final existingPref = query.findFirst();
      query.close();

      if (existingPref != null) {
        // Update existing preference if it's of the correct type
        if (existingPref.type == PreferenceType.string) {
          existingPref.stringValue = value;
          _preferenceBox!.put(existingPref);
          return true;
        } else {
          // Remove the old preference and create a new one
          _preferenceBox!.remove(existingPref.id);
        }
      }

      // Create new preference
      final preference = UserPreference.string(
        key: key,
        value: value,
      );

      _preferenceBox!.put(preference);
      return true;
    } catch (e) {
      print('Error saving string preference: $e');
      return false;
    }
  }

  @override
  Future<int?> getIntPreference(String key, {int? defaultValue}) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final result = query.findFirst();
      query.close();

      if (result != null && result.type == PreferenceType.integer) {
        return result.intValue;
      } else {
        return defaultValue;
      }
    } catch (e) {
      print('Error getting int preference: $e');
      return defaultValue;
    }
  }

  @override
  Future<bool> saveIntPreference(String key, int value) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if preference already exists
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final existingPref = query.findFirst();
      query.close();

      if (existingPref != null) {
        // Update existing preference if it's of the correct type
        if (existingPref.type == PreferenceType.integer) {
          existingPref.intValue = value;
          _preferenceBox!.put(existingPref);
          return true;
        } else {
          // Remove the old preference and create a new one
          _preferenceBox!.remove(existingPref.id);
        }
      }

      // Create new preference
      final preference = UserPreference.integer(
        key: key,
        value: value,
      );

      _preferenceBox!.put(preference);
      return true;
    } catch (e) {
      print('Error saving int preference: $e');
      return false;
    }
  }

  @override
  Future<double?> getDoublePreference(String key,
      {double? defaultValue}) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final result = query.findFirst();
      query.close();

      if (result != null && result.type == PreferenceType.double) {
        return result.doubleValue;
      } else {
        return defaultValue;
      }
    } catch (e) {
      print('Error getting double preference: $e');
      return defaultValue;
    }
  }

  @override
  Future<bool> saveDoublePreference(String key, double value) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if preference already exists
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final existingPref = query.findFirst();
      query.close();

      if (existingPref != null) {
        // Update existing preference if it's of the correct type
        if (existingPref.type == PreferenceType.double) {
          existingPref.doubleValue = value;
          _preferenceBox!.put(existingPref);
          return true;
        } else {
          // Remove the old preference and create a new one
          _preferenceBox!.remove(existingPref.id);
        }
      }

      // Create new preference
      final preference = UserPreference.double(
        key: key,
        value: value,
      );

      _preferenceBox!.put(preference);
      return true;
    } catch (e) {
      print('Error saving double preference: $e');
      return false;
    }
  }

  @override
  Future<bool?> getBoolPreference(String key, {bool? defaultValue}) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final result = query.findFirst();
      query.close();

      if (result != null && result.type == PreferenceType.boolean) {
        return result.boolValue;
      } else {
        return defaultValue;
      }
    } catch (e) {
      print('Error getting bool preference: $e');
      return defaultValue;
    }
  }

  @override
  Future<bool> saveBoolPreference(String key, bool value) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if preference already exists
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final existingPref = query.findFirst();
      query.close();

      if (existingPref != null) {
        // Update existing preference if it's of the correct type
        if (existingPref.type == PreferenceType.boolean) {
          existingPref.boolValue = value;
          _preferenceBox!.put(existingPref);
          return true;
        } else {
          // Remove the old preference and create a new one
          _preferenceBox!.remove(existingPref.id);
        }
      }

      // Create new preference
      final preference = UserPreference.boolean(
        key: key,
        value: value,
      );

      _preferenceBox!.put(preference);
      return true;
    } catch (e) {
      print('Error saving bool preference: $e');
      return false;
    }
  }

  @override
  Future<bool> deletePreference(String key) async {
    if (!_isInitialized) await initialize();

    try {
      final query =
          _preferenceBox!.query(UserPreference_.key.equals(key)).build();

      final existingPref = query.findFirst();
      query.close();

      if (existingPref != null) {
        _preferenceBox!.remove(existingPref.id);
        return true;
      }

      return true; // Key didn't exist, so it's already "deleted"
    } catch (e) {
      print('Error deleting preference: $e');
      return false;
    }
  }

  @override
  void setCloudSyncEnabled(bool enabled) {
    _isCloudSyncEnabled = enabled;
  }

  @override
  bool isCloudSyncEnabled() {
    return _isCloudSyncEnabled;
  }

  @override
  Future<bool> syncToCloud() async {
    if (!_isInitialized || !_isCloudSyncEnabled) return false;

    try {
      // Mock implementation - in real app, this would sync to a cloud service
      print('Syncing to cloud...');

      // Simulate some network delay
      await Future.delayed(const Duration(seconds: 1));

      return true;
    } catch (e) {
      print('Error syncing to cloud: $e');
      return false;
    }
  }

  @override
  Future<bool> syncFromCloud() async {
    if (!_isInitialized || !_isCloudSyncEnabled) return false;

    try {
      // Mock implementation - in real app, this would sync from a cloud service
      print('Syncing from cloud...');

      // Simulate some network delay
      await Future.delayed(const Duration(seconds: 1));

      return true;
    } catch (e) {
      print('Error syncing from cloud: $e');
      return false;
    }
  }
}
