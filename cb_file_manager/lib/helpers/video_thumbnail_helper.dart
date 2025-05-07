import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';

import 'fc_native_video_thumbnail.dart';

Future<int> _getEstimatedVideoDurationIsolate(String videoPath) async {
  try {
    final videoFile = File(videoPath);
    if (await videoFile.exists()) {
      final fileSize = await videoFile.length();
      final estimatedSeconds = (fileSize / (1024 * 1024) * 10).round();
      final clampedDuration = estimatedSeconds.clamp(1, 600);
      return clampedDuration > 0 ? clampedDuration : 1;
    }
  } catch (_) {}
  return 60;
}

Future<int> _calculateTimestampFromPercentageIsolate(
    String videoPath, double percentage) async {
  final estimatedDuration = await _getEstimatedVideoDurationIsolate(videoPath);
  int timestampSeconds = ((percentage / 100.0) * estimatedDuration).round();
  timestampSeconds = timestampSeconds.clamp(0, max(0, estimatedDuration - 1));
  return timestampSeconds;
}

String _createCacheFilenameIsolate(String videoPath) {
  final bytes = utf8.encode(videoPath);
  final digest = md5.convert(bytes);
  return 'thumb_${digest.toString()}.jpg';
}

class _ThumbnailIsolateArgs {
  final String videoPath;
  final String cacheFilename;
  final String absoluteVideoPath;
  final double thumbnailPercentage;
  final int quality;
  final int maxSize;
  final bool isWindows;
  final RootIsolateToken? rootIsolateToken;
  final bool forceRegenerate;

  _ThumbnailIsolateArgs({
    required this.videoPath,
    required this.cacheFilename,
    required this.absoluteVideoPath,
    required this.thumbnailPercentage,
    required this.quality,
    required this.maxSize,
    required this.isWindows,
    required this.rootIsolateToken,
    required this.forceRegenerate,
  });
}

Future<String?> _generateThumbnailIsolate(_ThumbnailIsolateArgs args) async {
  String? finalThumbnailPath;

  try {
    if (args.rootIsolateToken != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(
          args.rootIsolateToken!);
    } else {
      debugPrint(
          'VideoThumbnail (Isolate): Warning - RootIsolateToken is null, platform channels may fail.');
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String thumbnailPath = path.join(tempDir.path, args.cacheFilename);
    final cacheFile = File(thumbnailPath);

    // Non-blocking file check
    bool cacheExists = false;
    try {
      cacheExists = !args.forceRegenerate &&
          await cacheFile.exists() &&
          await cacheFile.length() > 0;

      if (cacheExists) {
        return thumbnailPath;
      }
    } catch (e) {
      debugPrint(
          'VideoThumbnail (Isolate): Error checking cache file $thumbnailPath: $e');
    }

    // Delete existing thumbnail if force regenerating
    if (args.forceRegenerate) {
      try {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
      } catch (e) {
        debugPrint(
            'VideoThumbnail (Isolate): Error deleting existing thumbnail during forceRegenerate: $e');
      }
    }

    final int timestampSeconds = await _calculateTimestampFromPercentageIsolate(
        args.videoPath, args.thumbnailPercentage);

    // Try to generate thumbnail using native method on Windows
    if (args.isWindows) {
      try {
        if (FcNativeVideoThumbnail.isSupportedFormat(args.videoPath)) {
          final nativeThumbnailPath =
              await FcNativeVideoThumbnail.generateThumbnail(
            videoPath: args.videoPath,
            outputPath: thumbnailPath,
            width: args.maxSize,
            format: 'jpg',
            timeSeconds: timestampSeconds,
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            debugPrint(
                'VideoThumbnail (Isolate): Native thumbnail generation timed out for ${args.videoPath}');
            return null;
          });

          if (nativeThumbnailPath != null) {
            final bool fileValid =
                await _isFileValidNonBlocking(nativeThumbnailPath);
            if (fileValid) {
              finalThumbnailPath = nativeThumbnailPath;
              return finalThumbnailPath;
            }
          }
        }
      } catch (e, stackTrace) {
        debugPrint(
            'VideoThumbnail (Isolate): Native error for ${args.videoPath}: $e\n$stackTrace');
      }
    }

    // Fallback to VideoThumbnail package
    try {
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: args.absoluteVideoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        quality: args.quality,
        maxHeight: args.maxSize,
        maxWidth: args.maxSize,
        timeMs: timestampSeconds * 1000,
      );

      if (thumbnailFile != null) {
        final bool fileValid = await _isFileValidNonBlocking(thumbnailFile);
        if (fileValid) {
          finalThumbnailPath = thumbnailFile;
          return finalThumbnailPath;
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
          'VideoThumbnail (Isolate): video_thumbnail error for ${args.absoluteVideoPath}: $e\n$stackTrace');
    }
  } catch (e, stackTrace) {
    debugPrint(
        'VideoThumbnail (Isolate): General error for ${args.videoPath}: $e\n$stackTrace');
  }

  return null;
}

// Helper method to check if file exists and is valid without blocking
Future<bool> _isFileValidNonBlocking(String filePath) async {
  try {
    final file = File(filePath);
    final exists = await file.exists();
    if (!exists) return false;

    final length = await file.length();
    return length > 0;
  } catch (e) {
    debugPrint('VideoThumbnail (Isolate): Error validating file $filePath: $e');
    return false;
  }
}

class VideoThumbnailHelper {
  // Add a StreamController to notify when cache is cleared
  static final StreamController<void> _cacheChangedController =
      StreamController<void>.broadcast();

  // Expose a stream that widgets can listen to
  static Stream<void> get onCacheChanged => _cacheChangedController.stream;

  // Method to notify listeners that cache has changed
  static void _notifyCacheChanged() {
    _cacheChangedController.add(null);
  }

  static final LinkedHashMap<String, String> _fileCache =
      LinkedHashMap<String, String>();

  static final _processingQueue = <_ThumbnailRequest>[];
  static final _pendingQueue = <_ThumbnailRequest>[];

  // Reduce maximum concurrent processes to prevent system overload
  static const int _maxConcurrentProcesses = 1;

  // Add throttling for native Windows thumbnail operations
  static bool _nativeOperationInProgress = false;
  static const Duration _nativeOperationTimeout = Duration(seconds: 5);

  static bool _isProcessingQueue = false;

  // Higher priority for visible thumbnails
  static const int _visiblePriority = 100;
  // Medium priority for prefetch operations
  static const int _prefetchPriority = 20;
  // Lower priority for background operations
  static const int _defaultPriority = 0;

  static const int _maxFileCacheSize = 500;

  // Increase quality for better thumbnails (was 70)
  static const int thumbnailQuality = 90;
  // Increase size for sharper thumbnails (was 200)
  static const int maxThumbnailSize = 300;

  static bool get _isWindows => Platform.isWindows;

  static bool _ffmpegInitialized = false;

  static DateTime _lastCleanupTime = DateTime.now();

  static String _currentDirectory = '';

  static bool _verboseLogging = false;

  static String? _cacheIndexFilePath;

  static bool _cacheInitialized = false;

  static final UserPreferences _userPrefs = UserPreferences.instance;
  static bool _userPrefsInitialized = false;
  static double _thumbnailPercentage = 10.0;

  static Timer? _saveCacheTimer;
  static const Duration _saveCacheThrottleDuration = Duration(seconds: 10);

  static bool _initializing = false;
  static Completer<void> _initCompleter = Completer<void>();

  /// Tạo một cache lưu trữ các đường dẫn thumbnail trong bộ nhớ
  /// Được sử dụng cho hiển thị nhanh khi cuộn
  static final Map<String, String> _inMemoryPathCache = {};

  /// Kích thước tối đa của cache trong bộ nhớ
  static const int _maxMemoryCacheSize = 500;

  /// Thời gian trước khi dọn dẹp cache (10 phút)
  static const Duration _memoryCacheCleanupInterval = Duration(minutes: 10);

  /// Thời điểm dọn dẹp cache cuối cùng
  static DateTime _lastMemoryCacheCleanup = DateTime.now();

  /// A tracker to remember which items have had loading attempts
  /// This prevents items from being forgotten after scrolling
  static final Set<String> _attemptedPaths = {};

  /// Flag to prevent items from being completely forgotten when scrolled out of viewport
  static bool _preserveRequestsWhenScrolled = true;

  static void setVerboseLogging(bool enabled) {
    _verboseLogging = enabled;
  }

  static void _log(String message, {bool forceShow = false}) {
    if (_verboseLogging || forceShow) {
      debugPrint(message);
    }
  }

  static Future<void> initializeCache() async {
    if (_cacheInitialized) return;
    if (_initializing) return _initCompleter.future;

    _initializing = true;
    _initCompleter = Completer<void>();

    try {
      if (!_userPrefsInitialized) {
        try {
          await _userPrefs.init();
          final percentage = await _userPrefs.getVideoThumbnailPercentage();
          _thumbnailPercentage = percentage.toDouble();
          _userPrefsInitialized = true;
          _log(
              'VideoThumbnail: UserPreferences initialized. Thumbnail percentage: $_thumbnailPercentage%');
        } catch (e) {
          _log('VideoThumbnail: Error initializing UserPreferences: $e',
              forceShow: true);
          _thumbnailPercentage = 10.0;
        }
      }

      await _loadCacheFromDisk();
      _cacheInitialized = true;
      _log('VideoThumbnail: Cache system initialized.');

      _initCompleter.complete();
    } catch (e) {
      _log('VideoThumbnail: Error during cache initialization: $e',
          forceShow: true);
      _initCompleter.completeError(e);
      _cacheInitialized = false;
      _userPrefsInitialized = false;
    } finally {
      _initializing = false;
    }
  }

  static void setCurrentDirectory(String dirPath) {
    if (_currentDirectory == dirPath) return;

    _log(
        'VideoThumbnail: Changing directory from "${_currentDirectory}" to "$dirPath"',
        forceShow: true);
    _currentDirectory = dirPath;

    cancelThumbnailsNotInDirectory(dirPath);
  }

  static void cancelThumbnailsNotInDirectory(String dirPath) {
    if (dirPath.isEmpty) return;

    int canceledCount = 0;

    final List<_ThumbnailRequest> requestsToRemove = [];

    for (final request in _pendingQueue) {
      final requestDir = path.dirname(request.videoPath);
      if (requestDir != dirPath) {
        if (!request.completer.isCompleted) {
          request.completer.complete(null);
        }
        requestsToRemove.add(request);
        canceledCount++;
      }
    }

    _pendingQueue.removeWhere((req) => requestsToRemove.contains(req));

    _log(
        'VideoThumbnail: Canceled $canceledCount pending thumbnails for other directories',
        forceShow: true);
  }

  static Future<bool> initializeFFmpeg() async {
    if (_ffmpegInitialized) return true;

    try {
      debugPrint('VideoThumbnailHelper: Initializing FFmpeg...');

      await FFMpegHelper.instance.initialize();

      if (_isWindows) {
        final isInstalled = await FFMpegHelper.instance.isFFMpegPresent();
        if (!isInstalled) {
          bool success = await FFMpegHelper.instance.setupFFMpegOnWindows(
            onProgress: (progress) {
              debugPrint('FFmpeg download progress: ${progress}%');
            },
          );

          if (!success) {
            return false;
          }
        }
      }

      _ffmpegInitialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool isSupportedVideoFormat(String filePath) {
    final lowercasePath = filePath.toLowerCase();

    final supportedExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.wmv',
      '.flv',
      '.webm',
      '.mpg',
      '.mpeg',
      '.m4v',
      '.3gp'
    ];

    return supportedExtensions.any((ext) => lowercasePath.endsWith(ext));
  }

  static Future<void> _addToFileCache(String key, String value) async {
    final file = File(value);
    if (!await file.exists()) {
      _log(
          'VideoThumbnail: Warning - Attempted to cache non-existent file: $value');
      return;
    }

    _fileCache.remove(key);

    if (_fileCache.length >= _maxFileCacheSize) {
      final oldestKey = _fileCache.keys.first;
      _fileCache.remove(oldestKey);
      _log('VideoThumbnail: Removed oldest item from file cache: $oldestKey');
    }

    _fileCache[key] = value;
    _log('VideoThumbnail: Added to file cache: $key => $value');
  }

  static Future<void> _cleanupOldTempFiles() async {
    final now = DateTime.now();
    if (now.difference(_lastCleanupTime).inHours < 1) {
      return;
    }

    _lastCleanupTime = now;

    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);

      final files = await directory
          .list()
          .where((file) => path.basename(file.path).startsWith('thumb_'))
          .toList();

      for (final file in files) {
        if (!_fileCache.values.contains(file.path)) {
          try {
            final stat = await file.stat();
            if (now.difference(stat.modified).inHours > 24) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> removeFromCache(String videoPath) async {
    // Xóa khỏi cache trong bộ nhớ ngay lập tức
    _inMemoryPathCache.remove(videoPath);

    // Xóa khỏi file cache
    if (_fileCache.containsKey(videoPath)) {
      final cachedPath = _fileCache[videoPath]!;
      _fileCache.remove(videoPath);

      // Xóa file trên đĩa trong background
      unawaited(() async {
        try {
          final file = File(cachedPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          _log('VideoThumbnail: Error deleting invalid cached file: $e');
        }
      }());
    }
  }

  static Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      // Process as many items as allowed by _maxConcurrentProcesses
      while (_processingQueue.length < _maxConcurrentProcesses &&
          _pendingQueue.isNotEmpty) {
        // Sort by priority to ensure most visible thumbnails are processed first
        _pendingQueue.sort((a, b) => b.priority.compareTo(a.priority));

        final request = _pendingQueue.removeAt(0);
        _processingQueue.add(request);

        // Use microtask to avoid blocking the UI thread
        // This ensures UI stays responsive between thumbnail processing
        scheduleMicrotask(() {
          _processRequest(request).then((_) {
            _processingQueue.remove(request);
            // Schedule next batch via microtask to avoid blocking UI
            scheduleMicrotask(() => _processQueue());
          });
        });

        // Small delay to ensure the UI thread gets time to process
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  static Future<void> _processRequest(_ThumbnailRequest request) async {
    try {
      final thumbnailPath = await _generateThumbnailInternal(request.videoPath,
          forceRegenerate: request.forceRegenerate);

      if (!request.completer.isCompleted) {
        request.completer.complete(thumbnailPath);
      }
    } catch (e, stackTrace) {
      _log(
          'VideoThumbnail: Error processing request for ${request.videoPath}: $e\n$stackTrace',
          forceShow: true);
      if (!request.completer.isCompleted) {
        request.completer.completeError(e, stackTrace);
      }
    }
  }

  static Future<String?> _requestThumbnail(String videoPath,
      {int priority = _defaultPriority, bool forceRegenerate = false}) {
    final existingPending = _pendingQueue.firstWhere(
        (req) => req.videoPath == videoPath,
        orElse: () => _ThumbnailRequest.empty());
    final existingProcessing = _processingQueue.firstWhere(
        (req) => req.videoPath == videoPath,
        orElse: () => _ThumbnailRequest.empty());

    if (existingPending.videoPath.isNotEmpty &&
        existingPending.priority >= priority) {
      return existingPending.completer.future;
    }
    if (existingProcessing.videoPath.isNotEmpty &&
        existingProcessing.priority >= priority) {
      return existingProcessing.completer.future;
    }

    _ThumbnailRequest? oldRequest;
    if (existingPending.videoPath.isNotEmpty) {
      oldRequest = existingPending;
      _pendingQueue.remove(existingPending);
    }

    final completer = Completer<String?>();
    final newRequest = _ThumbnailRequest(
      videoPath: videoPath,
      priority: priority,
      completer: completer,
      timestamp: DateTime.now(),
      forceRegenerate: forceRegenerate,
    );

    _pendingQueue.add(newRequest);

    Timer.run(_processQueue);

    if (oldRequest != null && !oldRequest.completer.isCompleted) {
      completer.future.then((value) {
        if (!oldRequest!.completer.isCompleted) {
          oldRequest.completer.complete(value);
        }
      }, onError: (error, stackTrace) {
        if (!oldRequest!.completer.isCompleted) {
          oldRequest.completer.completeError(error, stackTrace);
        }
      });
    }

    return completer.future;
  }

  static Future<String?> _generateThumbnailInternal(String videoPath,
      {bool forceRegenerate = false}) async {
    try {
      final cacheFilename = _createCacheFilename(videoPath);

      String absoluteVideoPath = path.absolute(videoPath);
      if (_isWindows) {
        absoluteVideoPath = absoluteVideoPath.replaceAll('\\', '/');
      }

      if (!_userPrefsInitialized) {
        _log(
            'VideoThumbnail: Warning - UserPrefs not initialized in _generateThumbnailInternal. Using default percentage.',
            forceShow: true);
      }
      final percentage = _thumbnailPercentage;

      // First check if already exists in cache and valid before using compute
      if (!forceRegenerate && _fileCache.containsKey(videoPath)) {
        final cachedPath = _fileCache[videoPath]!;
        final cacheFile = File(cachedPath);
        try {
          if (await cacheFile.exists() && await cacheFile.length() > 0) {
            _log('VideoThumbnail: Using valid cache for $videoPath');
            return cachedPath;
          } else {
            _log('VideoThumbnail: Cache invalid for $videoPath, regenerating');
            _fileCache.remove(videoPath);
          }
        } catch (e) {
          _log('VideoThumbnail: Error checking cache: $e');
          _fileCache.remove(videoPath);
        }
      }

      final rootToken = RootIsolateToken.instance;
      if (rootToken == null) {
        _log('VideoThumbnail: Error - RootIsolateToken.instance is null.',
            forceShow: true);
      }

      final args = _ThumbnailIsolateArgs(
        videoPath: videoPath,
        cacheFilename: cacheFilename,
        absoluteVideoPath: absoluteVideoPath,
        thumbnailPercentage: percentage,
        quality: thumbnailQuality,
        maxSize: maxThumbnailSize,
        isWindows: _isWindows,
        rootIsolateToken: rootToken,
        forceRegenerate: forceRegenerate,
      );

      // Use a timeout to prevent isolate from hanging indefinitely
      final generatedPath =
          await compute(_generateThumbnailIsolate, args).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('VideoThumbnail: Timeout generating thumbnail for $videoPath',
              forceShow: true);
          return null;
        },
      );

      if (generatedPath != null) {
        final resultFile = File(generatedPath);
        if (await resultFile.exists() && await resultFile.length() > 0) {
          await _addToFileCache(videoPath, generatedPath);
          _saveCacheToDiskThrottled();
          return generatedPath;
        } else {
          _log(
              'VideoThumbnail: Compute returned path but file invalid: $generatedPath');
          try {
            if (await resultFile.exists()) await resultFile.delete();
          } catch (_) {}
        }
      }
    } catch (e, stackTrace) {
      _log(
          'VideoThumbnail: Error in _generateThumbnailInternal for $videoPath: $e\n$stackTrace',
          forceShow: true);
    }

    return null;
  }

  static String _createCacheFilename(String videoPath) {
    final bytes = utf8.encode(videoPath);
    final digest = md5.convert(bytes);
    return 'thumb_${digest.toString()}.jpg';
  }

  static void _saveCacheToDiskThrottled() {
    if (_saveCacheTimer?.isActive ?? false) {
      _saveCacheTimer!.cancel();
    }
    _saveCacheTimer = Timer(_saveCacheThrottleDuration, () {
      _saveCacheToDiskActual();
      _saveCacheTimer = null;
    });
  }

  static Future<void> _saveCacheToDiskActual() async {
    try {
      if (_cacheIndexFilePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cacheIndexFilePath =
            path.join(tempDir.path, 'thumbnail_cache_index.json');
      }

      final cacheData = Map<String, String>.from(_fileCache);

      await compute(_saveCacheIsolate, {
        'filePath': _cacheIndexFilePath!,
        'cacheData': cacheData,
      });
    } catch (e) {
      _log('VideoThumbnail: Error initiating cache save: $e', forceShow: true);
    }
  }

  static Future<void> _saveCacheIsolate(Map<String, dynamic> args) async {
    final String filePath = args['filePath'];
    final Map<String, String> cacheData = args['cacheData'];
    try {
      final jsonData = jsonEncode(cacheData);
      await File(filePath).writeAsString(jsonData);
    } catch (e) {
      debugPrint('VideoThumbnail (Isolate): Error saving cache to disk: $e');
    }
  }

  static Future<void> _loadCacheFromDisk() async {
    _log('VideoThumbnail: Loading cache from disk...');
    try {
      _fileCache.clear();

      if (_cacheIndexFilePath == null) {
        final tempDir = await getTemporaryDirectory();
        _cacheIndexFilePath =
            path.join(tempDir.path, 'thumbnail_cache_index.json');
      }

      final indexFile = File(_cacheIndexFilePath!);
      if (!await indexFile.exists()) {
        _log('VideoThumbnail: No cache index file found.');
        return;
      }

      final jsonData = await indexFile.readAsString();
      try {
        final cacheData = jsonDecode(jsonData) as Map<String, dynamic>;
        int validCount = 0;
        int invalidCount = 0;
        for (final entry in cacheData.entries) {
          final thumbnailPath = entry.value as String?;
          final videoPath = entry.key;
          if (thumbnailPath != null && videoPath != null) {
            _fileCache[videoPath] = thumbnailPath;
            validCount++;
          } else {
            invalidCount++;
          }
        }
        _log(
            'VideoThumbnail: Loaded $validCount entries from disk index (ignored $invalidCount invalid).');
      } catch (e) {
        _log(
            'VideoThumbnail: Error decoding cache JSON: $e. Deleting corrupt index.',
            forceShow: true);
        try {
          await indexFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      _log('VideoThumbnail: Error loading cache from disk: $e',
          forceShow: true);
    }
  }

  static Future<String?> generateThumbnail(String videoPath,
      {bool isPriority = false, bool forceRegenerate = false}) async {
    if (!_cacheInitialized) {
      if (_initializing) {
        await _initCompleter.future;
      } else {
        await initializeCache();
      }
    }

    if (!isSupportedVideoFormat(videoPath)) {
      _log('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    if (forceRegenerate) {
      _log('VideoThumbnail: Force regenerating thumbnail for: $videoPath');
      _fileCache.remove(videoPath);
    }

    final priority = isPriority ? _visiblePriority : _defaultPriority;

    final result = await _requestThumbnail(videoPath,
        priority: priority, forceRegenerate: forceRegenerate);

    return result;
  }

  static Future<Uint8List?> generateThumbnailData(String videoPath,
      {bool isPriority = false, bool forceRegenerate = false}) async {
    if (!_cacheInitialized) {
      if (_initializing) {
        await _initCompleter.future;
      } else {
        await initializeCache();
      }
    }

    if (!isSupportedVideoFormat(videoPath)) {
      debugPrint('VideoThumbnail: Unsupported video format: $videoPath');
      return null;
    }

    try {
      final thumbnailPath = await generateThumbnail(videoPath,
          isPriority: isPriority, forceRegenerate: forceRegenerate);

      if (thumbnailPath != null) {
        try {
          final File thumbnailFile = File(thumbnailPath);
          if (await thumbnailFile.exists()) {
            final bytes = await thumbnailFile.readAsBytes();
            if (bytes.isNotEmpty) {
              return bytes;
            } else {
              debugPrint(
                  'VideoThumbnail: Thumbnail file is empty: $thumbnailPath');
              _fileCache.remove(videoPath);
              try {
                await thumbnailFile.delete();
              } catch (_) {}
              return null;
            }
          } else {
            debugPrint(
                'VideoThumbnail: Thumbnail file path obtained but file does not exist: $thumbnailPath');
            _fileCache.remove(videoPath);
            return null;
          }
        } catch (e) {
          debugPrint(
              'VideoThumbnail: Error reading thumbnail file $thumbnailPath: $e');
          _fileCache.remove(videoPath);
          try {
            final file = File(thumbnailPath);
            if (await file.exists()) await file.delete();
          } catch (_) {}
          return null;
        }
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint(
          'VideoThumbnail: Error in generateThumbnailData for $videoPath: $e');
      debugPrint('VideoThumbnail: Stack trace: $stackTrace');
    }

    return null;
  }

  static Future<String?> getFromCache(String videoPath) async {
    if (!_cacheInitialized) {
      if (_initializing) {
        await _initCompleter.future;
      } else {
        await initializeCache();
      }
    }

    // Kiểm tra cache trong bộ nhớ trước
    if (_inMemoryPathCache.containsKey(videoPath)) {
      final cachedPath = _inMemoryPathCache[videoPath]!;
      try {
        final file = File(cachedPath);
        if (await file.exists() && await file.length() > 0) {
          // Đưa lại lên đầu cache nếu tồn tại
          final value = _inMemoryPathCache.remove(videoPath)!;
          _inMemoryPathCache[videoPath] = value;
          return cachedPath;
        } else {
          // Xóa khỏi cache nếu không hợp lệ
          _inMemoryPathCache.remove(videoPath);
        }
      } catch (e) {
        _inMemoryPathCache.remove(videoPath);
      }
    }

    // Kiểm tra cache trên đĩa
    if (_fileCache.containsKey(videoPath)) {
      final cachedPath = _fileCache[videoPath]!;
      try {
        final file = File(cachedPath);
        if (await file.exists() && await file.length() > 0) {
          // Thêm vào cache trong bộ nhớ để truy cập nhanh hơn lần sau
          _addToMemoryCache(videoPath, cachedPath);
          return cachedPath;
        } else {
          // Cache entry không hợp lệ, xóa đi
          _fileCache.remove(videoPath);
        }
      } catch (e) {
        _log('VideoThumbnail: Error checking cache file $cachedPath: $e');
        _fileCache.remove(videoPath);
      }
    }

    // Không tìm thấy trong cache
    return null;
  }

  /// Thêm đường dẫn vào cache bộ nhớ với cơ chế LRU (Least Recently Used)
  static void _addToMemoryCache(String videoPath, String thumbnailPath) {
    // Kiểm tra xem đã đến lúc dọn dẹp cache chưa
    final now = DateTime.now();
    if (now.difference(_lastMemoryCacheCleanup) > _memoryCacheCleanupInterval) {
      _cleanMemoryCache();
    }

    // Nếu đã tồn tại, cập nhật lại vị trí
    if (_inMemoryPathCache.containsKey(videoPath)) {
      final value = _inMemoryPathCache.remove(videoPath)!;
      _inMemoryPathCache[videoPath] = value;
      return;
    }

    // Nếu cache đầy, xóa entry cũ nhất (first item in LinkedHashMap)
    if (_inMemoryPathCache.length >= _maxMemoryCacheSize) {
      // Xóa entry đầu tiên (cũ nhất)
      final oldestKey = _inMemoryPathCache.keys.first;
      _inMemoryPathCache.remove(oldestKey);
    }

    // Thêm vào cache
    _inMemoryPathCache[videoPath] = thumbnailPath;
  }

  /// Dọn dẹp cache trong bộ nhớ
  static void _cleanMemoryCache() {
    _log('VideoThumbnail: Cleaning memory cache...');
    _lastMemoryCacheCleanup = DateTime.now();

    // Giữ lại 2/3 các entry gần đây nhất
    if (_inMemoryPathCache.length > _maxMemoryCacheSize / 2) {
      final keepCount = (_maxMemoryCacheSize * 2 / 3).round();
      final keysToRemove = _inMemoryPathCache.keys
          .take(_inMemoryPathCache.length - keepCount)
          .toList();
      for (final key in keysToRemove) {
        _inMemoryPathCache.remove(key);
      }
      _log(
          'VideoThumbnail: Memory cache trimmed to ${_inMemoryPathCache.length} entries');
    }
  }

  static Widget buildVideoThumbnail({
    required String videoPath,
    Widget Function()? fallbackBuilder,
    double width = 200,
    double height = 150,
    BoxFit fit = BoxFit.cover,
    bool isPriority = false,
    bool forceRegenerate = false,
    Key? key,
    void Function(String?)? onThumbnailGenerated,
  }) {
    final defaultFallback = () => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.movie, size: 40, color: Colors.grey),
          ),
        );

    return FutureBuilder<String?>(
      key: key ?? ValueKey('thumb_$videoPath'),
      future: generateThumbnail(videoPath,
          isPriority: isPriority, forceRegenerate: forceRegenerate),
      builder: (context, snapshot) {
        Widget content;
        final thumbnailPath = snapshot.data;

        // Notify the parent when a thumbnail is generated
        if (thumbnailPath != null && onThumbnailGenerated != null) {
          // Use a microtask to avoid calling during build
          scheduleMicrotask(() => onThumbnailGenerated(thumbnailPath));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            thumbnailPath == null) {
          content = fallbackBuilder?.call() ?? defaultFallback();
        } else if (snapshot.hasError) {
          _log(
              'VideoThumbnail FutureBuilder error for $videoPath: ${snapshot.error}');
          content = fallbackBuilder?.call() ?? defaultFallback();
        } else if (thumbnailPath != null) {
          content = Image.file(
            File(thumbnailPath),
            key: ValueKey(thumbnailPath),
            width: width,
            height: height,
            fit: fit,
            // Add null checks and validation before converting to int
            cacheWidth:
                (width.isFinite && width > 0) ? (width * 2).toInt() : null,
            cacheHeight:
                (height.isFinite && height > 0) ? (height * 2).toInt() : null,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              _log('Error loading thumbnail image file $thumbnailPath: $error');
              _fileCache.remove(videoPath);
              unawaited(() async {
                try {
                  final file = File(thumbnailPath);
                  if (await file.exists()) await file.delete();
                } catch (_) {}
              }());
              return fallbackBuilder?.call() ?? defaultFallback();
            },
          );
        } else {
          content = fallbackBuilder?.call() ?? defaultFallback();
        }

        return content;
      },
    );
  }

  static Future<void> clearCache() async {
    _log('VideoThumbnail: Clearing cache...', forceShow: true);

    // Set a flag to prevent new thumbnail requests during cache clearing
    final bool wasProcessing = _isProcessingQueue;
    _isProcessingQueue = true;

    try {
      _fileCache.clear();
      _inMemoryPathCache.clear();
      _attemptedPaths.clear();

      // Cancel all pending thumbnail requests first
      final pendingRequests = List<_ThumbnailRequest>.from(_pendingQueue);
      _pendingQueue.clear();

      for (final request in pendingRequests) {
        try {
          if (!request.completer.isCompleted) {
            request.completer.complete(null);
          }
        } catch (e) {
          _log('VideoThumbnail: Error completing pending request: $e');
        }
      }

      // Wait briefly for any ongoing compute operations to finish
      await Future.delayed(const Duration(milliseconds: 50));

      // Cancel all processing requests
      final processingRequests = List<_ThumbnailRequest>.from(_processingQueue);
      _processingQueue.clear();

      for (final request in processingRequests) {
        try {
          if (!request.completer.isCompleted) {
            request.completer.complete(null);
          }
        } catch (e) {
          _log('VideoThumbnail: Error completing processing request: $e');
        }
      }

      // Reset initialization state
      _initializing = false;
      _initCompleter = Completer<void>();
      _nativeOperationInProgress = false;

      // Clear Flutter's image cache to prevent memory leaks
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (e) {
        _log('VideoThumbnail: Error clearing PaintingBinding image cache: $e');
      }

      // Delete physical thumbnail files
      try {
        final tempDir = await getTemporaryDirectory();
        final directory = Directory(tempDir.path);

        if (!await directory.exists()) {
          _log(
              'VideoThumbnail: Temporary directory not found for clearing cache.');
          return;
        }

        final thumbnailFiles = await directory
            .list()
            .where((file) => path.basename(file.path).startsWith('thumb_'))
            .toList();

        int deletedCount = 0;
        for (final file in thumbnailFiles) {
          try {
            if (await file.exists()) {
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            _log(
                'VideoThumbnail: Error deleting thumbnail file ${file.path}: $e');
          }
        }
        _log('VideoThumbnail: Deleted $deletedCount physical thumbnail files.');

        if (_cacheIndexFilePath != null) {
          final indexFile = File(_cacheIndexFilePath!);
          if (await indexFile.exists()) {
            await indexFile.delete();
            _log('VideoThumbnail: Deleted cache index file.');
          }
        }
      } catch (e) {
        _log('VideoThumbnail: Error clearing physical cache files: $e',
            forceShow: true);
      }

      _lastCleanupTime = DateTime.now();
      _cacheInitialized = false;
      _userPrefsInitialized = false;
      _log('VideoThumbnail: Cache cleared completely.');

      // Notify listeners that cache has been cleared
      _notifyCacheChanged();
    } finally {
      // Restore processing flag to previous state if it wasn't already processing
      _isProcessingQueue = wasProcessing;
    }
  }

  static Future<void> trimCache() async {
    _log('VideoThumbnail: Trimming cache...');
    if (_fileCache.length > _maxFileCacheSize / 2) {
      final keysToRemoveCount = _fileCache.length - (_maxFileCacheSize ~/ 2);
      final keysToRemove = _fileCache.keys.take(keysToRemoveCount).toList();
      for (final key in keysToRemove) {
        _fileCache.remove(key);
      }
      _log(
          'VideoThumbnail: Trimmed in-memory cache to ${_fileCache.length} items.');
      _saveCacheToDiskThrottled();
    }

    await _cleanupOldTempFiles();
    _log('VideoThumbnail: Cache trimming complete.');
  }

  /// Tối ưu việc tải nhiều thumbnail cùng một lúc với hàng đợi ưu tiên
  static Future<void> optimizedBatchPreload(
    List<String> videoPaths, {
    int maxConcurrent = 2,
    int visibleCount = 10,
  }) async {
    if (!_cacheInitialized) {
      await initializeCache();
    }

    if (videoPaths.isEmpty) return;

    // Chia thành 3 nhóm ưu tiên:
    // 1. Nhóm hiển thị - tải ngay với ưu tiên cao
    // 2. Nhóm gần viewport - tải với ưu tiên trung bình
    // 3. Nhóm còn lại - tải với ưu tiên thấp

    final visiblePaths = videoPaths.take(visibleCount).toList();
    final nearPaths =
        videoPaths.skip(visibleCount).take(visibleCount * 2).toList();
    final otherPaths = videoPaths.skip(visibleCount * 3).toList();

    // Tạm dừng các yêu cầu đang chờ để xếp các yêu cầu mới
    _pendingQueue.clear();

    // Thêm vào queue với độ ưu tiên thích hợp
    for (final path in visiblePaths) {
      _requestThumbnail(path, priority: _visiblePriority);
    }

    // Delay trước khi thêm nhóm kế tiếp để tránh nghẽn
    await Future.delayed(const Duration(milliseconds: 100));

    for (final path in nearPaths) {
      _requestThumbnail(path, priority: _prefetchPriority);
    }

    // Delay dài hơn trước khi thêm nhóm cuối
    await Future.delayed(const Duration(milliseconds: 200));

    for (final path in otherPaths) {
      _requestThumbnail(path, priority: _defaultPriority);
    }
  }

  /// Hủy tất cả các yêu cầu đang chờ xử lý
  static void cancelPendingRequests() {
    _pendingQueue.clear();
  }

  /// Flag to mark a thumbnail as attempted for generation
  /// This prevents the need to retry generating already failed thumbnails
  static void markAttempted(String videoPath) {
    _attemptedPaths.add(videoPath);
  }

  /// Check if a thumbnail generation was already attempted
  static bool wasAttempted(String videoPath) {
    return _attemptedPaths.contains(videoPath);
  }

  /// Restart thumbnail generation for items that come back into viewport
  static Future<String?> restartThumbnailRequest(String videoPath) async {
    // Remove from attempted paths to allow regeneration
    _attemptedPaths.remove(videoPath);

    // First try cache
    final cached = await getFromCache(videoPath);
    if (cached != null) {
      return cached;
    }

    // Request with high priority
    return _requestThumbnail(videoPath, priority: _visiblePriority);
  }

  /// Force regenerate a thumbnail even if it's already in cache
  /// Useful when a thumbnail was attempted but failed and needs to be retried
  static Future<String?> forceRegenerateThumbnail(String videoPath) async {
    if (!_cacheInitialized) {
      await initializeCache();
    }

    // First remove from all caches
    _inMemoryPathCache.remove(videoPath);
    _fileCache.remove(videoPath);
    _attemptedPaths.remove(videoPath);

    // Clear from pending and processing queues
    final pendingIndex =
        _pendingQueue.indexWhere((req) => req.videoPath == videoPath);
    if (pendingIndex != -1) {
      if (!_pendingQueue[pendingIndex].completer.isCompleted) {
        _pendingQueue[pendingIndex].completer.complete(null);
      }
      _pendingQueue.removeAt(pendingIndex);
    }

    // Delete any existing file
    try {
      final cacheFilename = _createCacheFilename(videoPath);
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = path.join(tempDir.path, cacheFilename);

      final File file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log('Error deleting thumbnail file for $videoPath: $e');
    }

    // Request new thumbnail with highest priority
    return await _requestThumbnail(videoPath,
        priority: _visiblePriority + 50, // Super high priority
        forceRegenerate: true);
  }

  /// Regenerate thumbnails for all video files in the specified directory
  /// This is useful after clearing the cache to ensure thumbnails are regenerated
  static Future<void> regenerateThumbnailsForDirectory(
      String directoryPath) async {
    _log(
        'VideoThumbnail: Regenerating thumbnails for directory: $directoryPath',
        forceShow: true);

    if (!_cacheInitialized) {
      await initializeCache();
    }

    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        _log('VideoThumbnail: Directory does not exist: $directoryPath',
            forceShow: true);
        return;
      }

      // Set as current directory
      setCurrentDirectory(directoryPath);

      // Get all video files in the directory
      final fileList = await directory.list().toList();
      final videoPaths = fileList
          .where(
              (entity) => entity is File && isSupportedVideoFormat(entity.path))
          .map((entity) => entity.path)
          .toList();

      if (videoPaths.isEmpty) {
        _log('VideoThumbnail: No video files found in directory',
            forceShow: true);
        return;
      }

      _log(
          'VideoThumbnail: Found ${videoPaths.length} video files to regenerate thumbnails',
          forceShow: true);

      // Use the optimized batch preload to regenerate thumbnails
      await optimizedBatchPreload(videoPaths,
          maxConcurrent: 2, visibleCount: 10);

      _log(
          'VideoThumbnail: Regeneration queued for ${videoPaths.length} videos',
          forceShow: true);
    } catch (e) {
      _log('VideoThumbnail: Error regenerating thumbnails: $e',
          forceShow: true);
    }
  }
}

class _ThumbnailRequest {
  final String videoPath;
  int priority;
  final Completer<String?> completer;
  final DateTime timestamp;
  final bool forceRegenerate;

  _ThumbnailRequest.empty()
      : videoPath = '',
        priority = -1,
        completer = Completer<String?>(),
        timestamp = DateTime(0),
        forceRegenerate = false;

  _ThumbnailRequest({
    required this.videoPath,
    required this.priority,
    required this.completer,
    required this.timestamp,
    required this.forceRegenerate,
  });
}
