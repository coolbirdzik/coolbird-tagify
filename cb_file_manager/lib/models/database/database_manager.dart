import 'package:cb_file_manager/models/database/database_provider.dart';
import 'package:cb_file_manager/models/objectbox/objectbox_database_provider.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'dart:async'; // Thêm import này để sử dụng Completer

/// Database manager for centralizing access to the database
class DatabaseManager implements IDatabaseProvider {
  // Singleton instance
  static DatabaseManager? _instance;

  // Semaphore để kiểm soát việc khởi tạo đồng thời
  static final _initSemaphore = _AsyncSemaphore();

  // Database provider implementation
  late IDatabaseProvider _provider;

  // User preferences for checking if ObjectBox is enabled
  final UserPreferences _preferences = UserPreferences.instance;

  // Flag to track if cloud sync is enabled
  bool _cloudSyncEnabled = false;

  // Flag to track if the manager is initialized
  bool _isInitialized = false;

  // Private constructor
  DatabaseManager._();

  /// Get the singleton instance of the database manager
  static DatabaseManager getInstance() {
    _instance ??= DatabaseManager._();
    return _instance!;
  }

  /// Initialize the database manager
  @override
  Future<void> initialize() async {
    // Sử dụng semaphore để đảm bảo chỉ một lần khởi tạo được thực hiện
    return _initSemaphore.run(() async {
      if (_isInitialized) {
        // Đã khởi tạo, không làm gì thêm
        print('DatabaseManager already initialized, skipping initialization');
        return;
      }

      try {
        // Tạo provider mà không cần khởi tạo UserPreferences
        _provider = ObjectBoxDatabaseProvider();

        // Thêm cơ chế retry để đảm bảo database khởi động được
        int retryCount = 0;
        const maxRetries = 3;
        bool initSuccess = false;

        while (!initSuccess && retryCount < maxRetries) {
          try {
            // Initialize the provider
            await _provider.initialize();
            initSuccess = true;
            print(
                'Database provider initialized successfully on attempt ${retryCount + 1}');
          } catch (e) {
            retryCount++;
            print(
                'Error initializing database provider (attempt $retryCount): $e');

            // Nếu vẫn còn cơ hội thử lại, đợi một chút trước khi thử lại
            if (retryCount < maxRetries) {
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            } else {
              throw Exception(
                  'Failed to initialize database after $maxRetries attempts: $e');
            }
          }
        }

        _isInitialized = true;
        print('DatabaseManager initialized successfully');
      } catch (e) {
        print('Error initializing DatabaseManager: $e');

        // Nếu không khởi tạo được database, vẫn đánh dấu là đã khởi tạo
        // để tránh app bị kẹt trong vòng lặp khởi tạo không thành công
        _isInitialized = true;

        // Rethrow để caller có thể xử lý theo cách riêng
        rethrow;
      }
    });
  }

  /// Check if the manager is initialized
  @override
  bool isInitialized() {
    return _isInitialized;
  }

  /// Close the database connection
  @override
  Future<void> close() async {
    if (_isInitialized) {
      await _provider.close();
      _isInitialized = false;
    }
  }

  /// Đảm bảo DatabaseManager đã được khởi tạo trước khi sử dụng
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Add a tag to a file
  @override
  Future<bool> addTagToFile(String filePath, String tag) async {
    await _ensureInitialized();
    return _provider.addTagToFile(filePath, tag);
  }

  /// Remove a tag from a file
  @override
  Future<bool> removeTagFromFile(String filePath, String tag) async {
    await _ensureInitialized();
    return _provider.removeTagFromFile(filePath, tag);
  }

  /// Get all tags for a file
  @override
  Future<List<String>> getTagsForFile(String filePath) async {
    await _ensureInitialized();
    return _provider.getTagsForFile(filePath);
  }

  /// Set all tags for a file (replaces existing tags)
  @override
  Future<bool> setTagsForFile(String filePath, List<String> tags) async {
    await _ensureInitialized();
    return _provider.setTagsForFile(filePath, tags);
  }

  /// Find all files with a specific tag
  @override
  Future<List<String>> findFilesByTag(String tag) async {
    await _ensureInitialized();
    return _provider.findFilesByTag(tag);
  }

  /// Get all unique tags in the database
  @override
  Future<Set<String>> getAllUniqueTags() async {
    await _ensureInitialized();
    final tags = await _provider.getAllUniqueTags();
    return tags.toSet();
  }

  /// Get a string preference
  @override
  Future<String?> getStringPreference(String key,
      {String? defaultValue}) async {
    await _ensureInitialized();
    return _provider.getStringPreference(key, defaultValue: defaultValue);
  }

  /// Save a string preference
  @override
  Future<bool> saveStringPreference(String key, String value) async {
    await _ensureInitialized();
    return _provider.saveStringPreference(key, value);
  }

  /// Get an int preference
  @override
  Future<int?> getIntPreference(String key, {int? defaultValue}) async {
    await _ensureInitialized();
    return _provider.getIntPreference(key, defaultValue: defaultValue);
  }

  /// Save an int preference
  @override
  Future<bool> saveIntPreference(String key, int value) async {
    await _ensureInitialized();
    return _provider.saveIntPreference(key, value);
  }

  /// Get a double preference
  @override
  Future<double?> getDoublePreference(String key,
      {double? defaultValue}) async {
    await _ensureInitialized();
    return _provider.getDoublePreference(key, defaultValue: defaultValue);
  }

  /// Save a double preference
  @override
  Future<bool> saveDoublePreference(String key, double value) async {
    await _ensureInitialized();
    return _provider.saveDoublePreference(key, value);
  }

  /// Get a bool preference
  @override
  Future<bool?> getBoolPreference(String key, {bool? defaultValue}) async {
    await _ensureInitialized();
    return _provider.getBoolPreference(key, defaultValue: defaultValue);
  }

  /// Save a bool preference
  @override
  Future<bool> saveBoolPreference(String key, bool value) async {
    await _ensureInitialized();
    return _provider.saveBoolPreference(key, value);
  }

  /// Delete a preference
  @override
  Future<bool> deletePreference(String key) async {
    await _ensureInitialized();
    return _provider.deletePreference(key);
  }

  /// Set whether cloud sync is enabled
  @override
  void setCloudSyncEnabled(bool enabled) {
    _cloudSyncEnabled = enabled;
    if (_isInitialized) {
      _provider.setCloudSyncEnabled(enabled);
    }
  }

  /// Check if cloud sync is enabled
  @override
  bool isCloudSyncEnabled() {
    return _cloudSyncEnabled;
  }

  /// Sync data to the cloud
  @override
  Future<bool> syncToCloud() async {
    await _ensureInitialized();
    if (!_cloudSyncEnabled) return false;
    return _provider.syncToCloud();
  }

  /// Sync data from the cloud
  @override
  Future<bool> syncFromCloud() async {
    await _ensureInitialized();
    if (!_cloudSyncEnabled) return false;
    return _provider.syncFromCloud();
  }
}

/// Helper class để đảm bảo các hoạt động bất đồng bộ chỉ thực hiện một lần
class _AsyncSemaphore {
  bool _running = false;
  final List<Completer<void>> _queue = [];

  Future<T> run<T>(Future<T> Function() task) async {
    final completer = Completer<void>();

    // Thêm vào hàng đợi
    _queue.add(completer);

    // Xử lý hàng đợi nếu chưa có tác vụ nào đang chạy
    if (!_running) {
      _processQueue();
    }

    // Đợi lượt của mình
    await completer.future;

    try {
      // Thực hiện tác vụ
      return await task();
    } finally {
      // Đánh dấu hoàn thành và xử lý tiếp hàng đợi
      _running = false;
      _processQueue();
    }
  }

  void _processQueue() {
    if (_queue.isEmpty) return;
    _running = true;

    // Lấy completer đầu tiên và hoàn thành nó
    final completer = _queue.removeAt(0);
    completer.complete();
  }
}
