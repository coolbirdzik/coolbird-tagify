import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// A Flutter plugin to access Windows native video thumbnail generation
/// This uses the Windows thumbnail cache system for efficient thumbnail extraction
class FcNativeVideoThumbnail {
  static const MethodChannel _channel =
      MethodChannel('fc_native_video_thumbnail');

  /// Flag to indicate if this is running on Windows
  static bool get isWindows => Platform.isWindows;

  /// Flag to track initialization status
  static bool _initialized = false;

  /// Prevents multiple concurrent native operations
  static bool _operationInProgress = false;

  /// Semaphore to control access to native operations
  static final _operationSemaphore = Completer<void>()..complete();

  /// Maximum time to wait for a native operation
  static const Duration _operationTimeout = Duration(seconds: 5);

  /// Initialize the plugin
  /// This is automatically called by [generateThumbnail]
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      if (!isWindows) {
        debugPrint(
            'FcNativeVideoThumbnail: Not running on Windows, initialization skipped');
        return false;
      }

      // Nothing to initialize for now, but we could add version checking or capability testing here
      _initialized = true;
      debugPrint(
          'FcNativeVideoThumbnail: Native Windows thumbnail provider initialized');
      return true;
    } catch (e) {
      debugPrint('FcNativeVideoThumbnail: Failed to initialize: $e');
      return false;
    }
  }

  /// Generate a thumbnail for a video file using Windows native APIs
  ///
  /// - [videoPath]: Path to the video file
  /// - [outputPath]: Where to save the thumbnail (must be a valid path)
  /// - [width]: Width of the thumbnail (also used for height to maintain aspect ratio)
  /// - [format]: Image format, either 'png' or 'jpg'
  /// - [timeSeconds]: Position in the video (in seconds) to extract the thumbnail from (optional)
  ///
  /// Returns the path to the generated thumbnail if successful, null otherwise
  static Future<String?> generateThumbnail({
    required String videoPath,
    required String outputPath,
    int width = 200,
    String format = 'jpg',
    int? timeSeconds,
  }) async {
    if (!isWindows) {
      debugPrint(
          'FcNativeVideoThumbnail: Not running on Windows, cannot generate native thumbnail');
      return null;
    }

    // Ensure the plugin is initialized
    if (!_initialized) {
      final initResult = await initialize();
      if (!initResult) return null;
    }

    // Validate paths (async)
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      // Use async exists()
      debugPrint(
          'FcNativeVideoThumbnail: Video file does not exist: $videoPath');
      return null;
    }

    // Create parent directory if it doesn't exist
    final directory = path.dirname(outputPath);
    await Directory(directory).create(recursive: true);

    // Check if another operation is already in progress
    if (_operationInProgress) {
      debugPrint(
          'FcNativeVideoThumbnail: Another operation in progress, waiting...');
      // Create a new semaphore if the current one is completed
      if (_operationSemaphore.isCompleted) {
        var oldSemaphore = _operationSemaphore;
        await oldSemaphore.future;
      } else {
        // Wait for the current operation to complete
        try {
          await _operationSemaphore.future.timeout(_operationTimeout);
        } catch (e) {
          debugPrint(
              'FcNativeVideoThumbnail: Timed out waiting for previous operation');
          return null;
        }
      }
    }

    // Create a new semaphore for the current operation
    var currentSemaphore = Completer<void>();

    try {
      _operationInProgress = true;

      // Call the native method with a timeout
      final result = await _channel.invokeMethod<bool>('getVideoThumbnail', {
        'srcFile': videoPath,
        'destFile': outputPath,
        'width': width,
        'format': format.toLowerCase() == 'png' ? 'png' : 'jpg',
        'timeSeconds': timeSeconds, // Pass the timestamp to native code
      }).timeout(_operationTimeout, onTimeout: () {
        debugPrint(
            'FcNativeVideoThumbnail: Native operation timed out for $videoPath');
        return false;
      });

      if (result == true) {
        // Verify the thumbnail was created (async)
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          // Use async exists() and length()
          debugPrint(
              'FcNativeVideoThumbnail: Successfully generated thumbnail at $outputPath');
          return outputPath;
        } else {
          debugPrint(
              'FcNativeVideoThumbnail: File reported as created but doesn\'t exist or is empty at $outputPath');
          // Attempt to delete potentially corrupt file
          try {
            if (await outputFile.exists()) await outputFile.delete();
          } catch (_) {}
          return null;
        }
      } else {
        // Failed extraction but not an error - common with some video files
        debugPrint(
            'FcNativeVideoThumbnail: Could not extract thumbnail from video $videoPath (native call returned false)');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint(
          'FcNativeVideoThumbnail: Platform error for $videoPath: ${e.message}');
      return null;
    } catch (e) {
      debugPrint(
          'FcNativeVideoThumbnail: Error generating thumbnail for $videoPath: $e');
      return null;
    } finally {
      _operationInProgress = false;
      currentSemaphore.complete();
    }
  }

  /// Check if a video format is supported by the Windows thumbnail extractor
  /// This is a conservative list of formats known to work well with Windows thumbnail cache
  static bool isSupportedFormat(String videoPath) {
    if (!isWindows) return false;

    final extension = path.extension(videoPath).toLowerCase();
    // Windows thumbnail cache supports most common video formats
    final supportedExtensions = [
      '.mp4',
      '.mov',
      '.wmv',
      '.avi',
      '.mkv',
      '.mpg',
      '.mpeg',
      '.m4v',
      '.ts'
    ];

    return supportedExtensions.contains(extension);
  }
}
