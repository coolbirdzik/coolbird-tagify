import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Advanced queue manager for thumbnail generation
/// Prevents UI blocking by carefully controlling when thumbnails are generated
class ThumbnailQueueManager {
  static final ThumbnailQueueManager _instance =
      ThumbnailQueueManager._internal();
  factory ThumbnailQueueManager() => _instance;
  ThumbnailQueueManager._internal();

  // Priority queue for thumbnail requests
  final PriorityQueue<ThumbnailRequest> _queue =
      PriorityQueue<ThumbnailRequest>();

  // Currently active requests
  final Map<String, Completer<String?>> _activeRequests = {};

  // Strict concurrency control - only 1 at a time
  static const int _maxConcurrent = 1;
  int _activeThumbnails = 0;

  // Longer delays to prevent UI freezing
  static const Duration _processingDelay = Duration(milliseconds: 200);
  static const Duration _batchDelay = Duration(milliseconds: 500);

  // Background processing timer
  Timer? _processingTimer;

  // Queue processing state
  bool _isProcessing = false;

  /// Add thumbnail request to queue
  Future<String?> requestThumbnail({
    required String videoPath,
    required String outputPath,
    required Future<String?> Function() generator,
    int priority = 0,
    bool isVisible = false,
  }) async {
    final requestId = '${videoPath}:${outputPath}';

    // Check if already processing this request
    if (_activeRequests.containsKey(requestId)) {
      return _activeRequests[requestId]!.future;
    }

    final completer = Completer<String?>();
    _activeRequests[requestId] = completer;

    // Add to queue with higher priority for visible items
    final request = ThumbnailRequest(
      id: requestId,
      videoPath: videoPath,
      outputPath: outputPath,
      generator: generator,
      priority: isVisible ? priority + 1000 : priority,
      completer: completer,
    );

    _queue.add(request);

    // Start processing if not already running
    _startProcessing();

    return completer.future;
  }

  /// Start queue processing with careful timing
  void _startProcessing() {
    if (_isProcessing) return;

    _isProcessing = true;
    _processingTimer?.cancel();

    _processingTimer = Timer.periodic(_processingDelay, (timer) {
      _processNext();
    });
  }

  /// Process next item in queue
  Future<void> _processNext() async {
    // Stop if too many active or queue empty
    if (_activeThumbnails >= _maxConcurrent || _queue.isEmpty) {
      if (_queue.isEmpty && _activeThumbnails == 0) {
        _stopProcessing();
      }
      return;
    }

    final request = _queue.removeFirst();
    _activeThumbnails++;

    try {
      // Add significant delay to prevent UI blocking
      await Future.delayed(const Duration(milliseconds: 100));

      // Generate thumbnail
      final result = await request.generator();

      // Complete the request
      if (!request.completer.isCompleted) {
        request.completer.complete(result);
      }
    } catch (e) {
      // Handle error
      if (!request.completer.isCompleted) {
        request.completer.completeError(e);
      }
    } finally {
      _activeThumbnails--;
      _activeRequests.remove(request.id);

      // Add delay before processing next item
      await Future.delayed(_batchDelay);
    }
  }

  /// Stop processing
  void _stopProcessing() {
    _isProcessing = false;
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Clear all pending requests
  void clearQueue() {
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      if (!request.completer.isCompleted) {
        request.completer.complete(null);
      }
    }
    _activeRequests.clear();
  }

  /// Get queue statistics
  Map<String, int> getStats() {
    return {
      'queueSize': _queue.length,
      'activeRequests': _activeThumbnails,
      'pendingRequests': _activeRequests.length,
    };
  }
}

/// Thumbnail request data structure
class ThumbnailRequest implements Comparable<ThumbnailRequest> {
  final String id;
  final String videoPath;
  final String outputPath;
  final Future<String?> Function() generator;
  final int priority;
  final Completer<String?> completer;
  final DateTime createdAt;

  ThumbnailRequest({
    required this.id,
    required this.videoPath,
    required this.outputPath,
    required this.generator,
    required this.priority,
    required this.completer,
  }) : createdAt = DateTime.now();

  @override
  int compareTo(ThumbnailRequest other) {
    // Higher priority first, then by creation time
    if (priority != other.priority) {
      return other.priority.compareTo(priority);
    }
    return createdAt.compareTo(other.createdAt);
  }
}

/// Simple priority queue implementation
class PriorityQueue<T extends Comparable<T>> {
  final List<T> _items = [];

  void add(T item) {
    _items.add(item);
    _items.sort();
  }

  T removeFirst() {
    if (_items.isEmpty) throw StateError('Queue is empty');
    return _items.removeAt(0);
  }

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;
}
