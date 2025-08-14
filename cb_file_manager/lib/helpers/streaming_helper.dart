import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

import '../services/network_browsing/network_service_base.dart';
import '../services/network_browsing/mobile_smb_service.dart';
import '../services/network_browsing/i_smb_service.dart';
import '../ui/components/video_player/video_player.dart';
import '../ui/utils/file_type_utils.dart';
import 'package:path/path.dart' as p;
import 'file_type_helper.dart';
import 'network_file_cache_service.dart';
import 'vlc_direct_smb_helper.dart';
// import '../helpers/libsmb2_streaming_helper.dart';
import 'native_vlc_direct_helper.dart';

/// Class để lưu trữ kết quả mở file
class FileOpenResult {
  final bool success;
  final String? errorMessage;
  final String? message;
  final Stream<List<int>>? fileStream;
  final String? streamingUrl;

  final String? localPath;
  final FileType? fileType;
  final bool requiresUserChoice;
  final bool viewerLaunched;

  FileOpenResult({
    required this.success,
    this.errorMessage,
    this.message,
    this.fileStream,
    this.streamingUrl,
    this.localPath,
    this.fileType,
    this.requiresUserChoice = false,
    this.viewerLaunched = false,
  });
}

/// Helper class để xử lý streaming files từ network services
class StreamingHelper {
  static StreamingHelper? _instance;
  static StreamingHelper get instance {
    _instance ??= StreamingHelper._();
    return _instance!;
  }

  StreamingHelper._();

  NetworkServiceBase? _currentNetworkService;

  /// Khởi tạo streaming cho network service
  Future<bool> initializeStreaming(NetworkServiceBase networkService) async {
    try {
      _currentNetworkService = networkService;
      debugPrint('Streaming initialized for ${networkService.serviceName}');
      return true;
    } catch (e) {
      debugPrint('Error initializing streaming: $e');
      return false;
    }
  }

  /// Dừng streaming
  Future<void> stopStreaming() async {
    _currentNetworkService = null;
    debugPrint('Streaming stopped');
  }

  /// Mở file với streaming
  Future<void> openFileWithStreaming(
    BuildContext context,
    String remotePath,
    String fileName,
  ) async {
    try {
      // Hiển thị loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _openFileDirectly(context, remotePath, fileName);

      // Đóng loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        await _handleSuccessfulOpen(context, result, fileName, remotePath);
      } else {
        await _handleOpenError(context, result.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      // Đóng loading dialog nếu còn mở
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      await _handleOpenError(context, 'Error opening file: $e');
    }
  }

  /// Optimized streaming with caching support - Phase 1 improvements
  Future<FileOpenResult> _openFileDirectly(
    BuildContext context,
    String remotePath,
    String fileName,
  ) async {
    final startTime = DateTime.now();
    debugPrint('=== StreamingHelper._openFileDirectly START (Optimized) ===');
    debugPrint('StreamingHelper: remotePath: $remotePath');
    debugPrint('StreamingHelper: timestamp: ${startTime.toIso8601String()}');

    if (_currentNetworkService == null) {
      debugPrint('StreamingHelper: ERROR - Network service not initialized');
      return FileOpenResult(
        success: false,
        errorMessage: 'Network service not initialized',
      );
    }

    final service = _currentNetworkService!;
    debugPrint('StreamingHelper: Service type: ${service.runtimeType}');
    debugPrint('StreamingHelper: Service connected: ${service.isConnected}');

    try {
      final fileExtension = p.extension(remotePath).toLowerCase();
      final fileType = _getFileType(fileExtension);
      debugPrint('StreamingHelper: File extension: $fileExtension');
      debugPrint('StreamingHelper: File type: $fileType');

      // Priority 1: Attempt Native VLC Direct streaming (highest priority)
      debugPrint(
          'StreamingHelper: Checking for Native VLC Direct streaming...');
      debugPrint(
          'StreamingHelper: NativeVlcDirectHelper.canStreamDirectly($fileType): ${NativeVlcDirectHelper.canStreamDirectly(fileType)}');
      if (service is ISmbService &&
          NativeVlcDirectHelper.canStreamDirectly(fileType)) {
        try {
          final canUseNative =
              await NativeVlcDirectHelper.canUseNativeVlcDirect(
            fileType: fileType,
            smbService: service,
          );

          if (canUseNative) {
            debugPrint(
                'StreamingHelper: ✅ Attempting Native VLC Direct streaming');
            await NativeVlcDirectHelper.openMediaWithNativeVlcDirect(
              context: context,
              smbPath: remotePath,
              fileName: fileName,
              fileType: fileType,
              smbService: service,
            );
            return FileOpenResult(success: true, viewerLaunched: true);
          } else {
            debugPrint(
                'StreamingHelper: ❌ Native VLC Direct not available, trying LibSMB2');
          }
        } catch (e) {
          debugPrint(
              'StreamingHelper: ❌ Native VLC Direct streaming failed: $e. Trying LibSMB2 fallback.');
        }
      }

      // LibSMB2 streaming removed - now using flutter_vlc_player for SMB direct streaming

      // Priority 3: Fallback to VLC Direct SMB streaming for other SMB services
      debugPrint('StreamingHelper: Checking for VLC Direct SMB fallback...');
      debugPrint(
          'StreamingHelper: VlcDirectSmbHelper.canStreamDirectly($fileType): ${VlcDirectSmbHelper.canStreamDirectly(fileType)}');
      if (service is ISmbService &&
          VlcDirectSmbHelper.canStreamDirectly(fileType)) {
        try {
          debugPrint(
              'StreamingHelper: ✅ Attempting VLC Direct SMB streaming (fallback)');
          await VlcDirectSmbHelper.openMediaWithVlcDirectSmb(
            context: context,
            smbPath: remotePath,
            fileName: fileName,
            fileType: fileType,
            smbService: service,
          );
          // If VLC player is launched, we return a success result indicating this
          return FileOpenResult(success: true, viewerLaunched: true);
        } catch (e) {
          debugPrint(
              'StreamingHelper: ❌ VLC Direct SMB failed: $e. Proceeding to other fallbacks.');
          // If it fails, we just log it and continue with other methods
        }
      }

      // Check if file is already cached
      final cacheService = NetworkFileCacheService();
      final cachedFile = await cacheService.getCachedFile(remotePath);

      if (cachedFile != null && await cachedFile.exists()) {
        debugPrint('StreamingHelper: Found cached file, using cached version');
        final cachedStream = cachedFile.openRead();
        return FileOpenResult(
          success: true,
          fileStream: cachedStream,
          fileType: fileType,
          message:
              'File loaded from cache (${(await cachedFile.length() / 1024).toStringAsFixed(1)} KB)',
        );
      }

      // Priority 4: Try openFileStream for other cases
      debugPrint(
          'StreamingHelper: DECISION - Using openFileStream method (optimized)');
      debugPrint('StreamingHelper: Calling service.openFileStream...');

      final streamStartTime = DateTime.now();
      final sourceStream = service.openFileStream(remotePath);

      if (sourceStream != null) {
        debugPrint('StreamingHelper: openFileStream SUCCESS');
        debugPrint(
            'StreamingHelper: Stream creation time: ${DateTime.now().difference(streamStartTime).inMilliseconds}ms');

        // For media files (video/audio), use caching to improve performance
        if (fileType == FileType.video || fileType == FileType.audio) {
          debugPrint('StreamingHelper: Applying caching for media file');

          // Create a controller for the cached stream
          final controller = StreamController<List<int>>();

          // Use NetworkFileCacheService to buffer and forward the stream
          cacheService.bufferStreamAndForward(
              remotePath, sourceStream, controller);

          return FileOpenResult(
            success: true,
            fileStream: controller.stream,
            fileType: fileType,
            message: 'Media file streaming with smart caching enabled',
          );
        } else {
          // For non-media files, stream directly without caching
          return FileOpenResult(
            success: true,
            fileStream: sourceStream,
            fileType: fileType,
            message: 'File streaming directly (no caching for non-media)',
          );
        }
      }

      // Fallback: Try readFileData only for small non-media files
      if (service is MobileSMBService &&
          (fileType != FileType.video && fileType != FileType.audio)) {
        debugPrint(
            'StreamingHelper: openFileStream failed, trying readFileData fallback for non-media file');

        // Get file size for small file check
        int? fileSize;
        try {
          fileSize = await service.getFileSize(remotePath);
          debugPrint('StreamingHelper: File size: $fileSize bytes');
        } catch (e) {
          debugPrint('StreamingHelper: Could not get file size: $e');
        }

        // Only use readFileData for small files (< 10MB)
        const int smallFileThreshold = 10 * 1024 * 1024; // 10MB
        if (fileSize != null && fileSize <= smallFileThreshold) {
          debugPrint(
              'StreamingHelper: Using readFileData for small non-media file');
          try {
            final fileData = await service.readFileData(remotePath);
            if (fileData != null && fileData.isNotEmpty) {
              final fileStream = Stream.value(fileData);
              return FileOpenResult(
                success: true,
                fileStream: fileStream,
                fileType: fileType,
                message:
                    'Small file loaded via readFileData (${(fileData.length / 1024).toStringAsFixed(1)} KB)',
              );
            }
          } catch (e) {
            debugPrint('StreamingHelper: readFileData fallback failed: $e');
          }
        } else {
          debugPrint(
              'StreamingHelper: File too large for readFileData fallback (${fileSize != null ? (fileSize / 1024 / 1024).toStringAsFixed(1) : "unknown"} MB)');
        }
      }

      // All methods failed
      debugPrint('StreamingHelper: ERROR - All streaming methods failed');
      debugPrint('StreamingHelper: Service type: ${service.runtimeType}');
      debugPrint('StreamingHelper: Service connected: ${service.isConnected}');

      return FileOpenResult(
        success: false,
        errorMessage:
            'Không thể tạo stream cho file này. Vui lòng kiểm tra kết nối mạng và thử lại.',
        fileType: fileType,
      );
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('StreamingHelper: CRITICAL ERROR in _openFileDirectly');
      debugPrint('StreamingHelper: Error: $e');
      debugPrint('StreamingHelper: Duration: ${duration.inMilliseconds}ms');
      debugPrint('StreamingHelper: Stack trace: $stackTrace');

      return FileOpenResult(
        success: false,
        errorMessage: 'Lỗi không mong muốn khi mở file: $e',
      );
    } finally {
      final totalDuration = DateTime.now().difference(startTime);
      debugPrint(
          'StreamingHelper: Total execution time: ${totalDuration.inMilliseconds}ms');
      debugPrint('=== StreamingHelper._openFileDirectly END (Optimized) ===');
    }
  }

  /// Xác định loại file dựa trên extension
  FileType _getFileType(String extension) {
    return FileTypeHelper.getFileType(extension);
  }

  /// Xử lý khi mở file thành công
  Future<void> _handleSuccessfulOpen(
    BuildContext context,
    FileOpenResult result,
    String fileName,
    String remotePath,
  ) async {
    if (!context.mounted) return;

    // Kiểm tra nếu kết quả không thành công
    if (!result.success) {
      await _handleOpenError(
        context,
        result.errorMessage ?? 'Failed to open file',
      );
      return;
    }

    // If an external viewer was launched (e.g., VLC), we don't need to do anything else.
    if (result.viewerLaunched) {
      debugPrint(
          "StreamingHelper: Viewer already launched, skipping internal player.");
      return;
    }

    if (result.requiresUserChoice) {
      // Hiển thị dialog cho người dùng chọn
      await _showFileOptionsDialog(context, result, fileName);
      return;
    }

    if (result.fileStream != null || result.streamingUrl != null) {
      // Mở media player hoặc image viewer với stream, URL hoặc SMB MRL
      await _openStreamingViewer(context, result, fileName, remotePath);
    } else if (result.localPath != null) {
      // File đã được tải về và mở
      _showSuccessMessage(
        context,
        result.message ?? 'File opened successfully',
      );
    } else {
      // Không có dữ liệu để mở file
      await _handleOpenError(context, 'No data available to open this file');
    }
  }

  /// Mở streaming viewer dựa trên loại file
  Future<void> _openStreamingViewer(
    BuildContext context,
    FileOpenResult result,
    String fileName,
    String remotePath,
  ) async {
    if (!context.mounted) return;

    // Kiểm tra xem có dữ liệu để stream không
    if (result.fileStream == null && result.streamingUrl == null) {
      await _handleOpenError(
        context,
        'No streaming data available for this file',
      );
      return;
    }

    if (result.fileType == FileType.image) {
      // Mở image viewer
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => result.fileStream != null
              ? StreamingImageViewer.fromStream(
                  fileStream: result.fileStream!,
                  fileName: fileName,
                )
              : result.streamingUrl != null
                  ? StreamingImageViewer.fromUrl(
                      streamingUrl: result.streamingUrl!,
                      fileName: fileName,
                    )
                  : throw Exception(
                      'Neither fileStream nor streamingUrl available',
                    ),
        ),
      );
    } else if (result.fileType == FileType.video ||
        result.fileType == FileType.audio) {
      // Debug thông tin trước khi kiểm tra VLC Direct SMB
      debugPrint('StreamingHelper: Processing video/audio file');
      debugPrint(
          'StreamingHelper: _currentNetworkService type: ${_currentNetworkService.runtimeType}');

      debugPrint('StreamingHelper: File type: ${result.fileType}');
      debugPrint(
          'StreamingHelper: Can stream directly: ${VlcDirectSmbHelper.canStreamDirectly(result.fileType!)}');

      // LibSMB2 streaming removed - now using flutter_vlc_player for SMB

      // Fallback: VLC Direct SMB streaming
      if (_currentNetworkService is ISmbService &&
          VlcDirectSmbHelper.canStreamDirectly(result.fileType!)) {
        try {
          debugPrint(
              'StreamingHelper: ✅ Attempting VLC Direct SMB streaming (fallback)');
          debugPrint('StreamingHelper: Using remotePath: $remotePath');
          await VlcDirectSmbHelper.openMediaWithVlcDirectSmb(
            context: context,
            smbPath: remotePath,
            fileName: fileName,
            fileType: result.fileType!,
            smbService: _currentNetworkService as ISmbService,
          );
          return;
        } catch (e) {
          debugPrint('StreamingHelper: ❌ VLC Direct SMB failed: $e');
          // Tiếp tục với fallback khác
        }
      } else {
        debugPrint(
            'StreamingHelper: ❌ Direct streaming conditions not met, using other fallbacks');
      }

      // Fallback: Mở media player với các phương thức khác
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => result.fileStream != null
              ? VideoPlayer.stream(
                  fileStream: result.fileStream!,
                  fileName: fileName,
                  fileType: result.fileType!,
                )
              : result.streamingUrl != null
                  ? VideoPlayer.url(
                      streamingUrl: result.streamingUrl!,
                      fileName: fileName,
                      fileType: result.fileType!,
                    )
                  : throw Exception(
                      'No streaming data available',
                    ),
        ),
      );
    }
  }

  /// Hiển thị dialog tùy chọn cho file không được hỗ trợ trực tiếp
  Future<void> _showFileOptionsDialog(
    BuildContext context,
    FileOpenResult result,
    String fileName,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open File: $fileName'),
        content: const Text(
          'This file type is not directly supported for streaming. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _downloadAndOpen(context, fileName);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  /// Tải file về
  Future<void> _downloadAndOpen(BuildContext context, String remotePath) async {
    if (_currentNetworkService == null) {
      await _handleOpenError(context, 'Network service not available');
      return;
    }

    try {
      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Downloading file...'),
            ],
          ),
        ),
      );

      // Tạo file tạm thời
      final fileName = p.basename(remotePath);
      final tempDir = Directory.systemTemp;
      final localPath = p.join(tempDir.path, 'smb_files', fileName);

      // Tạo thư mục nếu chưa tồn tại
      final localDir = Directory(p.dirname(localPath));
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      // Tải file từ network service
      await _currentNetworkService!.getFile(remotePath, localPath);

      if (context.mounted) {
        Navigator.of(context).pop(); // Đóng loading
      }

      _showSuccessMessage(context, 'File downloaded successfully');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Đóng loading
      }
      await _handleOpenError(context, 'Error downloading file: $e');
    }
  }

  /// Xử lý lỗi khi mở file
  Future<void> _handleOpenError(
    BuildContext context,
    String errorMessage,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Hiển thị thông báo thành công
  void _showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Kiểm tra xem file có thể streaming không
  bool canStreamFile(String filePath) {
    return FileTypeUtils.isImageFile(filePath) ||
        FileTypeUtils.isVideoFile(filePath) ||
        FileTypeUtils.isAudioFile(filePath);
  }

  /// Lấy icon phù hợp cho loại file
  IconData getFileIcon(String filePath) {
    if (FileTypeUtils.isVideoFile(filePath)) {
      return Icons.video_file;
    } else if (FileTypeUtils.isAudioFile(filePath)) {
      return Icons.audio_file;
    } else if (FileTypeUtils.isImageFile(filePath)) {
      return Icons.image;
    } else if (FileTypeUtils.isDocumentFile(filePath) ||
        FileTypeUtils.isSpreadsheetFile(filePath) ||
        FileTypeUtils.isPresentationFile(filePath)) {
      return Icons.description;
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// Kiểm tra trạng thái streaming
  bool get isStreamingActive => _currentNetworkService != null;

  /// Lấy network service hiện tại
  NetworkServiceBase? get currentNetworkService => _currentNetworkService;

  /// Kiểm tra xem có thể streaming file không
  bool canStreamFileWithService(String filePath) {
    return _currentNetworkService != null && canStreamFile(filePath);
  }
}
