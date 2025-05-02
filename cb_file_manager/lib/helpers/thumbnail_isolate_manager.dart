import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/services.dart';
import '../helpers/fc_native_video_thumbnail.dart';

/// A manager for efficient video thumbnail generation using isolates
///
/// This class handles concurrent thumbnail generation in background isolates,
/// prioritizing visible thumbnails and efficiently managing system resources.
class ThumbnailIsolateManager {
  // Singleton instance
  static final ThumbnailIsolateManager _instance = ThumbnailIsolateManager._();
  static ThumbnailIsolateManager get instance => _instance;

  // Isolate pool configuration
  static final int _maxIsolates = Platform.isWindows ? 6 : 3;
  static final int _maxConcurrentProcessing = Platform.isWindows ? 3 : 1;

  // Worker and request tracking
  final List<_IsolateWorker> _workers = [];
  final Map<String, Completer<String?>> _pendingRequests = {};
  final List<_ThumbnailRequest> _queue = [];
  final List<String> _processingPaths = [];

  // State tracking
  bool _isProcessingQueue = false;
  bool _debugMode = false;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Private constructor for singleton
  ThumbnailIsolateManager._();

  /// Enable or disable debug logging
  void setDebugMode(bool enable) {
    _debugMode = enable;
  }

  /// Log message if debug mode is enabled
  void _log(String message) {
    if (_debugMode) {
      debugPrint('[ThumbnailIsolate] $message');
    }
  }

  /// Initialize the isolate system
  ///
  /// Creates a pool of isolate workers for handling thumbnail generation
  Future<void> initialize() async {
    if (_isInitialized) return;

    _log('Initializing ThumbnailIsolateManager');

    // Create isolate workers
    for (int i = 0; i < _maxIsolates; i++) {
      final worker = _IsolateWorker(id: i);
      await worker.spawn();
      _workers.add(worker);
      _log('Worker #$i spawned');
    }

    _isInitialized = true;
    _log('ThumbnailIsolateManager initialized with $_maxIsolates workers');
  }

  /// Release all resources and stop all isolates
  Future<void> dispose() async {
    _log('Disposing ThumbnailIsolateManager');

    // Cancel all pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    // Stop all isolates
    for (final worker in _workers) {
      await worker.stop();
    }

    _workers.clear();
    _pendingRequests.clear();
    _queue.clear();
    _isInitialized = false;

    _log('ThumbnailIsolateManager disposed');
  }

  /// Generate a thumbnail for a video with restart capability
  ///
  /// [videoPath] Path to the video file
  /// [priority] Higher values get processed sooner (0-200)
  /// [force] Ignore cache and regenerate
  /// [forceRegenerate] Force regeneration even if already in cache
  /// [quality] JPEG quality (0-100)
  /// [maxSize] Maximum thumbnail dimension
  /// [thumbnailPercentage] Position in video (0-100)
  Future<String?> generateThumbnail(
    String videoPath, {
    int priority = 0,
    bool force = false,
    bool forceRegenerate = false,
    int quality = 70,
    int maxSize = 200,
    double thumbnailPercentage = 10.0,
  }) async {
    if (_workers.isEmpty) {
      await initialize();
    }

    // Handle force regeneration requests
    if (forceRegenerate) {
      _cleanupExistingRequests(videoPath);
      force = true;
    }

    // Special fast path for high priority items during scrolling
    if (priority >= 120) {
      final cachedPath = await _checkFastCache(videoPath);
      if (cachedPath != null) return cachedPath;
    }

    // Check regular cache unless forced
    if (!force) {
      final cachedPath = await _checkCache(videoPath);
      if (cachedPath != null) return cachedPath;
    }

    // Update priority of existing request if needed
    if (_updateExistingRequestPriority(videoPath, priority)) {
      _log(
          'Request for $videoPath already in queue, returning existing future');
      return _pendingRequests[videoPath]!.future;
    }

    // Create new request
    final completer = Completer<String?>();
    _pendingRequests[videoPath] = completer;

    // Add to queue
    _queue.add(_ThumbnailRequest(
      videoPath: videoPath,
      priority: priority,
      force: force,
      quality: quality,
      maxSize: maxSize,
      thumbnailPercentage: thumbnailPercentage,
    ));

    // Sort queue by priority
    _sortQueue();

    // Start processing if not already
    if (!_isProcessingQueue) {
      _processQueue();
    }

    return completer.future;
  }

  /// Quickly check cache for high-priority requests
  Future<String?> _checkFastCache(String videoPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFilename = _createCacheFilename(videoPath);
      final thumbnailPath = path.join(cacheDir.path, cacheFilename);

      final cacheFile = File(thumbnailPath);
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        _log('Fast path: Found cached thumbnail for $videoPath');
        return thumbnailPath;
      }
    } catch (e) {
      _log('Error in fast path check: $e');
    }
    return null;
  }

  /// Check if thumbnail is in cache
  Future<String?> _checkCache(String videoPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFilename = _createCacheFilename(videoPath);
      final thumbnailPath = path.join(cacheDir.path, cacheFilename);

      final cacheFile = File(thumbnailPath);
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        _log('Found cached thumbnail for $videoPath');
        return thumbnailPath;
      }
    } catch (e) {
      _log('Cache check error: $e');
    }
    return null;
  }

  /// Remove any existing requests for this video path
  void _cleanupExistingRequests(String videoPath) {
    if (_pendingRequests.containsKey(videoPath)) {
      if (!_pendingRequests[videoPath]!.isCompleted) {
        _pendingRequests[videoPath]!.complete(null);
      }
      _pendingRequests.remove(videoPath);
    }

    _queue.removeWhere((request) => request.videoPath == videoPath);
  }

  /// Update priority of existing request if it exists
  bool _updateExistingRequestPriority(String videoPath, int priority) {
    // Find in queue to update priority
    final existingIndex = _queue.indexWhere((r) => r.videoPath == videoPath);
    if (existingIndex != -1) {
      // If new priority is higher, update it and resort the queue
      if (priority > _queue[existingIndex].priority) {
        _log(
            'Updating priority for $videoPath from ${_queue[existingIndex].priority} to $priority');
        _queue[existingIndex] = _ThumbnailRequest(
          videoPath: videoPath,
          priority: priority,
          force: _queue[existingIndex].force,
          quality: _queue[existingIndex].quality,
          maxSize: _queue[existingIndex].maxSize,
          thumbnailPercentage: _queue[existingIndex].thumbnailPercentage,
        );

        _sortQueue();
      }
      return true;
    }

    return _pendingRequests.containsKey(videoPath);
  }

  /// Sort the queue by priority (high to low)
  void _sortQueue() {
    _queue.sort((a, b) {
      // First sort by priority
      int result = b.priority.compareTo(a.priority);
      if (result != 0) return result;

      // Then by being forced (forced items take precedence)
      if (a.force != b.force) return a.force ? -1 : 1;

      // Finally by path for consistency
      return a.videoPath.compareTo(b.videoPath);
    });
  }

  /// Process the thumbnail queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _queue.isEmpty) return;

    _isProcessingQueue = true;

    while (_queue.isNotEmpty) {
      // Find available worker
      final availableWorker = _findAvailableWorker();
      if (availableWorker == null ||
          _processingPaths.length >= _maxConcurrentProcessing) {
        // No worker available or at max concurrent tasks, wait a bit
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      // Sort the queue again to ensure priorities are respected
      _sortQueue();

      // Get highest priority request
      final request = _queue.removeAt(0);
      final videoPath = request.videoPath;

      _log(
          'Processing request for $videoPath on worker #${availableWorker.id}');

      // Mark worker as busy and track processing path
      availableWorker.isBusy = true;
      _processingPaths.add(videoPath);

      // Send request to worker
      try {
        final result = await availableWorker.generateThumbnail(
          videoPath,
          force: request.force,
          quality: request.quality,
          maxSize: request.maxSize,
          thumbnailPercentage: request.thumbnailPercentage,
        );

        // Complete the request
        if (_pendingRequests.containsKey(videoPath) &&
            !_pendingRequests[videoPath]!.isCompleted) {
          _pendingRequests[videoPath]!.complete(result);
        }
      } catch (e) {
        _log('Error generating thumbnail for $videoPath: $e');
        if (_pendingRequests.containsKey(videoPath) &&
            !_pendingRequests[videoPath]!.isCompleted) {
          _pendingRequests[videoPath]!.complete(null);
        }
      } finally {
        // Cleanup and mark worker as available
        availableWorker.isBusy = false;
        _processingPaths.remove(videoPath);
        _pendingRequests.remove(videoPath);
      }
    }

    _isProcessingQueue = false;
  }

  /// Find an available worker
  _IsolateWorker? _findAvailableWorker() {
    for (final worker in _workers) {
      if (!worker.isBusy) {
        return worker;
      }
    }
    return null;
  }

  /// Create cache filename from video path
  String _createCacheFilename(String videoPath) {
    final bytes = utf8.encode(videoPath);
    final digest = md5.convert(bytes);
    return 'thumb_${digest.toString()}.jpg';
  }

  /// Prefetch thumbnails for multiple videos
  ///
  /// [videoPaths] List of video paths to generate thumbnails for
  /// [basePriority] Base priority value for all requests
  Future<void> prefetchThumbnails(List<String> videoPaths,
      {int basePriority = 0}) async {
    _log('Prefetching ${videoPaths.length} thumbnails');

    final priorityGroups = _splitIntoPriorityGroups(videoPaths);

    // Queue each group with different priorities
    for (int i = 0; i < priorityGroups.length; i++) {
      final group = priorityGroups[i];
      final groupPriority = basePriority + (priorityGroups.length - i) * 10;

      for (final videoPath in group) {
        generateThumbnail(videoPath, priority: groupPriority);
      }

      // Add delay between groups to reduce system load
      if (i < priorityGroups.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Split videos into priority groups based on likely visibility
  List<List<String>> _splitIntoPriorityGroups(List<String> videoPaths) {
    if (videoPaths.isEmpty) return [];

    final result = <List<String>>[];

    // Group 1: Highest priority (first 10 videos)
    final highPriority = videoPaths.take(10).toList();
    if (highPriority.isNotEmpty) {
      result.add(highPriority);
    }

    // Group 2: Medium priority (next 20 videos)
    final mediumPriority = videoPaths.skip(10).take(20).toList();
    if (mediumPriority.isNotEmpty) {
      result.add(mediumPriority);
    }

    // Group 3: Low priority (remaining videos)
    final lowPriority = videoPaths.skip(30).toList();
    if (lowPriority.isNotEmpty) {
      result.add(lowPriority);
    }

    return result;
  }

  /// Cancel requests that aren't relevant to current directory
  void cancelRequestsNotInDirectory(String directoryPath) {
    if (directoryPath.isEmpty) return;

    final keysToRemove = <String>[];

    // Find requests not in the current directory
    for (final key in _pendingRequests.keys) {
      if (!key.startsWith(directoryPath)) {
        keysToRemove.add(key);
      }
    }

    // Cancel irrelevant requests
    for (final key in keysToRemove) {
      if (!_pendingRequests[key]!.isCompleted) {
        _pendingRequests[key]!.complete(null);
      }
      _pendingRequests.remove(key);
    }

    // Remove from queue
    _queue.removeWhere((req) => !req.videoPath.startsWith(directoryPath));

    _log('Canceled ${keysToRemove.length} requests not in $directoryPath');
  }
}

/// Worker isolate to generate thumbnails
class _IsolateWorker {
  final int id;
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool isBusy = false;
  final Map<int, Completer<String?>> _requests = {};
  int _nextRequestId = 0;

  _IsolateWorker({required this.id});

  /// Initialize the isolate
  Future<void> spawn() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort!.sendPort,
      debugName: 'thumbnail_worker_$id',
    );

    // Listen for messages from the isolate
    _receivePort!.listen((message) {
      if (message is SendPort) {
        // Save SendPort to send messages to the isolate
        _sendPort = message;
      } else if (message is Map) {
        // Handle result
        final requestId = message['id'] as int;
        final result = message['result'] as String?;

        if (_requests.containsKey(requestId)) {
          _requests[requestId]!.complete(result);
          _requests.remove(requestId);
        }
      }
    });

    // Wait until SendPort is received from the isolate
    while (_sendPort == null) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Stop the isolate
  Future<void> stop() async {
    // Cancel all pending requests
    for (final completer in _requests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    // Stop the isolate
    _isolate?.kill();
    _receivePort?.close();

    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }

  /// Send a thumbnail generation request to the isolate
  Future<String?> generateThumbnail(
    String videoPath, {
    bool force = false,
    int quality = 70,
    int maxSize = 200,
    double thumbnailPercentage = 10.0,
  }) async {
    if (_sendPort == null) {
      throw Exception('Isolate not initialized');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<String?>();
    _requests[requestId] = completer;

    // Prepare parameters
    final params = <String, dynamic>{
      'id': requestId,
      'videoPath': videoPath,
      'force': force,
      'quality': quality,
      'maxSize': maxSize,
      'thumbnailPercentage': thumbnailPercentage,
      'isWindows': Platform.isWindows,
    };

    // Send request to the isolate
    _sendPort!.send(params);

    return completer.future;
  }

  /// Entry point for the isolate
  static void _isolateEntryPoint(SendPort sendPort) async {
    // Create ReceivePort to receive messages from the main thread
    final receivePort = ReceivePort();

    // Send SendPort back to the main thread
    sendPort.send(receivePort.sendPort);

    // Handle messages
    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final requestId = message['id'] as int;
        final videoPath = message['videoPath'] as String;
        final force = message['force'] as bool;
        final quality = message['quality'] as int;
        final maxSize = message['maxSize'] as int;
        final thumbnailPercentage = message['thumbnailPercentage'] as double;
        final isWindows = message['isWindows'] as bool;

        String? result;
        try {
          result = await _generateThumbnailInIsolate(
            videoPath,
            force: force,
            quality: quality,
            maxSize: maxSize,
            thumbnailPercentage: thumbnailPercentage,
            isWindows: isWindows,
          );
        } catch (e) {
          // Send error back to the main thread
          sendPort.send({
            'id': requestId,
            'result': null,
            'error': e.toString(),
          });
          return;
        }

        // Send result back to the main thread
        sendPort.send({
          'id': requestId,
          'result': result,
        });
      }
    });
  }

  /// Generate thumbnail in the isolate
  static Future<String?> _generateThumbnailInIsolate(
    String videoPath, {
    bool force = false,
    int quality = 70,
    int maxSize = 200,
    double thumbnailPercentage = 10.0,
    bool isWindows = false,
  }) async {
    try {
      // Create cache filename
      final cacheFilename = _createCacheFilenameInIsolate(videoPath);
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = path.join(tempDir.path, cacheFilename);

      // Check cache
      if (!force) {
        final cacheFile = File(thumbnailPath);
        if (await cacheFile.exists() && await cacheFile.length() > 0) {
          return thumbnailPath;
        }
      }

      // Delete old file if force
      if (force) {
        final cacheFile = File(thumbnailPath);
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
      }

      // Calculate timestamp for thumbnail
      final videoDuration = await _estimateVideoDuration(videoPath);
      final timestampMs =
          ((thumbnailPercentage / 100) * videoDuration * 1000).round();

      // Generate thumbnail
      String? generatedPath;

      // Try native method on Windows
      if (isWindows) {
        try {
          if (_isSupportedVideoFormat(videoPath)) {
            generatedPath = await FcNativeVideoThumbnail.generateThumbnail(
              videoPath: videoPath,
              outputPath: thumbnailPath,
              width: maxSize,
              format: 'jpg',
              timeSeconds: timestampMs ~/ 1000,
            );

            if (generatedPath != null) {
              final file = File(generatedPath);
              if (await file.exists() && await file.length() > 0) {
                return generatedPath;
              }
            }
          }
        } catch (_) {
          // Fallback to package method
        }
      }

      // Use package video_thumbnail
      String videoPathForPackage = videoPath;
      if (isWindows) {
        videoPathForPackage = videoPath.replaceAll('\\', '/');
      }

      generatedPath = await VideoThumbnail.thumbnailFile(
        video: videoPathForPackage,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        quality: quality,
        maxHeight: maxSize,
        maxWidth: maxSize,
        timeMs: timestampMs,
      );

      if (generatedPath != null) {
        final file = File(generatedPath);
        if (await file.exists() && await file.length() > 0) {
          return generatedPath;
        }
      }

      return null;
    } catch (e) {
      // Rethrow to allow main thread to handle
      rethrow;
    }
  }

  /// Create cache filename from video path in isolate
  static String _createCacheFilenameInIsolate(String videoPath) {
    final bytes = utf8.encode(videoPath);
    final digest = md5.convert(bytes);
    return 'thumb_isolate_${digest.toString()}.jpg';
  }

  /// Estimate video duration
  static Future<int> _estimateVideoDuration(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        // Estimate duration based on file size (1MB ~ 10 seconds)
        final estimatedSeconds = (fileSize / (1024 * 1024) * 10).round();
        return estimatedSeconds.clamp(1, 600); // Limit 1-600 seconds
      }
    } catch (_) {}
    return 60; // Default 60 seconds
  }

  /// Check if video format is supported
  static bool _isSupportedVideoFormat(String filePath) {
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
}

/// Object containing thumbnail request information
class _ThumbnailRequest {
  final String videoPath;
  final int priority;
  final bool force;
  final int quality;
  final int maxSize;
  final double thumbnailPercentage;

  _ThumbnailRequest({
    required this.videoPath,
    required this.priority,
    required this.force,
    required this.quality,
    required this.maxSize,
    required this.thumbnailPercentage,
  });
}
