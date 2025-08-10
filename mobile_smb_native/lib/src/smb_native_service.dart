import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'smb_native_ffi.dart';
import 'smb_file.dart';
import 'smb_connection_config.dart';

class SmbNativeService {
  static SmbNativeService? _instance;
  static SmbNativeService get instance => _instance ??= SmbNativeService._();

  late SmbNativeFFI _ffi;
  Pointer<Void>? _context;
  bool _isConnected = false;

  SmbNativeService._() {
    try {
      _ffi = SmbNativeFFI();
    } catch (e) {
      debugPrint('Failed to initialize SMB FFI: $e');
      debugPrint('SMB functionality will be limited on this platform');
      rethrow;
    }
  }

  /// Connect to SMB server
  Future<bool> connect(SmbConnectionConfig config) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _context = _ffi.connect(
        config.host,
        config.shareName ?? '',
        config.username,
        config.password,
      );

      _isConnected = _context != null;
      return _isConnected;
    } catch (e) {
      debugPrint('SMB connection error: $e');
      return false;
    }
  }

  /// Disconnect from SMB server
  Future<void> disconnect() async {
    if (_context != null) {
      _ffi.disconnect(_context!);
      _context = null;
    }
    _isConnected = false;
  }

  /// Check if connected to SMB server
  bool get isConnected {
    if (!_isConnected || _context == null) {
      return false;
    }
    return _ffi.isConnected(_context!);
  }

  /// List files and directories in the specified path
  Future<List<SmbFile>> listDirectory(String path) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    try {
      final files = _ffi.listDirectory(_context!, path);
      return files
          .map((file) => SmbFile(
                name: file['name'] as String,
                path: file['path'] as String,
                size: file['size'] as int,
                lastModified: DateTime.fromMillisecondsSinceEpoch(
                  (file['modifiedTime'] as int) * 1000,
                ),
                isDirectory: file['isDirectory'] as bool,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error listing directory: $e');
      return [];
    }
  }

  /// Stream file content in chunks
  Stream<Uint8List> streamFile(String path,
      {int chunkSize = 2 * 1024 * 1024}) async* {
    // 2MB default chunk size for video streaming
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        throw Exception('Failed to open file: $path');
      }

      final totalSize = _ffi.getFileSize(fileHandle);
      int totalRead = 0;
      final buffer = Uint8List(chunkSize);

      while (true) {
        final bytesRead = _ffi.readChunk(fileHandle, buffer);
        if (bytesRead < 0) {
          // Error from native layer
          break;
        }
        if (bytesRead == 0) {
          // Possibly network stall – retry unless we have reached EOF
          if (totalRead >= totalSize) {
            break; // EOF confirmed
          }
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }
        totalRead += bytesRead;
        yield Uint8List.fromList(buffer.take(bytesRead).toList());
      }
    } catch (e) {
      debugPrint('Error streaming file: $e');
      rethrow;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Stream file content from specific offset (for seek support)
  Stream<Uint8List> seekFileStream(String path, int offset,
      {int chunkSize = 2 * 1024 * 1024}) async* {
    // 2MB default chunk size for video streaming
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        throw Exception('Failed to open file: $path');
      }

      final totalSize = _ffi.getFileSize(fileHandle);
      if (offset < 0 || offset >= totalSize) {
        throw Exception('Invalid offset: $offset, file size: $totalSize');
      }

      // Seek to offset
      final seekSuccess = await seekFile(fileHandle, offset);
      if (!seekSuccess) {
        throw Exception('Failed to seek to offset: $offset');
      }

      int totalRead = offset;
      final buffer = Uint8List(chunkSize);

      while (true) {
        final bytesRead = _ffi.readChunk(fileHandle, buffer);
        if (bytesRead < 0) {
          // Error from native layer
          break;
        }
        if (bytesRead == 0) {
          // Possibly network stall – retry unless we have reached EOF
          if (totalRead >= totalSize) {
            break; // EOF confirmed
          }
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }
        totalRead += bytesRead;
        yield Uint8List.fromList(buffer.take(bytesRead).toList());
      }
    } catch (e) {
      debugPrint('Error seeking file stream: $e');
      rethrow;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Read entire file content
  Future<Uint8List?> readFile(String path) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return null;
      }

      final fileSize = _ffi.getFileSize(fileHandle);
      if (fileSize <= 0) {
        return Uint8List(0);
      }

      final result = Uint8List(fileSize);
      int totalBytesRead = 0;
      const chunkSize =
          1024 * 1024; // 1MB chunks for better compatibility with SMB2

      while (totalBytesRead < fileSize) {
        final remainingBytes = fileSize - totalBytesRead;
        final currentChunkSize =
            remainingBytes < chunkSize ? remainingBytes : chunkSize;
        final buffer = Uint8List(currentChunkSize);

        final bytesRead = _ffi.readChunk(fileHandle, buffer);
        if (bytesRead <= 0) {
          break;
        }

        result.setRange(totalBytesRead, totalBytesRead + bytesRead, buffer);
        totalBytesRead += bytesRead;
      }

      return result;
    } catch (e) {
      debugPrint('Error reading file: $e');
      return null;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Seek to specific position in file
  Future<bool> seekFile(Pointer<Void> fileHandle, int offset) async {
    try {
      final result = _ffi.seekFile(fileHandle, offset);
      return result == 0; // 0 means success
    } catch (e) {
      debugPrint('Error seeking file: $e');
      return false;
    }
  }

  /// Get file size
  Future<int?> getFileSize(String path) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return null;
      }

      return _ffi.getFileSize(fileHandle);
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return null;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Generate thumbnail for image or video file
  Future<Uint8List?> generateThumbnail(
    String path, {
    int width = 200,
    int height = 200,
  }) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    try {
      return _ffi.generateThumbnail(_context!, path, width, height);
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String path) async {
    if (!isConnected) {
      return false;
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      return fileHandle != null;
    } catch (e) {
      return false;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Stream file with progress callback
  Stream<SmbStreamChunk> streamFileWithProgress(
    String path, {
    int chunkSize =
        2 * 1024 * 1024, // 2MB default chunk size for video streaming
    Function(double progress)? onProgress,
  }) async* {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        throw Exception('Failed to open file: $path');
      }

      final totalSize = _ffi.getFileSize(fileHandle);
      int bytesRead = 0;
      final buffer = Uint8List(chunkSize);

      while (true) {
        final currentBytesRead = _ffi.readChunk(fileHandle, buffer);
        if (currentBytesRead < 0) {
          break; // Error
        }
        if (currentBytesRead == 0) {
          if (bytesRead >= totalSize) {
            break; // EOF
          }
          await Future.delayed(const Duration(milliseconds: 10));
          continue; // Retry to allow buffering
        }

        bytesRead += currentBytesRead;
        final progress = totalSize > 0 ? bytesRead / totalSize : 0.0;

        final chunk = SmbStreamChunk(
          data: Uint8List.fromList(buffer.take(currentBytesRead).toList()),
          progress: progress,
          bytesRead: bytesRead,
          totalSize: totalSize,
        );

        onProgress?.call(progress);
        yield chunk;
      }
    } catch (e) {
      debugPrint('Error streaming file with progress: $e');
      rethrow;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Get error message for error code
  String getErrorMessage(int errorCode) {
    return _ffi.getErrorMessage(errorCode);
  }

  /// Read a specific byte range from a file
  ///
  /// [offset] - starting byte position (0-based)
  /// [length] - number of bytes to read
  /// Returns the requested bytes or an empty list if out of range
  Future<Uint8List?> readRange(
    String path, {
    required int offset,
    required int length,
    int chunkSize = 64 * 1024, // 64KB default chunk size for range read
  }) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }
    if (offset < 0 || length <= 0) {
      throw Exception('Invalid offset or length');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return null;
      }

      final fileSize = _ffi.getFileSize(fileHandle);
      if (fileSize <= 0 || offset >= fileSize) {
        return Uint8List(0);
      }

      // Clamp length to remaining bytes in file
      final bytesToRead =
          (offset + length) > fileSize ? (fileSize - offset) : length;

      // Seek to desired offset
      final seekOk = _ffi.seekFile(fileHandle, offset);
      if (!seekOk) {
        throw Exception('Failed to seek to offset $offset for file: $path');
      }

      final result = Uint8List(bytesToRead);
      int totalRead = 0;
      while (totalRead < bytesToRead) {
        final remaining = bytesToRead - totalRead;
        final currentChunkSize = remaining < chunkSize ? remaining : chunkSize;
        final buffer = Uint8List(currentChunkSize);

        final read = _ffi.readChunk(fileHandle, buffer);
        if (read <= 0) {
          break; // EOF or error
        }

        result.setRange(totalRead, totalRead + read, buffer);
        totalRead += read;
      }

      return result.sublist(0, totalRead);
    } catch (e) {
      debugPrint('Error reading range: $e');
      return null;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  // NEW: Enhanced read-range operations for VLC-style streaming
  /// Read a specific byte range using optimized native read-range
  /// This is more efficient than the standard readRange for video streaming
  Future<Uint8List?> readRangeOptimized(
    String path, {
    required int startOffset,
    required int endOffset,
    int bufferSize = 2 * 1024 * 1024, // 2MB buffer for video streaming
  }) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }
    if (startOffset < 0 || endOffset <= startOffset) {
      throw Exception('Invalid range: start=$startOffset, end=$endOffset');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return null;
      }

      final fileSize = _ffi.getFileSize(fileHandle);
      if (fileSize <= 0 || startOffset >= fileSize) {
        return Uint8List(0);
      }

      // Clamp end offset to file size
      final actualEndOffset = endOffset > fileSize ? fileSize : endOffset;
      final bytesToRead = actualEndOffset - startOffset;

      if (bytesToRead <= 0) {
        return Uint8List(0);
      }

      final buffer = Uint8List(bufferSize);
      final bytesRead =
          _ffi.readRange(fileHandle, buffer, startOffset, actualEndOffset);

      if (bytesRead > 0) {
        return buffer.sublist(0, bytesRead);
      }

      return Uint8List(0);
    } catch (e) {
      debugPrint('Error reading optimized range: $e');
      return null;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Read a specific byte range asynchronously (non-blocking)
  Future<Uint8List?> readRangeAsync(
    String path, {
    required int startOffset,
    required int endOffset,
    int bufferSize = 2 * 1024 * 1024,
  }) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server');
    }
    if (startOffset < 0 || endOffset <= startOffset) {
      throw Exception('Invalid range: start=$startOffset, end=$endOffset');
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return null;
      }

      final fileSize = _ffi.getFileSize(fileHandle);
      if (fileSize <= 0 || startOffset >= fileSize) {
        return Uint8List(0);
      }

      final actualEndOffset = endOffset > fileSize ? fileSize : endOffset;
      final bytesToRead = actualEndOffset - startOffset;

      if (bytesToRead <= 0) {
        return Uint8List(0);
      }

      final buffer = Uint8List(bufferSize);
      final bytesRead =
          _ffi.readRangeAsync(fileHandle, buffer, startOffset, actualEndOffset);

      if (bytesRead > 0) {
        return buffer.sublist(0, bytesRead);
      }

      return Uint8List(0);
    } catch (e) {
      debugPrint('Error reading async range: $e');
      return null;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Prefetch a byte range for better streaming performance
  Future<bool> prefetchRange(
    String path, {
    required int startOffset,
    required int endOffset,
  }) async {
    if (!isConnected) {
      return false;
    }
    if (startOffset < 0 || endOffset <= startOffset) {
      return false;
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return false;
      }

      return _ffi.prefetchRange(fileHandle, startOffset, endOffset);
    } catch (e) {
      debugPrint('Error prefetching range: $e');
      return false;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  /// Set streaming options for optimized video playback
  Future<bool> setStreamingOptions(
    String path, {
    int chunkSize = 64 * 1024, // 64KB chunks
    int bufferSize = 2 * 1024 * 1024, // 2MB buffer
    bool enableCaching = true,
  }) async {
    if (!isConnected) {
      return false;
    }

    Pointer<Void>? fileHandle;
    try {
      fileHandle = _ffi.openFile(_context!, path);
      if (fileHandle == null) {
        return false;
      }

      return _ffi.setStreamingOptions(
          fileHandle, chunkSize, bufferSize, enableCaching);
    } catch (e) {
      debugPrint('Error setting streaming options: $e');
      return false;
    } finally {
      if (fileHandle != null) {
        _ffi.closeFile(fileHandle);
      }
    }
  }

  // NEW: SMB URL generation for direct VLC streaming
  /// Generate a direct SMB URL for VLC streaming
  /// Format: smb://server/share/path
  String? generateDirectUrl(String path) {
    if (!isConnected || _context == null) {
      return null;
    }

    try {
      return _ffi.generateDirectUrl(_context!, path);
    } catch (e) {
      debugPrint('Error generating direct URL: $e');
      return null;
    }
  }

  /// Generate SMB URL with embedded credentials for VLC streaming
  /// Format: smb://username:password@server/share/path
  String? generateUrlWithCredentials(
      String path, String username, String password) {
    if (!isConnected || _context == null) {
      return null;
    }

    try {
      return _ffi.generateUrlWithCredentials(
          _context!, path, username, password);
    } catch (e) {
      debugPrint('Error generating URL with credentials: $e');
      return null;
    }
  }

  /// Get the base connection URL
  /// Format: smb://server/share
  String? getConnectionUrl() {
    if (!isConnected || _context == null) {
      return null;
    }

    try {
      return _ffi.getConnectionUrl(_context!);
    } catch (e) {
      debugPrint('Error getting connection URL: $e');
      return null;
    }
  }

  /// Generate VLC-compatible SMB URL for direct streaming
  /// This is the main method for creating URLs that can be passed to flutter_vlc_player
  String? generateVlcUrl(String path, {String? username, String? password}) {
    debugPrint('SmbNativeService: generateVlcUrl called with path: $path');
    debugPrint(
        'SmbNativeService: generateVlcUrl credentials - Username: $username, Password: ${password != null ? '***' : 'null'}');

    if (!isConnected || _context == null) {
      debugPrint('SmbNativeService: Not connected or context is null');
      return null;
    }

    try {
      // Try to use native FFI functions first
      if (username != null && password != null) {
        final url = _ffi.generateUrlWithCredentials(
            _context!, path, username, password);
        if (url != null) {
          debugPrint('SmbNativeService: Generated URL with credentials: $url');
          return url;
        }
      } else {
        final url = _ffi.generateDirectUrl(_context!, path);
        if (url != null) {
          debugPrint('SmbNativeService: Generated direct URL: $url');
          return url;
        }
      }

      // Fallback: manually construct SMB URL if FFI functions fail
      debugPrint(
          'SmbNativeService: FFI functions failed, using fallback URL generation');

      // Try to get connection info from the path
      final connectionInfo = _extractConnectionInfoFromPath(path);
      if (connectionInfo != null) {
        final share = connectionInfo['share'];
        final host = connectionInfo['host'];

        if (share != null && host != null) {
          // Extract the actual file path from the full path
          String filePath;
          if (path.startsWith('#network/SMB/')) {
            // Remove '#network/SMB/host/share/' prefix to get the file path
            final pathWithoutPrefix =
                path.substring(13); // Remove '#network/SMB/'
            final parts = pathWithoutPrefix.split('/');
            if (parts.length > 2) {
              // Skip host and share, get the rest as file path
              filePath = parts.skip(2).join('/');
            } else {
              filePath = '';
            }
          } else if (path.startsWith('smb://')) {
            // Remove 'smb://host/share/' prefix to get the file path
            final pathWithoutScheme = path.substring(6); // Remove 'smb://'
            final parts = pathWithoutScheme.split('/');
            if (parts.length > 2) {
              // Skip host and share, get the rest as file path
              filePath = parts.skip(2).join('/');
            } else {
              filePath = '';
            }
          } else {
            filePath = path;
          }

          // Normalize and encode path segments to avoid double-encoding
          final pathSegments = filePath
              .split('/')
              .where((s) => s.isNotEmpty)
              .map((seg) => Uri.encodeComponent(Uri.decodeComponent(seg)))
              .toList();
          final encodedFilePath = pathSegments.join('/');
          final encodedShare = Uri.encodeComponent(Uri.decodeComponent(share));

          if (username != null &&
              password != null &&
              username.isNotEmpty &&
              username != 'guest') {
            final encodedUser = Uri.encodeComponent(username);
            final encodedPass = Uri.encodeComponent(password);
            final fallbackUrl =
                'smb://$encodedUser:$encodedPass@$host/$encodedShare/$encodedFilePath';
            debugPrint(
                'SmbNativeService: Generated fallback URL with credentials: $fallbackUrl');
            return fallbackUrl;
          } else {
            final fallbackUrl = 'smb://$host/$encodedShare/$encodedFilePath';
            debugPrint(
                'SmbNativeService: Generated fallback URL without credentials: $fallbackUrl');
            return fallbackUrl;
          }
        } else {
          debugPrint(
              'SmbNativeService: Missing host or share in connection info');
        }
      }

      debugPrint('SmbNativeService: Could not generate SMB URL for VLC');
      return null;
    } catch (e) {
      debugPrint('Error generating VLC URL: $e');
      return null;
    }
  }

  /// Extract connection info from SMB path
  Map<String, String>? _extractConnectionInfoFromPath(String smbPath) {
    try {
      // Handle smb:// URLs
      if (smbPath.startsWith('smb://')) {
        final pathWithoutScheme = smbPath.substring(6); // Remove 'smb://'
        final parts = pathWithoutScheme.split('/');

        if (parts.length >= 2) {
          final host = parts[0];
          final share = parts[1];

          debugPrint(
              'SmbNativeService: Extracted from smb:// - Host: $host, Share: $share');

          return {
            'host': host,
            'share': share,
          };
        }
      }

      // Handle #network/SMB/host/path format
      if (smbPath.startsWith('#network/SMB/')) {
        final pathWithoutPrefix =
            smbPath.substring(13); // Remove '#network/SMB/'
        final parts = pathWithoutPrefix.split('/');

        if (parts.length >= 2) {
          final host = parts[0];
          final share = parts[1];

          debugPrint(
              'SmbNativeService: Extracted from #network/SMB/ - Host: $host, Share: $share');

          return {
            'host': host,
            'share': share,
          };
        }
      }

      debugPrint('SmbNativeService: Could not parse SMB path: $smbPath');
      return null;
    } catch (e) {
      debugPrint('SmbNativeService: Error extracting connection info: $e');
      return null;
    }
  }
}

/// Represents a chunk of streamed file data with progress information
class SmbStreamChunk {
  final Uint8List data;
  final double progress;
  final int bytesRead;
  final int totalSize;

  const SmbStreamChunk({
    required this.data,
    required this.progress,
    required this.bytesRead,
    required this.totalSize,
  });

  @override
  String toString() {
    return 'SmbStreamChunk(dataSize: ${data.length}, progress: ${(progress * 100).toStringAsFixed(1)}%, bytesRead: $bytesRead, totalSize: $totalSize)';
  }
}
