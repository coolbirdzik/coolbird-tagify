import 'dart:io';
import 'dart:typed_data';

/// Base class for all network services
abstract class NetworkServiceBase {
  /// Returns the name of this network service
  String get serviceName;

  /// Returns the description of this network service
  String get serviceDescription;

  /// Returns the icon data for this service
  dynamic get serviceIcon;

  /// Check if this service is available on this platform
  bool isAvailable();

  /// Connect to a network location
  /// Returns a success boolean and an optional error message
  Future<ConnectionResult> connect({
    required String host,
    required String username,
    String? password,
    int? port,
    Map<String, dynamic>? additionalOptions,
  });

  /// Disconnect from the current connection
  Future<void> disconnect();

  /// List all files and directories at the given path
  Future<List<FileSystemEntity>> listDirectory(String path);

  /// Get file from remote path to local path
  Future<File> getFile(String remotePath, String localPath);

  /// Get file from remote path to local path with progress updates
  Future<File> getFileWithProgress(
    String remotePath,
    String localPath,
    void Function(double progress)? onProgress,
  );

  /// Put file from local path to remote path
  Future<bool> putFile(String localPath, String remotePath);

  /// Put file from local path to remote path with progress updates
  Future<bool> putFileWithProgress(
    String localPath,
    String remotePath,
    void Function(double progress)? onProgress,
  );

  /// Delete a file at the given path
  Future<bool> deleteFile(String path);

  /// Create a directory at the given path
  Future<bool> createDirectory(String path);

  /// Delete a directory at the given path
  Future<bool> deleteDirectory(String path);

  /// Rename a file or directory
  Future<bool> rename(String oldPath, String newPath);

  /// Check if connected to the service
  bool get isConnected;

  /// Get the base path for this connection, used for tab display
  String get basePath;

  /// Open a file for streaming (optional, returns null if not supported)
  Stream<List<int>>? openFileStream(String remotePath) => null;

  /// Get file size without downloading (optional, returns null if not supported)
  Future<int?> getFileSize(String remotePath) async => null;

  /// Generate thumbnail for image or video file (optional, returns null if not supported)
  Future<Uint8List?> getThumbnail(String remotePath, int size) async => null;
}

/// Result of a connection attempt
class ConnectionResult {
  final bool success;
  final String? errorMessage;
  final String? connectedPath;

  ConnectionResult({
    required this.success,
    this.errorMessage,
    this.connectedPath,
  });
}
