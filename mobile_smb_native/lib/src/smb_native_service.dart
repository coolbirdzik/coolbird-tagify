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
