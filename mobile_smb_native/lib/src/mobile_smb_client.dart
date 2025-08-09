import 'smb_file.dart';
import 'smb_connection_config.dart';
import 'mobile_smb_native_platform_interface.dart';

/// Main client class for SMB operations on mobile platforms
class MobileSmbClient {
  static final MobileSmbClient _instance = MobileSmbClient._internal();

  /// Get the singleton instance of MobileSmbClient
  factory MobileSmbClient() => _instance;

  MobileSmbClient._internal();

  /// Current connection configuration
  SmbConnectionConfig? _currentConfig;

  /// Get the current connection configuration
  SmbConnectionConfig? get currentConfig => _currentConfig;

  /// Connect to an SMB server
  ///
  /// Returns true if connection is successful, false otherwise
  Future<bool> connect(SmbConnectionConfig config) async {
    final success = await MobileSmbNativePlatform.instance.connect(config);
    if (success) {
      _currentConfig = config;
    }
    return success;
  }

  /// Disconnect from the current SMB server
  ///
  /// Returns true if disconnection is successful, false otherwise
  Future<bool> disconnect() async {
    final success = await MobileSmbNativePlatform.instance.disconnect();
    if (success) {
      _currentConfig = null;
    }
    return success;
  }

  /// List available shares on the connected server
  ///
  /// Returns a list of share names
  Future<List<String>> listShares() async {
    return await MobileSmbNativePlatform.instance.listShares();
  }

  /// List files and directories in the specified path
  ///
  /// [path] - The directory path to list (e.g., "/share/folder")
  /// Returns a list of SmbFile objects
  Future<List<SmbFile>> listDirectory(String path) async {
    return await MobileSmbNativePlatform.instance.listDirectory(path);
  }

  /// Read file content as bytes
  ///
  /// [path] - The file path to read
  /// Returns file content as a list of bytes
  Future<List<int>> readFile(String path) async {
    return await MobileSmbNativePlatform.instance.readFile(path);
  }

  /// Read file content as a string
  ///
  /// [path] - The file path to read
  /// [encoding] - Text encoding (default: utf-8)
  /// Returns file content as a string
  Future<String> readFileAsString(String path,
      {String encoding = 'utf-8'}) async {
    final bytes = await readFile(path);
    if (bytes.isEmpty) return '';

    try {
      // Simple UTF-8 decoding for now
      return String.fromCharCodes(bytes);
    } catch (e) {
      throw Exception('Failed to decode file as $encoding: $e');
    }
  }

  /// Write bytes to a file
  ///
  /// [path] - The file path to write to
  /// [data] - The data to write as bytes
  /// Returns true if write is successful, false otherwise
  Future<bool> writeFile(String path, List<int> data) async {
    return await MobileSmbNativePlatform.instance.writeFile(path, data);
  }

  /// Write string content to a file
  ///
  /// [path] - The file path to write to
  /// [content] - The string content to write
  /// [encoding] - Text encoding (default: utf-8)
  /// Returns true if write is successful, false otherwise
  Future<bool> writeFileAsString(String path, String content,
      {String encoding = 'utf-8'}) async {
    try {
      // Simple UTF-8 encoding for now
      final bytes = content.codeUnits;
      return await writeFile(path, bytes);
    } catch (e) {
      throw Exception('Failed to encode string as $encoding: $e');
    }
  }

  /// Delete a file or directory
  ///
  /// [path] - The path to delete
  /// Returns true if deletion is successful, false otherwise
  Future<bool> delete(String path) async {
    return await MobileSmbNativePlatform.instance.delete(path);
  }

  /// Create a directory
  ///
  /// [path] - The directory path to create
  /// Returns true if creation is successful, false otherwise
  Future<bool> createDirectory(String path) async {
    return await MobileSmbNativePlatform.instance.createDirectory(path);
  }

  /// Check if currently connected to an SMB server
  ///
  /// Returns true if connected, false otherwise
  Future<bool> isConnected() async {
    return await MobileSmbNativePlatform.instance.isConnected();
  }

  /// Get file or directory information
  ///
  /// [path] - The path to get information for
  /// Returns SmbFile object with file information, or null if not found
  Future<SmbFile?> getFileInfo(String path) async {
    return await MobileSmbNativePlatform.instance.getFileInfo(path);
  }

  /// Open file for streaming read
  ///
  /// [path] - The path to the file to stream
  /// Returns a Stream<List<int>> for reading file data in chunks, or null if streaming is not supported
  Stream<List<int>>? openFileStream(String path) {
    return MobileSmbNativePlatform.instance.openFileStream(path);
  }

  /// Get SMB version information
  ///
  /// Returns the SMB version being used for the current connection
  Future<String> getSmbVersion() async {
    return await MobileSmbNativePlatform.instance.getSmbVersion();
  }

  /// Get connection information including SMB version
  ///
  /// Returns detailed connection information including server, share, version, and user
  Future<String> getConnectionInfo() async {
    return await MobileSmbNativePlatform.instance.getConnectionInfo();
  }

  /// Get native SMB context pointer for media streaming
  ///
  /// Returns the native context pointer as an integer address
  /// This is used for direct media streaming with LibVLC/FFmpeg
  Future<int?> getNativeContext() async {
    return await MobileSmbNativePlatform.instance.getNativeContext();
  }

  /// Open file for optimized video streaming
  ///
  /// [path] - The path to the file to stream
  /// [chunkSize] - The size of chunks to read (default: 1MB for better performance)
  /// Returns a Stream<List<int>> for optimized video streaming, or null if not supported
  Stream<List<int>>? openFileStreamOptimized(String path,
      {int chunkSize = 1024 * 1024}) {
    return MobileSmbNativePlatform.instance
        .openFileStreamOptimized(path, chunkSize: chunkSize);
  }

  /// Open file for optimized video streaming with seek support
  ///
  /// [path] - The path to the file to stream
  /// [offset] - The byte offset to start streaming from
  /// [chunkSize] - The size of chunks to read (default: 1MB for better performance)
  /// Returns a Stream<List<int>> for optimized video streaming with seek, or null if not supported
  Stream<List<int>>? seekFileStreamOptimized(String path, int offset,
      {int chunkSize = 1024 * 1024}) {
    return MobileSmbNativePlatform.instance
        .seekFileStreamOptimized(path, offset, chunkSize: chunkSize);
  }

  /// Check if a path exists
  ///
  /// [path] - The path to check
  /// Returns true if the path exists, false otherwise
  Future<bool> exists(String path) async {
    final fileInfo = await getFileInfo(path);
    return fileInfo != null;
  }

  /// Check if a path is a directory
  ///
  /// [path] - The path to check
  /// Returns true if the path is a directory, false otherwise
  Future<bool> isDirectory(String path) async {
    final fileInfo = await getFileInfo(path);
    return fileInfo?.isDirectory ?? false;
  }

  /// Check if a path is a file
  ///
  /// [path] - The path to check
  /// Returns true if the path is a file, false otherwise
  Future<bool> isFile(String path) async {
    final fileInfo = await getFileInfo(path);
    return fileInfo != null && !fileInfo.isDirectory;
  }
}
