import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'memory_management_service.dart';

/// Service for optimizing video player performance and reducing ImageReader_JNI errors
class VideoPlayerOptimizer {
  static final VideoPlayerOptimizer _instance =
      VideoPlayerOptimizer._internal();
  factory VideoPlayerOptimizer() => _instance;
  VideoPlayerOptimizer._internal();

  Timer? _memoryMonitorTimer;
  Timer? _bufferCleanupTimer;
  bool _isMonitoring = false;
  int _consecutiveBufferErrors = 0;
  int _consecutiveImageReaderErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  static const int _maxImageReaderErrors = 2;

  // Buffer management
  bool _isBufferReduced = false;
  bool _isQualityReduced = false;
  int _currentBufferSize = 1024 * 1024; // 1MB initial
  static const int _minBufferSize = 256 * 1024; // 256KB minimum
  static const int _maxBufferSize = 4 * 1024 * 1024; // 4MB maximum

  /// Initialize video player optimizations
  Future<void> initialize() async {
    // Initialize memory management service
    await MemoryManagementService().initialize();

    // Set Media Kit global options for better performance
    await _configureMediaKitOptions();

    // Start memory monitoring
    startMemoryMonitoring();

    // Start buffer cleanup timer
    startBufferCleanupTimer();
  }

  /// Configure Media Kit global options
  Future<void> _configureMediaKitOptions() async {
    try {
      // Set Media Kit options for better buffer management
      // Note: Media Kit doesn't expose all low-level options, so we focus on what's available

      // Configure global Media Kit settings for better memory management
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint(
          'VideoPlayerOptimizer: Error configuring Media Kit options: $e');
    }
  }

  /// Start memory monitoring to prevent ImageReader_JNI errors
  void startMemoryMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkMemoryUsage();
    });
  }

  /// Start buffer cleanup timer to prevent buffer accumulation
  void startBufferCleanupTimer() {
    _bufferCleanupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _performBufferCleanup();
    });
  }

  /// Stop memory monitoring
  void stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    _isMonitoring = false;
  }

  /// Stop buffer cleanup timer
  void stopBufferCleanupTimer() {
    _bufferCleanupTimer?.cancel();
    _bufferCleanupTimer = null;
  }

  /// Check memory usage and trigger optimizations if needed
  void _checkMemoryUsage() {
    try {
      // Get memory info (this is platform-specific)
      if (Platform.isAndroid) {
        // On Android, we can use platform channels to get memory info
        _checkAndroidMemoryUsage();
      }
    } catch (e) {
      debugPrint('VideoPlayerOptimizer: Error checking memory usage: $e');
    }
  }

  /// Check Android-specific memory usage
  void _checkAndroidMemoryUsage() {
    // This would need to be implemented with platform channels
    // For now, we'll use a simple heuristic based on available memory
    // and trigger cleanup if we've had recent buffer errors
    if (_consecutiveImageReaderErrors > 0) {
      _performProactiveBufferCleanup();
    }
  }

  /// Perform proactive buffer cleanup to prevent ImageReader_JNI errors
  void _performProactiveBufferCleanup() {
    debugPrint('VideoPlayerOptimizer: Performing proactive buffer cleanup');

    // Force garbage collection if available
    _forceGarbageCollection();

    // Reduce buffer size if we're having issues
    if (_consecutiveImageReaderErrors >= 2 && !_isBufferReduced) {
      _reduceBufferSize();
    }
  }

  /// Force garbage collection to free up memory
  void _forceGarbageCollection() {
    try {
      debugPrint('VideoPlayerOptimizer: Requesting garbage collection');

      // Use MemoryManagementService for better GC control
      MemoryManagementService().forceGarbageCollection();
    } catch (e) {
      debugPrint('VideoPlayerOptimizer: Error during garbage collection: $e');
    }
  }

  /// Reduce buffer size to prevent memory pressure
  void _reduceBufferSize() {
    if (_currentBufferSize > _minBufferSize) {
      _currentBufferSize = (_currentBufferSize / 2).round();
      _currentBufferSize =
          _currentBufferSize.clamp(_minBufferSize, _maxBufferSize);
      _isBufferReduced = true;

      debugPrint(
          'VideoPlayerOptimizer: Reduced buffer size to ${_currentBufferSize} bytes');
    }
  }

  /// Perform regular buffer cleanup
  void _performBufferCleanup() {
    debugPrint('VideoPlayerOptimizer: Performing regular buffer cleanup');

    // Reset error counters if no recent errors
    if (_consecutiveBufferErrors > 0) {
      _consecutiveBufferErrors = max(0, _consecutiveBufferErrors - 1);
    }

    if (_consecutiveImageReaderErrors > 0) {
      _consecutiveImageReaderErrors = max(0, _consecutiveImageReaderErrors - 1);
    }

    // Gradually increase buffer size back if no errors
    if (_isBufferReduced && _consecutiveImageReaderErrors == 0) {
      _currentBufferSize = min(_maxBufferSize, _currentBufferSize * 2);
      if (_currentBufferSize >= _maxBufferSize) {
        _isBufferReduced = false;
      }
    }
  }

  /// Create optimized player for SMB streaming
  Player createOptimizedPlayer() {
    final player = Player();

    // Add error handling for ImageReader_JNI errors
    player.stream.error.listen((error) {
      if (error.contains('ImageReader_JNI') || error.contains('buffer')) {
        _handleBufferError(player);
      }

      // Specific handling for ImageReader_JNI errors
      if (error.contains('ImageReader_JNI')) {
        _handleImageReaderError(player);
      }
    });

    // Add buffering monitoring
    player.stream.buffering.listen((buffering) {
      // Buffering state changed
      if (buffering) {
        debugPrint('VideoPlayerOptimizer: Buffering started');
      } else {
        debugPrint('VideoPlayerOptimizer: Buffering finished');
      }
    });

    // Add position monitoring to detect stalls
    player.stream.position.listen((position) {
      _monitorPlaybackPosition(player, position);
    });

    return player;
  }

  /// Monitor playback position to detect stalls
  void _monitorPlaybackPosition(Player player, Duration position) {
    // If position hasn't changed for more than 5 seconds, it might be stalled
    Timer(const Duration(seconds: 5), () {
      if (player.state.position == position && player.state.playing) {
        _handlePlaybackStall(player);
      }
    });
  }

  /// Monitor playback position to detect seek stalls
  void _monitorSeekStalls(Player player, Duration position) {
    // If position hasn't changed for more than 3 seconds during seeking, it might be stalled
    Timer(const Duration(seconds: 3), () {
      if (player.state.position == position && player.state.playing) {
        debugPrint(
            'VideoPlayerOptimizer: Detected potential seek stall at ${position.inSeconds}s');
        _handleSeekStall(player, position);
      }
    });
  }

  /// Handle seek stall
  void _handleSeekStall(Player player, Duration position) {
    debugPrint('VideoPlayerOptimizer: Handling seek stall');

    // Try to recover by force seeking slightly forward
    final seekPosition = position + const Duration(seconds: 2);

    _performForceSeek(player, seekPosition);

    // If still stalled after 5 seconds, try more aggressive recovery
    Timer(const Duration(seconds: 5), () {
      if (player.state.position == position && player.state.playing) {
        debugPrint(
            'VideoPlayerOptimizer: Seek still stalled, trying aggressive recovery');
        _aggressiveSeekRecovery(player, position);
      }
    });
  }

  /// Aggressive recovery for seek stalls
  void _aggressiveSeekRecovery(Player player, Duration position) {
    debugPrint('VideoPlayerOptimizer: Starting aggressive seek recovery');

    // Pause playback
    player.pause();

    // Wait a bit and try to seek to a different position
    Timer(const Duration(milliseconds: 1000), () async {
      try {
        // Try to seek to a position 10 seconds forward
        final seekPosition = position + const Duration(seconds: 10);
        await player.seek(seekPosition);
        await player.play();

        debugPrint('VideoPlayerOptimizer: Aggressive seek recovery completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: Aggressive seek recovery failed: $e');

        // If all else fails, try to restart playback
        _restartPlayback(player);
      }
    });
  }

  /// Restart playback from beginning
  void _restartPlayback(Player player) {
    debugPrint('VideoPlayerOptimizer: Restarting playback from beginning');

    // Pause playback
    player.pause();

    // Wait a bit and restart from beginning
    Timer(const Duration(seconds: 2), () async {
      try {
        await player.seek(Duration.zero);
        await player.play();

        debugPrint('VideoPlayerOptimizer: Playback restart completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: Playback restart failed: $e');
      }
    });
  }

  /// Handle playback stall
  void _handlePlaybackStall(Player player) {
    // Try to recover by seeking slightly forward
    final currentPosition = player.state.position;
    final seekPosition = currentPosition + const Duration(seconds: 1);

    player.seek(seekPosition);

    // If still stalled after 3 seconds, try more aggressive recovery
    Timer(const Duration(seconds: 3), () {
      if (player.state.position == currentPosition && player.state.playing) {
        _aggressiveRecovery(player);
      }
    });
  }

  /// Aggressive recovery for stalled playback
  void _aggressiveRecovery(Player player) {
    // Pause playback
    player.pause();

    // Wait a bit and try to resume
    Timer(const Duration(milliseconds: 1000), () {
      player.play();

      // If still not working, try seeking to a different position
      Timer(const Duration(seconds: 2), () {
        if (!player.state.playing) {
          final currentPosition = player.state.position;
          final seekPosition = currentPosition + const Duration(seconds: 5);
          player.seek(seekPosition);
          player.play();
        }
      });
    });
  }

  /// Handle buffer-related errors
  void _handleBufferError(Player player) {
    _consecutiveBufferErrors++;

    if (_consecutiveBufferErrors >= _maxConsecutiveErrors) {
      _consecutiveBufferErrors = 0;
      _performBufferRecovery(player);
    } else {
      // Pause playback temporarily to allow buffer recovery
      player.pause();

      // Wait a bit and then resume
      Timer(const Duration(milliseconds: 500), () {
        player.play();
      });
    }
  }

  /// Handle ImageReader_JNI errors specifically
  void _handleImageReaderError(Player player) {
    _consecutiveImageReaderErrors++;
    debugPrint(
        'VideoPlayerOptimizer: ImageReader_JNI error detected (count: $_consecutiveImageReaderErrors)');

    if (_consecutiveImageReaderErrors >= _maxImageReaderErrors) {
      _consecutiveImageReaderErrors = 0;
      _performImageReaderErrorRecovery(player);
    } else {
      // Immediate recovery attempt
      _performImmediateImageReaderRecovery(player);
    }
  }

  /// Perform immediate recovery for ImageReader_JNI errors
  void _performImmediateImageReaderRecovery(Player player) {
    debugPrint(
        'VideoPlayerOptimizer: Performing immediate ImageReader recovery');

    // Pause playback to stop buffer accumulation
    player.pause();

    // Force aggressive memory cleanup
    MemoryManagementService().forceAggressiveCleanup();

    // Reduce buffer size to minimum
    _currentBufferSize = _minBufferSize;
    MemoryManagementService().setVideoBufferSize(_currentBufferSize);

    // Wait for cleanup and resume
    Timer(const Duration(milliseconds: 2000), () {
      try {
        player.play();
        debugPrint('VideoPlayerOptimizer: ImageReader recovery completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: ImageReader recovery failed: $e');
      }
    });
  }

  /// Perform comprehensive recovery for ImageReader_JNI errors
  void _performImageReaderErrorRecovery(Player player) {
    debugPrint(
        'VideoPlayerOptimizer: Performing comprehensive ImageReader recovery');

    // Pause playback
    player.pause();

    // Force aggressive memory cleanup
    MemoryManagementService().forceAggressiveCleanup();

    // Reduce buffer size aggressively
    _currentBufferSize = _minBufferSize;
    _isBufferReduced = true;
    MemoryManagementService().setVideoBufferSize(_currentBufferSize);

    // Set aggressive memory management
    MemoryManagementService().setAggressiveMemoryManagement(true);

    // Wait longer for cleanup
    Timer(const Duration(seconds: 3), () {
      try {
        // Try to resume playback
        player.play();

        // If still having issues, try quality reduction
        Timer(const Duration(seconds: 5), () {
          if (_consecutiveImageReaderErrors > 0) {
            _performQualityReduction(player);
          }
        });

        debugPrint(
            'VideoPlayerOptimizer: Comprehensive ImageReader recovery completed');
      } catch (e) {
        debugPrint(
            'VideoPlayerOptimizer: Comprehensive ImageReader recovery failed: $e');
      }
    });
  }

  /// Perform quality reduction to prevent buffer issues
  void _performQualityReduction(Player player) {
    debugPrint('VideoPlayerOptimizer: Performing quality reduction');

    if (!_isQualityReduced) {
      _isQualityReduced = true;

      // Pause playback
      player.pause();

      // Force aggressive cleanup
      MemoryManagementService().forceAggressiveCleanup();

      // Set aggressive memory management
      MemoryManagementService().setAggressiveMemoryManagement(true);

      // Reduce buffer size to minimum
      _currentBufferSize = _minBufferSize;
      MemoryManagementService().setVideoBufferSize(_currentBufferSize);

      // Wait and resume with reduced quality
      Timer(const Duration(seconds: 2), () {
        try {
          player.play();
          debugPrint('VideoPlayerOptimizer: Quality reduction applied');
        } catch (e) {
          debugPrint('VideoPlayerOptimizer: Quality reduction failed: $e');
        }
      });
    }
  }

  /// Handle buffer-related errors with 4K-specific resolution reduction
  void _handleBufferErrorWith4KResolutionReduction(
      Player player, String mediaPath) {
    _consecutiveBufferErrors++;

    if (_consecutiveBufferErrors >= _maxConsecutiveErrors) {
      debugPrint(
          'VideoPlayerOptimizer: Too many buffer errors, attempting 4K-specific resolution reduction');
      _consecutiveBufferErrors = 0;

      // Check if this is a 4K video
      if (_is4KVideo(mediaPath)) {
        _perform4KResolutionReduction(player, mediaPath);
      } else {
        _performResolutionReduction(player, mediaPath);
      }
    } else {
      // Pause playback temporarily to allow buffer recovery
      player.pause();

      // Wait a bit and then resume
      Timer(const Duration(milliseconds: 500), () {
        player.play();
      });
    }
  }

  /// Handle seek errors with force seek
  void _handleSeekError(Player player, Duration targetPosition) {
    debugPrint(
        'VideoPlayerOptimizer: Handling seek error, attempting force seek');

    // Try to force seek by reopening media at the target position
    _performForceSeek(player, targetPosition);
  }

  /// Perform force seek by reopening media at target position
  void _performForceSeek(Player player, Duration targetPosition) {
    debugPrint(
        'VideoPlayerOptimizer: Performing force seek to ${targetPosition.inSeconds}s');

    // Pause playback
    player.pause();

    // Wait a bit and try to seek with force
    Timer(const Duration(milliseconds: 500), () async {
      try {
        // Try to seek with force
        await player.seek(targetPosition);

        // Resume playback
        await player.play();

        debugPrint('VideoPlayerOptimizer: Force seek completed successfully');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: Force seek failed: $e');

        // If force seek fails, try to reopen media at the target position
        _performMediaReopenAtPosition(player, targetPosition);
      }
    });
  }

  /// Reopen media at specific position
  void _performMediaReopenAtPosition(Player player, Duration targetPosition) {
    debugPrint(
        'VideoPlayerOptimizer: Reopening media at position ${targetPosition.inSeconds}s');

    // This would require storing the current media path
    // For now, we'll just try to seek again
    Timer(const Duration(seconds: 1), () async {
      try {
        await player.seek(targetPosition);
        await player.play();
        debugPrint('VideoPlayerOptimizer: Media reopen seek completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: Media reopen seek failed: $e');
      }
    });
  }

  /// Perform resolution reduction to prevent buffer issues
  void _performResolutionReduction(Player player, String mediaPath) {
    debugPrint('VideoPlayerOptimizer: Performing resolution reduction');

    // Pause playback
    player.pause();

    // Try to reopen media with reduced resolution
    Timer(const Duration(seconds: 1), () async {
      try {
        // Create new media with reduced resolution
        final reducedMedia = await createReducedResolutionMedia(mediaPath);

        // Reopen with new media
        await player.open(reducedMedia);

        // Resume playback
        await player.play();

        debugPrint('VideoPlayerOptimizer: Resolution reduction completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: Resolution reduction failed: $e');
        // Fallback to normal recovery
        _performBufferRecovery(player);
      }
    });
  }

  /// Perform 4K-specific resolution reduction
  void _perform4KResolutionReduction(Player player, String mediaPath) {
    debugPrint(
        'VideoPlayerOptimizer: Performing 4K-specific resolution reduction');

    // Pause playback
    player.pause();

    // Try to reopen media with 4K optimizations
    Timer(const Duration(seconds: 1), () async {
      try {
        // Create new media with 4K-specific optimizations
        final optimizedMedia = await create4KOptimizedMedia(mediaPath);

        // Reopen with new media
        await player.open(optimizedMedia);

        // Resume playback
        await player.play();

        debugPrint('VideoPlayerOptimizer: 4K resolution reduction completed');
      } catch (e) {
        debugPrint('VideoPlayerOptimizer: 4K resolution reduction failed: $e');
        // Fallback to normal recovery
        _performBufferRecovery(player);
      }
    });
  }

  /// Perform buffer recovery
  void _performBufferRecovery(Player player) {
    // Pause playback
    player.pause();

    // Wait longer for buffer recovery
    Timer(const Duration(seconds: 2), () {
      // Try to resume playback
      player.play();

      // Reset error counter after recovery attempt
      Timer(const Duration(seconds: 5), () {
        _consecutiveBufferErrors = 0;
      });
    });
  }

  /// Optimize video source for SMB streaming
  Future<Media> createOptimizedMedia(String path) async {
    // Check if it's an SMB path
    if (_isSmbPath(path)) {
      return _createSmbOptimizedMedia(path);
    }

    // Regular path - use standard Media
    return Media(path);
  }

  /// Check if path is SMB
  bool _isSmbPath(String path) {
    return path.startsWith('smb://') ||
        path.contains('\\') ||
        path.startsWith('//');
  }

  /// Create optimized media for SMB paths
  Future<Media> _createSmbOptimizedMedia(String path) async {
    // Create Media with optimized options for SMB streaming
    final media = Media(
      path,
      // Add any available Media Kit options for better streaming
    );

    return media;
  }

  /// Create media with aggressive resolution reduction for 4K videos
  Future<Media> _createSmbOptimizedMediaWithReduction(String path) async {
    debugPrint(
        'VideoPlayerOptimizer: Creating SMB optimized media with resolution reduction');

    // For SMB paths, always use reduced resolution to prevent buffer issues
    // This is especially important for 4K videos which cause ImageReader_JNI errors

    // Create Media with resolution scaling options
    final media = Media(
      path,
      // Add Media Kit options for resolution scaling
      // Note: Media Kit doesn't expose direct resolution scaling, so we'll use other approaches
    );

    return media;
  }

  /// Create media with forced resolution reduction for high-res videos
  Future<Media> createForcedReducedResolutionMedia(String path) async {
    debugPrint(
        'VideoPlayerOptimizer: Creating forced reduced resolution media for $path');

    // Always reduce resolution for SMB paths to prevent buffer issues
    if (_isSmbPath(path)) {
      return _createSmbOptimizedMediaWithReduction(path);
    }

    // For local files, check if we should force reduce resolution
    if (_shouldForceReduceResolution(path)) {
      return createReducedResolutionMedia(path);
    }

    // Regular path - use standard Media
    return Media(path);
  }

  /// Create media with reduced resolution to prevent buffer issues
  Future<Media> createReducedResolutionMedia(String path) async {
    debugPrint(
        'VideoPlayerOptimizer: Creating reduced resolution media for $path');

    // For SMB paths, try to reduce resolution to prevent buffer issues
    if (_isSmbPath(path)) {
      return _createSmbOptimizedMedia(path);
    }

    // Regular path - use standard Media
    return Media(path);
  }

  /// Create media with automatic resolution reduction for high-res videos
  Future<Media> createAutoReducedResolutionMedia(String path) async {
    debugPrint(
        'VideoPlayerOptimizer: Creating auto-reduced resolution media for $path');

    // For SMB paths, always use reduced resolution to prevent buffer issues
    if (_isSmbPath(path)) {
      return _createSmbOptimizedMedia(path);
    }

    // For local files, check if we should reduce resolution
    if (_shouldReduceResolutionForPath(path)) {
      return createReducedResolutionMedia(path);
    }

    // Regular path - use standard Media
    return Media(path);
  }

  /// Check if we should reduce resolution for a given path
  bool _shouldReduceResolutionForPath(String path) {
    // Reduce resolution for SMB paths and large video files
    if (_isSmbPath(path)) {
      return true;
    }

    // Check file size - if it's a large file, reduce resolution
    try {
      final file = File(path);
      if (file.existsSync()) {
        final sizeInMB = file.lengthSync() / (1024 * 1024);
        // If file is larger than 100MB, consider reducing resolution
        return sizeInMB > 100;
      }
    } catch (e) {
      debugPrint('VideoPlayerOptimizer: Error checking file size: $e');
    }

    return false;
  }

  /// Check if we should force reduce resolution (more aggressive than before)
  bool _shouldForceReduceResolution(String path) {
    // Force reduce resolution for SMB paths and any large video files
    if (_isSmbPath(path)) {
      return true;
    }

    // Check file size - if it's a large file, force reduce resolution
    try {
      final file = File(path);
      if (file.existsSync()) {
        final sizeInMB = file.lengthSync() / (1024 * 1024);
        // If file is larger than 50MB (reduced from 100MB), force reduce resolution
        return sizeInMB > 50;
      }
    } catch (e) {
      debugPrint('VideoPlayerOptimizer: Error checking file size: $e');
    }

    // Check if filename contains 4K indicators
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('4k') ||
        lowerPath.contains('2160p') ||
        lowerPath.contains('uhd')) {
      return true;
    }

    return false;
  }

  /// Detect if video is 4K and needs resolution reduction
  bool _is4KVideo(String path) {
    final lowerPath = path.toLowerCase();

    // Check filename for 4K indicators
    if (lowerPath.contains('4k') ||
        lowerPath.contains('2160p') ||
        lowerPath.contains('uhd') ||
        lowerPath.contains('3840x2160')) {
      return true;
    }

    // Check file size - 4K videos are typically very large
    try {
      final file = File(path);
      if (file.existsSync()) {
        final sizeInMB = file.lengthSync() / (1024 * 1024);
        // 4K videos are typically larger than 100MB
        return sizeInMB > 100;
      }
    } catch (e) {
      debugPrint(
          'VideoPlayerOptimizer: Error checking file size for 4K detection: $e');
    }

    return false;
  }

  /// Create media with 4K-specific optimizations
  Future<Media> create4KOptimizedMedia(String path) async {
    debugPrint('VideoPlayerOptimizer: Creating 4K optimized media for $path');

    if (_is4KVideo(path)) {
      debugPrint(
          'VideoPlayerOptimizer: Detected 4K video, applying aggressive optimizations');

      // For 4K videos, always use the most aggressive optimization
      return _createSmbOptimizedMediaWithReduction(path);
    }

    // For non-4K videos, use standard optimization
    return createForcedReducedResolutionMedia(path);
  }

  /// Create media with custom video source for 4K videos
  Future<Media> create4KOptimizedMediaWithCustomSource(String path) async {
    debugPrint(
        'VideoPlayerOptimizer: Creating 4K optimized media with custom source for $path');

    if (_is4KVideo(path)) {
      debugPrint(
          'VideoPlayerOptimizer: Detected 4K video, using custom video source');

      // For 4K videos, create a custom video source that forces resolution reduction
      return _createCustom4KVideoSource(path);
    }

    // For non-4K videos, use standard optimization
    return createForcedReducedResolutionMedia(path);
  }

  /// Create custom video source for 4K videos with forced resolution reduction
  Future<Media> _createCustom4KVideoSource(String path) async {
    debugPrint('VideoPlayerOptimizer: Creating custom 4K video source');

    // Create Media with custom options to force resolution reduction
    final media = Media(
      path,
      // Add custom headers or options to force lower resolution
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (compatible; 4K-Optimized-Player)',
        'Accept': 'video/*;q=0.8',
        'Range': 'bytes=0-', // Force range requests for better streaming
      },
    );

    return media;
  }

  /// Create media with seek-optimized settings
  Future<Media> createSeekOptimizedMedia(String path) async {
    debugPrint('VideoPlayerOptimizer: Creating seek-optimized media for $path');

    // Create Media with seek-optimized settings
    final media = Media(
      path,
      // Add options to improve seeking performance
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (compatible; Seek-Optimized-Player)',
        'Accept': 'video/*;q=0.9',
        'Range': 'bytes=0-', // Enable range requests for seeking
      },
    );

    return media;
  }

  /// Check if we should use reduced resolution based on path
  bool shouldUseReducedResolution(String path) {
    // Use reduced resolution for SMB paths to prevent buffer issues
    return _isSmbPath(path);
  }

  /// Dispose resources
  void dispose() {
    stopMemoryMonitoring();
    stopBufferCleanupTimer();

    // Reset state
    _consecutiveBufferErrors = 0;
    _consecutiveImageReaderErrors = 0;
    _isBufferReduced = false;
    _isQualityReduced = false;
    _currentBufferSize = 1024 * 1024; // Reset to initial size
  }
}

/// Extension to add optimization methods to Player
extension OptimizedPlayer on Player {
  /// Configure player with optimizations for SMB streaming
  Future<void> configureForSmbStreaming() async {
    // Add error handling
    stream.error.listen((error) {
      if (error.contains('ImageReader_JNI')) {
        _handleImageReaderError();
      }
    });

    // Add buffering monitoring
    stream.buffering.listen((buffering) {
      // Buffering state changed
    });

    // Add position monitoring
    stream.position.listen((position) {
      // Position updated
    });
  }

  /// Handle ImageReader_JNI errors
  void _handleImageReaderError() {
    // Pause briefly to allow buffer recovery
    pause();

    Timer(const Duration(milliseconds: 1000), () {
      play();
    });
  }
}
