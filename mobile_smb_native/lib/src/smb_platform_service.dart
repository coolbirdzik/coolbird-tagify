import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'smb_native_service.dart';
import 'smb_file.dart';
import 'smb_connection_config.dart';

/// Platform-aware SMB service that handles different implementations
/// based on the current platform
class SmbPlatformService {
  static SmbPlatformService? _instance;
  static SmbPlatformService get instance =>
      _instance ??= SmbPlatformService._();

  SmbNativeService? _nativeService;
  bool _isNativeAvailable = false;

  SmbPlatformService._() {
    _initializeNativeService();
  }

  void _initializeNativeService() {
    try {
      _nativeService = SmbNativeService.instance;
      _isNativeAvailable = true;
      debugPrint('SMB native service initialized successfully');
    } catch (e) {
      _isNativeAvailable = false;
      debugPrint('SMB native service not available: $e');

      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('Mobile platforms currently use stub implementation');
        debugPrint('Full SMB functionality is available on desktop platforms');
      }
    }
  }

  /// Check if native SMB functionality is available
  bool get isNativeAvailable => _isNativeAvailable;

  /// Check if currently connected
  bool get isConnected {
    if (!_isNativeAvailable) return false;
    return _nativeService?.isConnected ?? false;
  }

  /// Connect to SMB server
  Future<bool> connect(SmbConnectionConfig config) async {
    if (!_isNativeAvailable) {
      debugPrint('SMB connection failed: Native service not available');
      return false;
    }

    try {
      return await _nativeService!.connect(config);
    } catch (e) {
      debugPrint('SMB connection error: $e');
      return false;
    }
  }

  /// Disconnect from SMB server
  Future<void> disconnect() async {
    if (!_isNativeAvailable) return;

    try {
      await _nativeService!.disconnect();
    } catch (e) {
      debugPrint('SMB disconnect error: $e');
    }
  }

  /// List directory contents
  Future<List<SmbFile>> listDirectory(String path) async {
    if (!_isNativeAvailable) {
      debugPrint('Directory listing failed: Native service not available');
      return [];
    }

    try {
      return await _nativeService!.listDirectory(path);
    } catch (e) {
      debugPrint('Directory listing error: $e');
      return [];
    }
  }

  /// Stream file data
  Stream<List<int>>? streamFile(String path) {
    if (!_isNativeAvailable) {
      debugPrint('File streaming failed: Native service not available');
      return null;
    }

    try {
      return _nativeService!.streamFile(path);
    } catch (e) {
      debugPrint('File streaming error: $e');
      return null;
    }
  }

  /// Stream file data from specific offset (for seek support)
  Stream<List<int>>? seekFileStream(String path, int offset) {
    if (!_isNativeAvailable) {
      debugPrint('File seek streaming failed: Native service not available');
      return null;
    }

    try {
      return _nativeService!.seekFileStream(path, offset);
    } catch (e) {
      debugPrint('File seek streaming error: $e');
      return null;
    }
  }

  /// Stream file with progress tracking
  Stream<SmbStreamChunk> streamFileWithProgress(
    String path, {
    Function(double)? onProgress,
  }) {
    if (!_isNativeAvailable) {
      debugPrint(
          'File streaming with progress failed: Native service not available');
      return Stream.empty();
    }

    try {
      return _nativeService!
          .streamFileWithProgress(path, onProgress: onProgress);
    } catch (e) {
      debugPrint('File streaming with progress error: $e');
      return Stream.empty();
    }
  }

  /// Get platform-specific error message
  String getPlatformErrorMessage() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'SMB functionality is currently limited on mobile platforms. '
          'Full functionality is available on Windows, Linux, and macOS.';
    } else {
      return 'SMB native library failed to load. Please ensure libsmb2 is properly installed.';
    }
  }

  /// Get platform support status
  Map<String, dynamic> getPlatformStatus() {
    return {
      'platform': Platform.operatingSystem,
      'nativeAvailable': _isNativeAvailable,
      'isConnected': isConnected,
      'supportLevel': _getSupportLevel(),
    };
  }

  String _getSupportLevel() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _isNativeAvailable ? 'full' : 'limited';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'stub';
    } else {
      return 'unsupported';
    }
  }
}
