import 'dart:io';
import 'dart:async';
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
// import 'package:ffmpeg_helper/ffmpeg_helper.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/helpers/core/app_path_helper.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'fc_native_video_thumbnail.dart';

Future<int> _getEstimatedVideoDurationIsolate(String videoPath) async {
  try {
    final videoFile = File(videoPath);
    if (await videoFile.exists()) {
      final fileSize = await videoFile.length();

      // Get file extension to better estimate duration
      final extension = videoPath.toLowerCase().split('.').last;

      // Different estimation based on video format
      double estimationFactor;
      switch (extension) {
        case 'mp4':
        case 'mov':
        case 'avi':
          estimationFactor = 8.0; // 8 seconds per MB (higher quality)
          break;
        case 'mkv':
        case 'webm':
          estimationFactor = 10.0; // 10 seconds per MB (medium quality)
          break;
        case 'flv':
        case '3gp':
          estimationFactor = 15.0; // 15 seconds per MB (lower quality)
          break;
        default:
          estimationFactor = 10.0; // Default estimation
      }

      final estimatedSeconds =
          (fileSize / (1024 * 1024) * estimationFactor).round();

      // Clamp to reasonable bounds (minimum 10 seconds, maximum 10 minutes for estimation)
      final clampedDuration = estimatedSeconds.clamp(10, 600);

      debugPrint(
          'VideoThumbnail: Estimated duration for $videoPath: ${clampedDuration}s (${fileSize / (1024 * 1024)} MB, factor: $estimationFactor)');

      return clampedDuration > 0 ? clampedDuration : 60;
    }
  } catch (e) {
    debugPrint('VideoThumbnail: Error estimating duration for $videoPath: $e');
  }

  // Default fallback
  return 60;
}

Future<int> _calculateTimestampFromPercentageIsolate(
    String videoPath, double percentage) async {
  final estimatedDuration = await _getEstimatedVideoDurationIsolate(videoPath);

  // Ensure percentage is within valid range
  final validPercentage = percentage.clamp(0.0, 100.0);

  // For very short videos, use a fixed timestamp
  if (estimatedDuration <= 10) {
    final timestamp =
        (estimatedDuration / 2).round().clamp(2, estimatedDuration - 2);
    debugPrint(
        'VideoThumbnail: Short video ($estimatedDuration s), using middle timestamp: ${timestamp}s');
    return timestamp;
  }

  // Avoid the first and last 10% of the video to prevent black screens
  double adjustedPercentage = validPercentage;
  if (validPercentage < 10.0) {
    adjustedPercentage = 10.0; // Start at 10% minimum
  } else if (validPercentage > 90.0) {
    adjustedPercentage = 90.0; // End at 90% maximum
  }

  // Calculate timestamp in seconds
  int timestampSeconds =
      ((adjustedPercentage / 100.0) * estimatedDuration).round();

  // Ensure timestamp is within safe bounds (avoid first/last 5 seconds)
  final minTimestamp = 5;
  final maxTimestamp =
      estimatedDuration > 10 ? estimatedDuration - 5 : estimatedDuration ~/ 2;
  timestampSeconds = timestampSeconds.clamp(minTimestamp, maxTimestamp);

  // Debug logging to track thumbnail timestamp calculation
  debugPrint('VideoThumbnail: Calculating timestamp for $videoPath');
  debugPrint('  - Original percentage: $percentage%');
  debugPrint('  - Adjusted percentage: $adjustedPercentage%');
  debugPrint('  - Estimated duration: ${estimatedDuration}s');
  debugPrint('  - Calculated timestamp: ${timestampSeconds}s');
  debugPrint('  - Safe range: ${minTimestamp}s - ${maxTimestamp}s');

  return timestampSeconds;
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
    // Safely initialize BackgroundIsolateBinaryMessenger with proper error handling
    if (args.rootIsolateToken != null) {
      try {
        // Add null check and proper error handling
        if (args.rootIsolateToken != null) {
          BackgroundIsolateBinaryMessenger.ensureInitialized(
              args.rootIsolateToken!);
        }
      } catch (e) {
        debugPrint(
            'VideoThumbnail (Isolate): Error initializing BackgroundIsolateBinaryMessenger: $e');
        // Continue execution, we'll try to generate thumbnail without platform channels
      }
    } else {
      debugPrint(
          'VideoThumbnail (Isolate): Warning - RootIsolateToken is null, platform channels may fail.');
    }

    final Directory tempDir = await AppPathHelper.getVideoCacheDir();
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

  /// Dispose resources
  static void dispose() {
    _cacheChangedController.close();
  }

  // Track which paths have been logged to avoid spamming logs
  static final Set<String> _loggedPaths = {};
  static DateTime _lastLogCleanup = DateTime.now();

  static final LinkedHashMap<String, String> _fileCache =
      LinkedHashMap<String, String>();

  static final _processingQueue = <_ThumbnailRequest>[];
  static final _pendingQueue = <_ThumbnailRequest>[];

  // Reduce maximum concurrent processes to prevent system overload
  static const int _maxConcurrentProcesses = 1;

  // Add throttling for native Windows thumbnail operations

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

  static DateTime _lastCleanupTime = DateTime.now();

  static String _currentDirectory = '';

  static bool _verboseLogging = false;

  static String? _cacheIndexFilePath;

  static bool _cacheInitialized = false;

  static final UserPreferences _userPrefs = UserPreferences.instance;
  static bool _userPrefsInitialized = false;
  static double _thumbnailPercentage = 10.0;

  // Add method to refresh percentage from preferences
  static Future<void> refreshThumbnailPercentage() async {
    try {
      if (!_userPrefsInitialized) {
        await _userPrefs.init();
        _userPrefsInitialized = true;
      }

      final percentage = await _userPrefs.getVideoThumbnailPercentage();
      final oldPercentage = _thumbnailPercentage;
      _thumbnailPercentage = percentage.toDouble();

      debugPrint(
          'VideoThumbnail: Refreshed thumbnail percentage from $oldPercentage% to $_thumbnailPercentage%');

      // Clear cache if percentage changed significantly to regenerate thumbnails
      if ((oldPercentage - _thumbnailPercentage).abs() > 5.0) {
        debugPrint(
            'VideoThumbnail: Percentage changed significantly, clearing cache to regenerate thumbnails');
        await clearCache();
      }
    } catch (e) {
      debugPrint('VideoThumbnail: Error refreshing thumbnail percentage: $e');
    }
  }

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

  // Add a static flag to check if processing should continue
  static bool _shouldStopProcessing = false;

  static void setVerboseLogging(bool enabled) {
    _verboseLogging = enabled;
  }

  static void _log(String message, {bool forceShow = false}) {
    if (_verboseLogging || forceShow) {
      debugPrint(message);
    }
  }

  // Log with path throttling (private implementation)
  static void _logWithPathThrottle(String message, String path,
      {bool forceShow = false}) {
    // Clean up logged paths every 60 seconds
    final now = DateTime.now();
    if (now.difference(_lastLogCleanup).inSeconds > 60) {
      _loggedPaths.clear();
      _lastLogCleanup = now;
    }

    // Track more specific message types by using a composite key
    final logKey = '${message.split(":")[0]}:$path';

    // Only log if we haven't logged this path recently
    if (!_loggedPaths.contains(logKey)) {
      _loggedPaths.add(logKey);
      _log(message, forceShow: forceShow);
    }
  }

  // Public log throttling method for use by other classes
  static void logWithThrottle(String message, String path) {
    _logWithPathThrottle(message, path);
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
        'VideoThumbnail: Changing directory from "$_currentDirectory" to "$dirPath"',
        forceShow: true);
    _currentDirectory = dirPath;

    cancelThumbnailsNotInDirectory(dirPath);
  }

  static void cancelThumbnailsNotInDirectory(String dirPath) {
    if (dirPath.isEmpty) return;

    int canceledCount = 0;

    // Set flag to stop any new processing
    _shouldStopProcessing = true;

    // Clear pending queue for other directories
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

    // Also cancel any currently processing thumbnails
    final List<_ThumbnailRequest> processingsToRemove = [];
    for (final request in _processingQueue) {
      final requestDir = path.dirname(request.videoPath);
      if (requestDir != dirPath) {
        if (!request.completer.isCompleted) {
          request.completer.complete(null);
        }
        processingsToRemove.add(request);
        canceledCount++;
      }
    }

    _processingQueue.removeWhere((req) => processingsToRemove.contains(req));

    // Reset flag after clearing the queues
    _shouldStopProcessing = false;

    _log(
        'VideoThumbnail: Canceled $canceledCount thumbnails for other directories',
        forceShow: true);
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
      final tempDir = await AppPathHelper.getVideoCacheDir();
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

  /// Process the thumbnail generation queue
  static Future<void> _processQueue() async {
    if (_isProcessingQueue || _pendingQueue.isEmpty) return;

    _isProcessingQueue = true;

    try {
      while (_pendingQueue.isNotEmpty) {
        final request = _pendingQueue.removeAt(0);

        try {
          final result = await _generateThumbnailInternal(request.videoPath,
              forceRegenerate: request.forceRegenerate);

          if (result != null) {
            _fileCache[request.videoPath] = result;
            request.completer.complete(result);
          } else {
            request.completer.complete(null);
          }
        } catch (e) {
          debugPrint(
              'VideoThumbnail: Error processing request for ${request.videoPath}: $e');
          request.completer.complete(null);
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Generate cache filename for video path
  static String _generateCacheFilename(String videoPath) {
    final fileName = path.basename(videoPath);
    final nameWithoutExt = path.basenameWithoutExtension(fileName);
    final hash = videoPath.hashCode.abs();
    return '${nameWithoutExt}_${hash}.jpg';
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
      // Check if processing should stop before doing intensive work
      if (_shouldStopProcessing) {
        _log(
            'VideoThumbnail: Generation canceled for $videoPath due to directory change');
        return null;
      }

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

      // Check again if we should stop before starting the compute-intensive work
      if (_shouldStopProcessing) {
        _log(
            'VideoThumbnail: Generation canceled for $videoPath due to directory change');
        return null;
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
      String? generatedPath;
      try {
        generatedPath = await compute(_generateThumbnailIsolate, args).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _log('VideoThumbnail: Timeout generating thumbnail for $videoPath',
                forceShow: true);
            return null;
          },
        );
      } catch (e, stack) {
        _log('VideoThumbnail: Error during compute for $videoPath: $e\n$stack',
            forceShow: true);
        return null;
      }

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
          if (thumbnailPath != null) {
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

  /// Generate a thumbnail for a video file
  static Future<String?> generateThumbnail(
    String videoPath, {
    bool forceRegenerate = false,
    bool isPriority = false,
    int? quality,
    int? thumbnailSize,
  }) async {
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
      final cachedPath = _inMemoryPathCache[videoPath];
      if (cachedPath != null) {
        final cacheFile = File(cachedPath);
        if (await cacheFile.exists()) {
          // Đưa lại lên đầu cache nếu tồn tại
          final value = _inMemoryPathCache.remove(videoPath)!;
          _inMemoryPathCache[videoPath] = value;
          return cachedPath;
        } else {
          // Xóa khỏi cache nếu không hợp lệ
          _inMemoryPathCache.remove(videoPath);
        }
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
    defaultFallback() => Container(
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
            filterQuality: FilterQuality.high,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    // Add video play icon overlay
                    const Center(
                      child: Icon(
                        EvaIcons.playCircleOutline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
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
    _shouldStopProcessing = true;

    try {
      // Clear in-memory caches first
      _fileCache.clear();
      _inMemoryPathCache.clear();

      // Don't clear _attemptedPaths here, we want to regenerate all thumbnails
      // including those that previously failed
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
      await Future.delayed(const Duration(milliseconds: 100));

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

      // Clear Flutter's image cache to prevent memory leaks and old thumbnail display
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (e) {
        _log('VideoThumbnail: Error clearing PaintingBinding image cache: $e');
      }

      // Delete physical thumbnail files
      try {
        final tempDir = await AppPathHelper.getVideoCacheDir();
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
            // Use throttled logging for individual file errors
            _logWithPathThrottle(
                'VideoThumbnail: Error deleting thumbnail file: $e', file.path);
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
      // Reset processing flags and allow new requests
      _isProcessingQueue = wasProcessing;
      _shouldStopProcessing = false;
    }
  }

  static Future<void> trimCache() async {
    _log('VideoThumbnail: Trimming cache...');
    if (_fileCache.length > _maxFileCacheSize / 2) {
      final keysToRemoveCount = _fileCache.length - (_maxFileCacheSize ~/ 2);
      final keysToRemove = _fileCache.keys.take(keysToRemoveCount).toList();

      int removedCount = 0;
      for (final key in keysToRemove) {
        _fileCache.remove(key);
        removedCount++;
      }

      _log(
          'VideoThumbnail: Trimmed in-memory cache, removed $removedCount items.');
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
    return generateThumbnail(
      videoPath,
      forceRegenerate: true,
      isPriority: true,
    );
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

      // Clear the attempted paths to force regeneration
      for (final videoPath in videoPaths) {
        _attemptedPaths.remove(videoPath);
      }

      // Use the optimized batch preload with explicit forceRegenerate flag
      // First process the first 10 visible files with higher priority
      final visibleFiles = videoPaths.take(10).toList();
      final remainingFiles = videoPaths.skip(10).toList();

      // Process visible files first with higher priority
      for (final videoPath in visibleFiles) {
        await _requestThumbnail(videoPath,
            priority: _visiblePriority, forceRegenerate: true);

        // Small delay between each request to prevent system overload
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Then process remaining files with normal priority
      if (remainingFiles.isNotEmpty) {
        await optimizedBatchPreload(remainingFiles,
            maxConcurrent: 2, visibleCount: 20);
      }

      _log(
          'VideoThumbnail: Regeneration queued for ${videoPaths.length} videos',
          forceShow: true);

      // Notify listeners that cache has changed (thumbnails are being regenerated)
      _notifyCacheChanged();
    } catch (e) {
      _log('VideoThumbnail: Error regenerating thumbnails: $e',
          forceShow: true);
    }
  }

  /// Explicitly stop all thumbnail processing
  /// Call this method when navigating to a different folder or opening a file
  static void stopAllProcessing() {
    _log('VideoThumbnail: Explicitly stopping all thumbnail processing',
        forceShow: true);
    _shouldStopProcessing = true;

    // Clear the processing queue
    for (final request in _processingQueue) {
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }

    // Don't actually remove items from processing queue here
    // They'll be cleaned up naturally in the process queue loop

    // Wait a short time before allowing processing to continue
    // This helps prevent immediate restart of processing
    Future.delayed(const Duration(milliseconds: 100), () {
      _shouldStopProcessing = false;
    });
  }

  /// Check if thumbnail processing should stop
  /// This can be called from other classes to check if they should stop processing
  static bool shouldStopProcessing() {
    return _shouldStopProcessing;
  }

  /// Tìm thumbnail trong cache hoặc tạo mới nếu cần
  static Future<String?> getThumbnail(
    String videoPath, {
    bool forceRegenerate = false,
    bool isPriority = false,
    double? thumbnailPercentage,
    int? quality,
    int? thumbnailSize,
  }) async {
    if (!_cacheInitialized) {
      await initializeCache();
    }

    if (videoPath.isEmpty || !await File(videoPath).exists()) {
      _logWithPathThrottle(
          'VideoThumbnail: Invalid video path: $videoPath', videoPath);
      return null;
    }

    // Check in memory cache first for faster response
    if (!forceRegenerate && _inMemoryPathCache.containsKey(videoPath)) {
      final cachedPath = _inMemoryPathCache[videoPath];
      if (cachedPath != null) {
        final cacheFile = File(cachedPath);
        if (await cacheFile.exists()) {
          _logWithPathThrottle(
              'VideoThumbnail: Using in-memory cached thumbnail for $videoPath',
              videoPath);
          return cachedPath;
        } else {
          // Remove invalid cache entry
          _inMemoryPathCache.remove(videoPath);
        }
      }
    }

    // Next check permanent file cache
    if (!forceRegenerate) {
      final cachedPath = await getFromCache(videoPath);
      if (cachedPath != null) {
        _logWithPathThrottle(
            'VideoThumbnail: Using file-cached thumbnail for $videoPath',
            videoPath);
        // Also update in-memory cache
        _inMemoryPathCache[videoPath] = cachedPath;
        return cachedPath;
      }
    }

    // No valid cache entry, generate a new thumbnail
    _logWithPathThrottle(
        'VideoThumbnail: No cache found or regenerate requested for $videoPath',
        videoPath);
    // Note: thumbnailPercentage is stored globally but not used directly in generateThumbnail
    return generateThumbnail(
      videoPath,
      forceRegenerate: forceRegenerate,
      isPriority: isPriority,
      quality: quality,
      thumbnailSize: thumbnailSize,
    );
  }

  /// Get the cache directory path where thumbnails are stored
  static Future<String?> getCacheDirectoryPath() async {
    try {
      final dir = await AppPathHelper.getVideoCacheDir();
      return dir.path;
    } catch (e) {
      debugPrint('VideoThumbnail: Error getting cache directory path: $e');
      return null;
    }
  }

  /// Safe method to initialize BackgroundIsolateBinaryMessenger without crashing
  static void _safeInitializeBackgroundIsolate(RootIsolateToken? token) {
    if (token == null) {
      debugPrint(
          'VideoThumbnail: RootIsolateToken is null, skipping BackgroundIsolateBinaryMessenger initialization');
      return;
    }

    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      debugPrint(
          'VideoThumbnail: BackgroundIsolateBinaryMessenger initialized successfully');
    } catch (e) {
      debugPrint(
          'VideoThumbnail: Failed to initialize BackgroundIsolateBinaryMessenger: $e');
      // Continue without platform channels - this is not critical for thumbnail generation
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
