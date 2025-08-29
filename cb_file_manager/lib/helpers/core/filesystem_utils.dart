// dart
import 'dart:async';
import 'dart:io';
import 'dart:ffi';

// packages
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as pathlib;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart' as win32;
import 'package:ffi/ffi.dart';

// local files
import 'io_extensions.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

String storageRootPath = "/storage/emulated/0/";

enum Sorting { type, size, date, alpha, typeDate, typeSize }

/// Return all **paths**
Future<List<Directory>> getStorageList() async {
  // Fix for null safety - handle nullable return value
  List<Directory> paths = await getExternalStorageDirectories() ?? [];
  List<Directory> filteredPaths = []; // Use list literal instead of constructor
  for (Directory dir in paths) {
    filteredPaths
        .add(await getExternalStorageWithoutDataDir(dir.absolute.path));
  }
  return filteredPaths;
}

/// This function aims to get path like: `/storage/emulated/0/`
/// not like `/storage/emulated/0/Android/data/package.name.example/files`
Future<Directory> getExternalStorageWithoutDataDir(
    String unfilteredPath) async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String subPath =
      pathlib.join("Android", "data", packageInfo.packageName, "files");
  if (unfilteredPath.contains(subPath)) {
    String filteredPath = unfilteredPath.split(subPath).first;
    return Directory(filteredPath);
  } else {
    return Directory(unfilteredPath);
  }
}

/// keepHidden: show files that start with .
Future<List<FileSystemEntity>> getFoldersAndFiles(String path,
    {changeCurrentPath = true,
    Sorting sortedBy = Sorting.type,
    reverse = false,
    recursive = false,
    keepHidden = false}) async {
  Directory dir = Directory(path);
  List<FileSystemEntity> files = [];
  try {
    files = await dir.list(recursive: recursive).toList();

    // Create a new list to avoid type issues
    List<FileSystemEntity> typedFiles = [];

    for (var fsEntity in files) {
      String fsPath = fsEntity.path.toString();
      if (FileSystemEntity.isDirectorySync(fsPath)) {
        typedFiles.add(Directory(fsEntity.absolute.path.toString()));
      } else {
        typedFiles.add(File(fsEntity.absolute.path.toString()));
      }
    }

    files = typedFiles;

    // Removing hidden files & folders from the list
    if (!keepHidden) {
      debugPrint("filesystem->getFoldersAndFiles: excluding hidden");
      files.removeWhere((FileSystemEntity test) {
        return test.basename().startsWith('.') == true;
      });
    }
  } on FileSystemException {
    return [];
  }
  return sort(files, sortedBy, reverse: reverse);
}

/// keepHidden: show files that start with .
Stream<List<FileSystemEntity>> fileStream(String path,
    {changeCurrentPath = true,
    Sorting sortedBy = Sorting.type,
    reverse = false,
    recursive = false,
    keepHidden = false}) async* {
  Directory path0 = Directory(path);
  List<FileSystemEntity> files = []; // Use list literal
  try {
    // Checking if the target directory contains files inside or not!
    // so that [StreamBuilder] won't emit the same old data if there are
    // no elements inside that directory.
    if (path0.listSync(recursive: recursive).isNotEmpty) {
      if (!keepHidden) {
        yield* path0.list(recursive: recursive).transform(
            StreamTransformer.fromHandlers(
                handleData: (FileSystemEntity data, sink) {
          debugPrint("filsytem_utils -> fileStream: $data");
          files.add(data);
          sink.add(files);
        }));
      } else {
        yield* path0.list(recursive: recursive).transform(
            StreamTransformer.fromHandlers(
                handleData: (FileSystemEntity data, sink) {
          debugPrint("filsytem_utils -> fileStream: $data");
          if (data.basename().startsWith('.')) {
            files.add(data);
            sink.add(files);
          }
        }));
      }
    } else {
      yield [];
    }
  } on FileSystemException {
    yield [];
  }
}

/// search for files and folder in current directory & sub-directories,
/// and return [File] or [Directory]
///
/// [path]: start point
///
/// [query]: regex or simple string
Future<List<FileSystemEntity>> search(String path, String query,
    {bool matchCase = false, recursive = true, bool hidden = false}) async {
  int start = DateTime.now().millisecondsSinceEpoch;

  List<FileSystemEntity> entities =
      await getFoldersAndFiles(path, recursive: recursive, keepHidden: hidden);

  // Cải thiện cách tìm kiếm để hoạt động tốt hơn với thư mục
  List<FileSystemEntity> results = entities.where((entity) {
    // Lấy tên của thực thể mà không bao gồm đường dẫn
    String name = pathlib.basename(entity.path).toLowerCase();
    String searchQuery = query.toLowerCase();

    // Kiểm tra nếu tên chứa truy vấn tìm kiếm
    bool matches = name.contains(searchQuery);

    // Log kết quả tìm kiếm để dễ debug
    if (matches) {
      debugPrint(
          "Found matching entity: ${entity.path}, type: ${entity is Directory ? 'Directory' : 'File'}");
    }

    return matches;
  }).toList();

  int end = DateTime.now().millisecondsSinceEpoch;
  debugPrint(
      "Search completed in ${end - start} ms, found ${results.length} items (${results.whereType<Directory>().length} directories)");

  return results;
}

/// search for files and folder in current directory & sub-directories,
/// and return [File] or [Directory]
///
/// `path`: start point
/// `query`: regex or simple string
Stream<List<FileSystemEntity>> searchStream(String path, String query,
    {bool matchCase = false, recursive = true, bool hidden = false}) async* {
  yield* fileStream(path, recursive: recursive)
      .transform(StreamTransformer.fromHandlers(handleData: (data, sink) {
    // Filtering
    data.retainWhere(
        (test) => test.basename().toLowerCase().contains(query.toLowerCase()));
    sink.add(data);
  }));
}

Future<int> getFreeSpace(String path) async {
  MethodChannel platform = const MethodChannel('samples.flutter.dev/battery');
  int freeSpace = await platform.invokeMethod("getFreeStorageSpace");
  return freeSpace;
}

/// Create folder by path
/// * i.e: `.createFolderByPath("/storage/emulated/0/", "folder name" )`
///
/// Supply path alone to create by already combined path, or path + filename
/// to be combined
Future<Directory> createFolderByPath(String path, {String? folderName}) async {
  debugPrint("filesystem_utils->createFolderByPath: $folderName @ $path");
  Directory directory;

  directory = Directory(pathlib.join(path, folderName ?? ''));

  try {
    if (!directory.existsSync()) {
      directory.create();
    } else {
      throw const FileSystemException("File already exists");
    }
    return directory;
  } catch (e) {
    throw FileSystemException(e.toString());
  }
}

/// This function returns every [Directory] in th path
List<Directory> splitPathToDirectories(String path) {
  List<Directory> splittedPath = []; // Use list literal
  Directory pathDir = Directory(path);
  splittedPath.add(pathDir);
  for (int i = 0; i < pathlib.split(path).length; i++) {
    splittedPath.add(pathDir.parent);
    pathDir = pathDir.parent;
  }
  return splittedPath.reversed.toList();
}

Future<List<FileSystemEntity>> sort(List<FileSystemEntity> elements, Sorting by,
    {bool reverse = false}) async {
  try {
    switch (by) {
      case Sorting.type:
        if (!reverse) {
          return elements
            ..sort((f1, f2) {
              bool isDir1 =
                  FileSystemEntity.isDirectorySync(f1.path.toString());
              bool isDir2 =
                  FileSystemEntity.isDirectorySync(f2.path.toString());
              return isDir1 == isDir2 ? 0 : (isDir1 ? -1 : 1);
            });
        } else {
          return (elements..sort()).reversed.toList();
        }
      default:
        return elements..sort();
    }
  } catch (e) {
    return [];
  }
}

/// Get all available drives on Windows systems
/// Returns a list of directories representing each drive
/// Now also detects drives that require admin privileges and includes drive labels
Future<List<Directory>> getAllWindowsDrives() async {
  if (!Platform.isWindows) {
    return [];
  }

  List<Directory> drives = [];

  // Check all possible drive letters from A to Z
  for (var i = 65; i <= 90; i++) {
    String driveLetter = String.fromCharCode(i);
    String drivePath = '$driveLetter:\\';

    try {
      Directory drive = Directory(drivePath);

      // First check if the drive exists
      if (await drive.exists()) {
        // Try to test if we can list files as a permission check
        try {
          // Just try to list one file to check permissions
          await drive
              .list(followLinks: false)
              .first
              .timeout(const Duration(milliseconds: 500), onTimeout: () {
            throw TimeoutException('Permission check timed out');
          });

          // If we reach here, we have access
          drives.add(drive);

          // Get drive label and store it in the directory metadata
          String driveLabel = await getDriveLabel(drivePath);
          drive.setProperty('driveLabel', driveLabel);

          debugPrint('Found accessible drive: $drivePath - Label: $driveLabel');
        } catch (permissionError) {
          // Drive exists but we don't have permission
          // Create a special metadata property to mark as protected
          drive = Directory(drivePath);
          drives.add(drive);
          // Add a "tag" to mark this as a protected drive
          drive.setProperty('requiresAdmin', true);

          // Get drive label when possible and store it
          try {
            String driveLabel = await getDriveLabel(drivePath);
            drive.setProperty('driveLabel', driveLabel);
            debugPrint(
                'Found protected drive: $drivePath - Label: $driveLabel (requires admin)');
          } catch (e) {
            debugPrint('Found protected drive: $drivePath (requires admin)');
          }
        }
      }
    } catch (e) {
      // Ignore drives that can't be accessed or don't exist
      debugPrint('Drive not found or cannot be accessed: $drivePath - $e');
    }
  }

  return drives;
}

/// Get the volume label for a Windows drive
Future<String> getDriveLabel(String drivePath) async {
  if (!Platform.isWindows) {
    return '';
  }

  try {
    // Make sure path ends with backslash
    final drive = drivePath.endsWith('\\') ? drivePath : '$drivePath\\';

    // Allocate memory for the buffers
    final volumeNameBuffer = calloc<Uint16>(win32.MAX_PATH + 1).cast<Utf16>();
    final fileSystemNameBuffer =
        calloc<Uint16>(win32.MAX_PATH + 1).cast<Utf16>();

    // Volume serial number
    final volumeSerialNumber = calloc<Uint32>(1);

    // Maximum component length
    final maximumComponentLength = calloc<Uint32>(1);

    // File system flags
    final fileSystemFlags = calloc<Uint32>(1);

    try {
      // Get volume information
      final result = win32.GetVolumeInformation(
        drive.toNativeUtf16(),
        volumeNameBuffer,
        win32.MAX_PATH + 1,
        volumeSerialNumber,
        maximumComponentLength,
        fileSystemFlags,
        fileSystemNameBuffer,
        win32.MAX_PATH + 1,
      );

      String label = '';
      if (result != 0) {
        // Convert the buffer to a Dart string
        label = volumeNameBuffer.toDartString();
      }

      return label;
    } finally {
      // Free allocated memory
      calloc.free(volumeNameBuffer.cast<Uint16>());
      calloc.free(fileSystemNameBuffer.cast<Uint16>());
      calloc.free(volumeSerialNumber);
      calloc.free(maximumComponentLength);
      calloc.free(fileSystemFlags);
    }
  } catch (e) {
    debugPrint('Error getting drive label: $e');
    return '';
  }
}

/// Get additional Android storage locations
/// This includes common paths like /storage/, /mnt/, /system/, /data/, etc.
Future<List<Directory>> getAdditionalAndroidPaths() async {
  if (!Platform.isAndroid) {
    return [];
  }

  List<Directory> additionalPaths = [];
  List<String> pathsToCheck = [
    // Root directory
    '/',
    // Standard Android internal storage
    '/sdcard',
    '/storage/emulated/0',
    '/storage/self/primary',
    // System directories
    '/system',
    '/data',
    // Mount points that might contain storage devices
    '/mnt',
    '/mnt/sdcard',
    '/mnt/media_rw',
    '/storage',
  ];

  // Check common SD card path patterns
  for (int i = 0; i < 5; i++) {
    pathsToCheck.add('/storage/sdcard$i');
    pathsToCheck.add('/mnt/sdcard$i');
    pathsToCheck.add('/storage/extSdCard');
    pathsToCheck.add('/storage/emulated/$i');
  }

  // Try to list /storage/* directories to find mounted SD cards
  try {
    Directory storageDir = Directory('/storage');
    if (await storageDir.exists()) {
      List<FileSystemEntity> entries = await storageDir.list().toList();
      for (var entry in entries) {
        if (entry is Directory && !pathsToCheck.contains(entry.path)) {
          pathsToCheck.add(entry.path);
        }
      }
    }
  } catch (e) {
    debugPrint('Error listing /storage directory: $e');
  }

  // Check if each path exists and is accessible
  for (String path in pathsToCheck) {
    try {
      Directory dir = Directory(path);
      if (await dir.exists()) {
        try {
          // Try to list at least one file to ensure we have read access
          await dir.list().first.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              throw TimeoutException('Access check timed out');
            },
          );

          // If we got here, the directory exists and is accessible
          additionalPaths.add(dir);
          debugPrint('Found additional storage location: ${dir.path}');
        } catch (accessError) {
          // Path exists but we can't list files (no permission)
          debugPrint('Storage path exists but not accessible: $path');
        }
      }
    } catch (e) {
      // Path doesn't exist or other error
      debugPrint('Storage path not found or error: $path - $e');
    }
  }

  return additionalPaths;
}

/// Get all available storage locations across platforms
/// On Windows: returns all available drives
/// On Android: returns external storage directories and other storage paths
/// On other platforms: returns the application documents directory
Future<List<Directory>> getAllStorageLocations() async {
  List<Directory> storageLocations = [];

  try {
    if (Platform.isWindows) {
      // Get all Windows drives
      storageLocations = await getAllWindowsDrives();
    } else if (Platform.isAndroid) {
      // First try the standard Android storage detection
      try {
        List<Directory> standardPaths = await getStorageList();
        storageLocations.addAll(standardPaths);
      } catch (e) {
        debugPrint('Error getting standard Android storage: $e');
      }

      // Try to add additional Android paths
      try {
        storageLocations.addAll(await getAdditionalAndroidPaths());
      } catch (e) {
        debugPrint('Error getting additional Android paths: $e');
      }
    } else {
      // For other platforms, fallback to application documents directory
      Directory appDocDir = await getApplicationDocumentsDirectory();
      storageLocations.add(appDocDir);
    }
  } catch (e) {
    debugPrint('Error getting storage locations: $e');
    // Fallback to app documents directory
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      storageLocations.add(appDocDir);
    } catch (e) {
      debugPrint('Error getting application documents directory: $e');
    }
  }

  // Remove duplicates based on path
  final uniquePaths = <String>{};
  storageLocations = storageLocations.where((dir) {
    final path = dir.path;
    final isNew = !uniquePaths.contains(path);
    if (isNew) uniquePaths.add(path);
    return isNew;
  }).toList();

  return storageLocations;
}

/// Recursively get all videos in a directory and its subdirectories
Future<List<File>> getAllVideos(String path, {bool recursive = true}) async {
  List<FileSystemEntity> allFiles =
      await getFoldersAndFiles(path, recursive: recursive);

  List<File> videoFiles = allFiles.whereType<File>().where((file) {
    return FileTypeUtils.isVideoFile(file.path);
  }).toList();

  return videoFiles;
}

/// Recursively get all images in a directory and its subdirectories
Future<List<File>> getAllImages(String path, {bool recursive = true}) async {
  List<FileSystemEntity> allFiles =
      await getFoldersAndFiles(path, recursive: recursive);

  List<File> imageFiles = allFiles.whereType<File>().where((file) {
    return FileTypeUtils.isImageFile(file.path);
  }).toList();

  return imageFiles;
}

/// Class to manage file operations like copy, cut, paste, rename
class FileOperations {
  // Singleton instance
  static final FileOperations _instance = FileOperations._internal();
  factory FileOperations() => _instance;
  FileOperations._internal();

  // Store the current clipboard item (for copy/cut operations)
  FileSystemEntity? _clipboardItem;
  bool _isCut = false; // Flag to determine if operation is cut or copy

  // Getter to check if clipboard has an item
  bool get hasClipboardItem => _clipboardItem != null;

  // Getter to check if clipboard operation is cut
  bool get isClipboardItemCut => _isCut;

  // Getter for the clipboard item
  FileSystemEntity? get clipboardItem => _clipboardItem;

  // Set clipboard with file or folder
  void copyToClipboard(FileSystemEntity entity) {
    _clipboardItem = entity;
    _isCut = false;
  }

  // Set clipboard for cut operation
  void cutToClipboard(FileSystemEntity entity) {
    _clipboardItem = entity;
    _isCut = true;
  }

  // Clear clipboard after operation
  void clearClipboard() {
    _clipboardItem = null;
    _isCut = false;
  }

  // Paste file or folder from clipboard to destination
  Future<FileSystemEntity?> pasteFromClipboard(String destinationPath) async {
    if (_clipboardItem == null) return null;

    try {
      final filename = pathlib.basename(_clipboardItem!.path);
      final newPath = pathlib.join(destinationPath, filename);

      // Check if destination already exists
      bool exists =
          await File(newPath).exists() || await Directory(newPath).exists();

      // Create a unique name if destination exists
      String uniquePath = newPath;
      if (exists) {
        int counter = 1;
        String extension = '';
        String baseName = filename;

        // Handle file extensions
        if (_clipboardItem is File) {
          extension = pathlib.extension(filename);
          baseName = pathlib.basenameWithoutExtension(filename);
        }

        // Find a unique name
        while (exists) {
          String newName = '${baseName}_$counter$extension';
          uniquePath = pathlib.join(destinationPath, newName);
          exists = await File(uniquePath).exists() ||
              await Directory(uniquePath).exists();
          counter++;
        }
      }

      // Perform the operation based on entity type and operation type
      FileSystemEntity? result;

      if (_clipboardItem is File) {
        final file = _clipboardItem as File;

        if (_isCut) {
          // Move operation
          result = await file.rename(uniquePath);
        } else {
          // Copy operation
          result =
              await File(uniquePath).writeAsBytes(await file.readAsBytes());
        }
      } else if (_clipboardItem is Directory) {
        final directory = _clipboardItem as Directory;
        final newDirectory = Directory(uniquePath);

        // Create the new directory
        await newDirectory.create(recursive: true);

        // Copy all contents recursively
        await for (final entity in directory.list(recursive: true)) {
          final relativePath =
              pathlib.relative(entity.path, from: directory.path);
          final newEntityPath = pathlib.join(newDirectory.path, relativePath);

          if (entity is File) {
            // Create parent directories if needed
            final newEntityParent = Directory(pathlib.dirname(newEntityPath));
            if (!await newEntityParent.exists()) {
              await newEntityParent.create(recursive: true);
            }

            // Copy the file
            await File(newEntityPath).writeAsBytes(await entity.readAsBytes());
          } else if (entity is Directory) {
            // Create directory
            await Directory(newEntityPath).create(recursive: true);
          }
        }

        result = newDirectory;

        // If cut operation, delete original directory
        if (_isCut) {
          await directory.delete(recursive: true);
        }
      }

      // Clear clipboard if it was a cut operation
      if (_isCut) {
        clearClipboard();
      }

      return result;
    } catch (e) {
      debugPrint('Error during paste operation: $e');
      return null;
    }
  }

  // Rename a file or folder
  Future<FileSystemEntity?> rename(
      FileSystemEntity entity, String newName) async {
    try {
      final directory = pathlib.dirname(entity.path);
      final newPath = pathlib.join(directory, newName);

      // Check if destination already exists
      bool exists =
          await File(newPath).exists() || await Directory(newPath).exists();

      if (exists) {
        throw const FileSystemException(
            'A file or folder with this name already exists');
      }

      // Perform rename operation
      return await entity.rename(newPath);
    } catch (e) {
      debugPrint('Error during rename operation: $e');
      return null;
    }
  }
}
