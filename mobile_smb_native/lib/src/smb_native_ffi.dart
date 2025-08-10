import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Error codes
class SmbErrorCodes {
  static const int success = 0;
  static const int connectionError = -1;
  static const int authenticationError = -2;
  static const int fileNotFound = -3;
  static const int permissionDenied = -4;
  static const int invalidParameter = -5;
  static const int memoryAllocation = -6;
  static const int thumbnailGeneration = -7;
  static const int unknown = -999;
}

// Native structures
base class SmbFileInfo extends Struct {
  external Pointer<Utf8> name;
  external Pointer<Utf8> path;
  @Uint64()
  external int size;
  @Uint64()
  external int modifiedTime;
  @Int32()
  external int isDirectory;
  @Int32()
  external int errorCode;
}

base class SmbDirectoryResult extends Struct {
  external Pointer<SmbFileInfo> files;
  @Uint64()
  external int count;
  @Int32()
  external int errorCode;
}

base class ThumbnailResult extends Struct {
  external Pointer<Uint8> data;
  @Uint64()
  external int size;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int errorCode;
}

// Function signatures
typedef SmbConnectNative = Pointer<Void> Function(Pointer<Utf8> server,
    Pointer<Utf8> share, Pointer<Utf8> username, Pointer<Utf8> password);
typedef SmbConnectDart = Pointer<Void> Function(Pointer<Utf8> server,
    Pointer<Utf8> share, Pointer<Utf8> username, Pointer<Utf8> password);

typedef SmbDisconnectNative = Void Function(Pointer<Void> context);
typedef SmbDisconnectDart = void Function(Pointer<Void> context);

typedef SmbIsConnectedNative = Int32 Function(Pointer<Void> context);
typedef SmbIsConnectedDart = int Function(Pointer<Void> context);

typedef SmbOpenFileNative = Pointer<Void> Function(
    Pointer<Void> context, Pointer<Utf8> path);
typedef SmbOpenFileDart = Pointer<Void> Function(
    Pointer<Void> context, Pointer<Utf8> path);

typedef SmbCloseFileNative = Void Function(Pointer<Void> fileHandle);
typedef SmbCloseFileDart = void Function(Pointer<Void> fileHandle);

typedef SmbReadChunkNative = Int32 Function(Pointer<Void> fileHandle,
    Pointer<Uint8> buffer, Size bufferSize, Pointer<Size> bytesRead);
typedef SmbReadChunkDart = int Function(Pointer<Void> fileHandle,
    Pointer<Uint8> buffer, int bufferSize, Pointer<Size> bytesRead);

typedef SmbSeekFileNative = Int32 Function(
    Pointer<Void> fileHandle, Uint64 offset);
typedef SmbSeekFileDart = int Function(Pointer<Void> fileHandle, int offset);

typedef SmbGetFileSizeNative = Uint64 Function(Pointer<Void> fileHandle);
typedef SmbGetFileSizeDart = int Function(Pointer<Void> fileHandle);

// NEW: Enhanced read-range operations
typedef SmbReadRangeNative = Int32 Function(
    Pointer<Void> fileHandle,
    Pointer<Uint8> buffer,
    Size bufferSize,
    Uint64 startOffset,
    Uint64 endOffset,
    Pointer<Size> bytesRead);
typedef SmbReadRangeDart = int Function(
    Pointer<Void> fileHandle,
    Pointer<Uint8> buffer,
    int bufferSize,
    int startOffset,
    int endOffset,
    Pointer<Size> bytesRead);

typedef SmbReadRangeAsyncNative = Int32 Function(
    Pointer<Void> fileHandle,
    Pointer<Uint8> buffer,
    Size bufferSize,
    Uint64 startOffset,
    Uint64 endOffset,
    Pointer<Size> bytesRead);
typedef SmbReadRangeAsyncDart = int Function(
    Pointer<Void> fileHandle,
    Pointer<Uint8> buffer,
    int bufferSize,
    int startOffset,
    int endOffset,
    Pointer<Size> bytesRead);

typedef SmbPrefetchRangeNative = Int32 Function(
    Pointer<Void> fileHandle, Uint64 startOffset, Uint64 endOffset);
typedef SmbPrefetchRangeDart = int Function(
    Pointer<Void> fileHandle, int startOffset, int endOffset);

typedef SmbSetStreamingOptionsNative = Int32 Function(Pointer<Void> fileHandle,
    Size chunkSize, Size bufferSize, Int32 enableCaching);
typedef SmbSetStreamingOptionsDart = int Function(
    Pointer<Void> fileHandle, int chunkSize, int bufferSize, int enableCaching);

// NEW: SMB URL generation
typedef SmbGenerateDirectUrlNative = Pointer<Utf8> Function(
    Pointer<Void> context, Pointer<Utf8> path);
typedef SmbGenerateDirectUrlDart = Pointer<Utf8> Function(
    Pointer<Void> context, Pointer<Utf8> path);

typedef SmbGenerateUrlWithCredentialsNative = Pointer<Utf8> Function(
    Pointer<Void> context,
    Pointer<Utf8> path,
    Pointer<Utf8> username,
    Pointer<Utf8> password);
typedef SmbGenerateUrlWithCredentialsDart = Pointer<Utf8> Function(
    Pointer<Void> context,
    Pointer<Utf8> path,
    Pointer<Utf8> username,
    Pointer<Utf8> password);

typedef SmbGetConnectionUrlNative = Pointer<Utf8> Function(
    Pointer<Void> context);
typedef SmbGetConnectionUrlDart = Pointer<Utf8> Function(Pointer<Void> context);

typedef SmbListDirectoryNative = SmbDirectoryResult Function(
    Pointer<Void> context, Pointer<Utf8> path);
typedef SmbListDirectoryDart = SmbDirectoryResult Function(
    Pointer<Void> context, Pointer<Utf8> path);

typedef SmbFreeDirectoryResultNative = Void Function(
    Pointer<SmbDirectoryResult> result);
typedef SmbFreeDirectoryResultDart = void Function(
    Pointer<SmbDirectoryResult> result);

typedef SmbGenerateThumbnailNative = ThumbnailResult Function(
    Pointer<Void> context, Pointer<Utf8> path, Int32 width, Int32 height);
typedef SmbGenerateThumbnailDart = ThumbnailResult Function(
    Pointer<Void> context, Pointer<Utf8> path, int width, int height);

typedef SmbFreeThumbnailResultNative = Void Function(
    Pointer<ThumbnailResult> result);
typedef SmbFreeThumbnailResultDart = void Function(
    Pointer<ThumbnailResult> result);

typedef SmbGetErrorMessageNative = Pointer<Utf8> Function(Int32 errorCode);
typedef SmbGetErrorMessageDart = Pointer<Utf8> Function(int errorCode);

typedef SmbFreeStringNative = Void Function(Pointer<Utf8> str);
typedef SmbFreeStringDart = void Function(Pointer<Utf8> str);

class SmbNativeFFI {
  late DynamicLibrary _dylib;
  late SmbConnectDart _smbConnect;
  late SmbDisconnectDart _smbDisconnect;
  late SmbIsConnectedDart _smbIsConnected;
  late SmbOpenFileDart _smbOpenFile;
  late SmbCloseFileDart _smbCloseFile;
  late SmbReadChunkDart _smbReadChunk;
  late SmbSeekFileDart _smbSeekFile;
  late SmbGetFileSizeDart _smbGetFileSize;

  // NEW: Enhanced read-range operations (nullable for fallback)
  SmbReadRangeDart? _smbReadRange;
  SmbReadRangeAsyncDart? _smbReadRangeAsync;
  SmbPrefetchRangeDart? _smbPrefetchRange;
  SmbSetStreamingOptionsDart? _smbSetStreamingOptions;

  // NEW: SMB URL generation (nullable for fallback)
  SmbGenerateDirectUrlDart? _smbGenerateDirectUrl;
  SmbGenerateUrlWithCredentialsDart? _smbGenerateUrlWithCredentials;
  SmbGetConnectionUrlDart? _smbGetConnectionUrl;

  late SmbListDirectoryDart _smbListDirectory;
  late SmbFreeDirectoryResultDart _smbFreeDirectoryResult;
  late SmbGenerateThumbnailDart _smbGenerateThumbnail;
  late SmbFreeThumbnailResultDart _smbFreeThumbnailResult;
  late SmbGetErrorMessageDart _smbGetErrorMessage;
  late SmbFreeStringDart _smbFreeString;

  SmbNativeFFI() {
    _loadLibrary();
    _bindFunctions();
  }

  void _loadLibrary() {
    try {
      if (Platform.isAndroid) {
        _dylib = DynamicLibrary.open('libsmb_bridge.so');
      } else if (Platform.isIOS) {
        _dylib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _dylib = DynamicLibrary.open('smb_bridge.dll');
      } else if (Platform.isLinux) {
        _dylib = DynamicLibrary.open('libsmb_bridge.so');
      } else if (Platform.isMacOS) {
        _dylib = DynamicLibrary.open('libsmb_bridge.dylib');
      } else {
        throw UnsupportedError('Platform not supported');
      }
    } catch (e) {
      throw Exception('Failed to load SMB native library: $e');
    }
  }

  void _bindFunctions() {
    _smbConnect = _dylib
        .lookup<NativeFunction<SmbConnectNative>>('smb_connect')
        .asFunction();

    _smbDisconnect = _dylib
        .lookup<NativeFunction<SmbDisconnectNative>>('smb_disconnect')
        .asFunction();

    _smbIsConnected = _dylib
        .lookup<NativeFunction<SmbIsConnectedNative>>('smb_is_connected')
        .asFunction();

    _smbOpenFile = _dylib
        .lookup<NativeFunction<SmbOpenFileNative>>('smb_open_file')
        .asFunction();

    _smbCloseFile = _dylib
        .lookup<NativeFunction<SmbCloseFileNative>>('smb_close_file')
        .asFunction();

    _smbReadChunk = _dylib
        .lookup<NativeFunction<SmbReadChunkNative>>('smb_read_chunk')
        .asFunction();

    _smbSeekFile = _dylib
        .lookup<NativeFunction<SmbSeekFileNative>>('smb_seek_file')
        .asFunction();

    _smbGetFileSize = _dylib
        .lookup<NativeFunction<SmbGetFileSizeNative>>('smb_get_file_size')
        .asFunction();

    // NEW: Enhanced read-range operations (with fallback)
    try {
      _smbReadRange = _dylib
          .lookup<NativeFunction<SmbReadRangeNative>>('smb_read_range')
          .asFunction();
    } catch (e) {
      print('Warning: smb_read_range not available, using fallback');
      _smbReadRange = null;
    }

    try {
      _smbReadRangeAsync = _dylib
          .lookup<NativeFunction<SmbReadRangeAsyncNative>>(
              'smb_read_range_async')
          .asFunction();
    } catch (e) {
      print('Warning: smb_read_range_async not available, using fallback');
      _smbReadRangeAsync = null;
    }

    try {
      _smbPrefetchRange = _dylib
          .lookup<NativeFunction<SmbPrefetchRangeNative>>('smb_prefetch_range')
          .asFunction();
    } catch (e) {
      print('Warning: smb_prefetch_range not available, using fallback');
      _smbPrefetchRange = null;
    }

    try {
      _smbSetStreamingOptions = _dylib
          .lookup<NativeFunction<SmbSetStreamingOptionsNative>>(
              'smb_set_streaming_options')
          .asFunction();
    } catch (e) {
      print('Warning: smb_set_streaming_options not available, using fallback');
      _smbSetStreamingOptions = null;
    }

    // NEW: SMB URL generation (with fallback)
    try {
      _smbGenerateDirectUrl = _dylib
          .lookup<NativeFunction<SmbGenerateDirectUrlNative>>(
              'smb_generate_direct_url')
          .asFunction();
    } catch (e) {
      print('Warning: smb_generate_direct_url not available, using fallback');
      _smbGenerateDirectUrl = null;
    }

    try {
      _smbGenerateUrlWithCredentials = _dylib
          .lookup<NativeFunction<SmbGenerateUrlWithCredentialsNative>>(
              'smb_generate_url_with_credentials')
          .asFunction();
    } catch (e) {
      print(
          'Warning: smb_generate_url_with_credentials not available, using fallback');
      _smbGenerateUrlWithCredentials = null;
    }

    try {
      _smbGetConnectionUrl = _dylib
          .lookup<NativeFunction<SmbGetConnectionUrlNative>>(
              'smb_get_connection_url')
          .asFunction();
    } catch (e) {
      print('Warning: smb_get_connection_url not available, using fallback');
      _smbGetConnectionUrl = null;
    }

    _smbListDirectory = _dylib
        .lookup<NativeFunction<SmbListDirectoryNative>>('smb_list_directory')
        .asFunction();

    _smbFreeDirectoryResult = _dylib
        .lookup<NativeFunction<SmbFreeDirectoryResultNative>>(
            'smb_free_directory_result')
        .asFunction();

    _smbGenerateThumbnail = _dylib
        .lookup<NativeFunction<SmbGenerateThumbnailNative>>(
            'smb_generate_thumbnail')
        .asFunction();

    _smbFreeThumbnailResult = _dylib
        .lookup<NativeFunction<SmbFreeThumbnailResultNative>>(
            'smb_free_thumbnail_result')
        .asFunction();

    _smbGetErrorMessage = _dylib
        .lookup<NativeFunction<SmbGetErrorMessageNative>>(
            'smb_get_error_message')
        .asFunction();

    _smbFreeString = _dylib
        .lookup<NativeFunction<SmbFreeStringNative>>('smb_free_string')
        .asFunction();
  }

  // Connection methods
  Pointer<Void>? connect(
      String server, String share, String username, String password) {
    final serverPtr = server.toNativeUtf8();
    final sharePtr = share.toNativeUtf8();
    final usernamePtr = username.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();

    try {
      final result = _smbConnect(serverPtr, sharePtr, usernamePtr, passwordPtr);
      return result.address == 0 ? null : result;
    } finally {
      malloc.free(serverPtr);
      malloc.free(sharePtr);
      malloc.free(usernamePtr);
      malloc.free(passwordPtr);
    }
  }

  void disconnect(Pointer<Void> context) {
    _smbDisconnect(context);
  }

  bool isConnected(Pointer<Void> context) {
    return _smbIsConnected(context) != 0;
  }

  // File operations
  Pointer<Void>? openFile(Pointer<Void> context, String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      final result = _smbOpenFile(context, pathPtr);
      return result.address == 0 ? null : result;
    } finally {
      malloc.free(pathPtr);
    }
  }

  void closeFile(Pointer<Void> fileHandle) {
    _smbCloseFile(fileHandle);
  }

  int readChunk(Pointer<Void> fileHandle, Uint8List buffer) {
    final bufferPtr = malloc<Uint8>(buffer.length);
    final bytesReadPtr = malloc<Size>();

    try {
      final errorCode =
          _smbReadChunk(fileHandle, bufferPtr, buffer.length, bytesReadPtr);
      if (errorCode == SmbErrorCodes.success) {
        final bytesRead = bytesReadPtr.value;
        final data = bufferPtr.asTypedList(bytesRead);
        buffer.setRange(0, bytesRead, data);
        return bytesRead;
      }
      return 0;
    } finally {
      malloc.free(bufferPtr);
      malloc.free(bytesReadPtr);
    }
  }

  bool seekFile(Pointer<Void> fileHandle, int offset) {
    return _smbSeekFile(fileHandle, offset) == SmbErrorCodes.success;
  }

  int getFileSize(Pointer<Void> fileHandle) {
    return _smbGetFileSize(fileHandle);
  }

  // NEW: Enhanced read-range operations for VLC-style streaming
  int readRange(Pointer<Void> fileHandle, Uint8List buffer, int startOffset,
      int endOffset) {
    if (_smbReadRange == null) {
      print('Warning: readRange not available, using fallback');
      return 0;
    }

    final bufferPtr = malloc<Uint8>(buffer.length);
    final bytesReadPtr = malloc<Size>();

    try {
      final errorCode = _smbReadRange!(fileHandle, bufferPtr, buffer.length,
          startOffset, endOffset, bytesReadPtr);
      if (errorCode == SmbErrorCodes.success) {
        final bytesRead = bytesReadPtr.value;
        final data = bufferPtr.asTypedList(bytesRead);
        buffer.setRange(0, bytesRead, data);
        return bytesRead;
      }
      return 0;
    } finally {
      malloc.free(bufferPtr);
      malloc.free(bytesReadPtr);
    }
  }

  int readRangeAsync(Pointer<Void> fileHandle, Uint8List buffer,
      int startOffset, int endOffset) {
    if (_smbReadRangeAsync == null) {
      print('Warning: readRangeAsync not available, using fallback');
      return 0;
    }

    final bufferPtr = malloc<Uint8>(buffer.length);
    final bytesReadPtr = malloc<Size>();

    try {
      final errorCode = _smbReadRangeAsync!(fileHandle, bufferPtr,
          buffer.length, startOffset, endOffset, bytesReadPtr);
      if (errorCode == SmbErrorCodes.success) {
        final bytesRead = bytesReadPtr.value;
        final data = bufferPtr.asTypedList(bytesRead);
        buffer.setRange(0, bytesRead, data);
        return bytesRead;
      }
      return 0;
    } finally {
      malloc.free(bufferPtr);
      malloc.free(bytesReadPtr);
    }
  }

  bool prefetchRange(Pointer<Void> fileHandle, int startOffset, int endOffset) {
    if (_smbPrefetchRange == null) {
      print('Warning: prefetchRange not available, using fallback');
      return false;
    }
    return _smbPrefetchRange!(fileHandle, startOffset, endOffset) ==
        SmbErrorCodes.success;
  }

  bool setStreamingOptions(Pointer<Void> fileHandle, int chunkSize,
      int bufferSize, bool enableCaching) {
    if (_smbSetStreamingOptions == null) {
      print('Warning: setStreamingOptions not available, using fallback');
      return false;
    }
    return _smbSetStreamingOptions!(
            fileHandle, chunkSize, bufferSize, enableCaching ? 1 : 0) ==
        SmbErrorCodes.success;
  }

  // NEW: SMB URL generation for direct VLC streaming
  String? generateDirectUrl(Pointer<Void> context, String path) {
    if (_smbGenerateDirectUrl == null) {
      print('Warning: generateDirectUrl not available, using fallback');
      return null;
    }

    final pathPtr = path.toNativeUtf8();

    try {
      final urlPtr = _smbGenerateDirectUrl!(context, pathPtr);
      if (urlPtr.address != 0) {
        final url = urlPtr.toDartString();
        _smbFreeString(urlPtr);
        return url;
      }
    } finally {
      malloc.free(pathPtr);
    }

    return null;
  }

  String? generateUrlWithCredentials(
      Pointer<Void> context, String path, String username, String password) {
    if (_smbGenerateUrlWithCredentials == null) {
      print(
          'Warning: generateUrlWithCredentials not available, using fallback');
      return null;
    }

    final pathPtr = path.toNativeUtf8();
    final usernamePtr = username.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();

    try {
      final urlPtr = _smbGenerateUrlWithCredentials!(
          context, pathPtr, usernamePtr, passwordPtr);
      if (urlPtr.address != 0) {
        final url = urlPtr.toDartString();
        _smbFreeString(urlPtr);
        return url;
      }
    } finally {
      malloc.free(pathPtr);
      malloc.free(usernamePtr);
      malloc.free(passwordPtr);
    }

    return null;
  }

  String? getConnectionUrl(Pointer<Void> context) {
    if (_smbGetConnectionUrl == null) {
      print('Warning: getConnectionUrl not available, using fallback');
      return null;
    }

    final urlPtr = _smbGetConnectionUrl!(context);
    if (urlPtr.address != 0) {
      final url = urlPtr.toDartString();
      _smbFreeString(urlPtr);
      return url;
    }
    return null;
  }

  // Directory operations
  List<Map<String, dynamic>> listDirectory(Pointer<Void> context, String path) {
    final pathPtr = path.toNativeUtf8();
    final List<Map<String, dynamic>> files = [];

    try {
      final result = _smbListDirectory(context, pathPtr);

      if (result.errorCode == SmbErrorCodes.success && result.count > 0) {
        for (int i = 0; i < result.count; i++) {
          final fileInfo = result.files.elementAt(i).ref;
          files.add({
            'name': fileInfo.name.toDartString(),
            'path': fileInfo.path.toDartString(),
            'size': fileInfo.size,
            'modifiedTime': fileInfo.modifiedTime,
            'isDirectory': fileInfo.isDirectory != 0,
          });
        }

        // Free the result
        final resultPtr = malloc<SmbDirectoryResult>();
        resultPtr.ref = result;
        _smbFreeDirectoryResult(resultPtr);
        malloc.free(resultPtr);
      }
    } finally {
      malloc.free(pathPtr);
    }

    return files;
  }

  // Thumbnail generation
  Uint8List? generateThumbnail(
      Pointer<Void> context, String path, int width, int height) {
    final pathPtr = path.toNativeUtf8();

    try {
      final result = _smbGenerateThumbnail(context, pathPtr, width, height);

      if (result.errorCode == SmbErrorCodes.success && result.size > 0) {
        final data = result.data.asTypedList(result.size);
        final thumbnail = Uint8List.fromList(data);

        // Free the result
        final resultPtr = malloc<ThumbnailResult>();
        resultPtr.ref = result;
        _smbFreeThumbnailResult(resultPtr);
        malloc.free(resultPtr);

        return thumbnail;
      }
    } finally {
      malloc.free(pathPtr);
    }

    return null;
  }

  // Utility methods
  String getErrorMessage(int errorCode) {
    final messagePtr = _smbGetErrorMessage(errorCode);
    final message = messagePtr.toDartString();
    _smbFreeString(messagePtr);
    return message;
  }
}
