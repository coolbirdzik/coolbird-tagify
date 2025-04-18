// dart
import 'dart:async';
import 'dart:io';

// packages
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as pathlib;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// local files
import 'io_extensions.dart';

String storageRootPath = "/storage/emulated/0/";

enum Sorting { Type, Size, Date, Alpha, TypeDate, TypeSize }

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
  print("storage_helper->getExternalStorageWithoutDataDir: " +
      packageInfo.packageName);
  String subPath =
      pathlib.join("Android", "data", packageInfo.packageName, "files");
  if (unfilteredPath.contains(subPath)) {
    String filteredPath = unfilteredPath.split(subPath).first;
    print("storage_helper->getExternalStorageWithoutDataDir: " + filteredPath);
    return Directory(filteredPath);
  } else {
    return Directory(unfilteredPath);
  }
}

/// keepHidden: show files that start with .
Future<List<FileSystemEntity>> getFoldersAndFiles(String path,
    {changeCurrentPath = true,
    Sorting sortedBy = Sorting.Type,
    reverse = false,
    recursive = false,
    keepHidden = false}) async {
  Directory _path = Directory(path);
  List<FileSystemEntity> _files = [];
  try {
    _files = await _path.list(recursive: recursive).toList();

    // Create a new list to avoid type issues
    List<FileSystemEntity> _typedFiles = [];

    for (var fsEntity in _files) {
      String fsPath = fsEntity.path.toString();
      if (FileSystemEntity.isDirectorySync(fsPath)) {
        _typedFiles.add(Directory(fsEntity.absolute.path.toString()));
      } else {
        _typedFiles.add(File(fsEntity.absolute.path.toString()));
      }
    }

    _files = _typedFiles;

    // Removing hidden files & folders from the list
    if (!keepHidden) {
      print("filesystem->getFoldersAndFiles: excluding hidden");
      _files.removeWhere((FileSystemEntity test) {
        return test.basename().startsWith('.') == true;
      });
    }
  } on FileSystemException catch (e) {
    print(e);
    return [];
  }
  return sort(_files, sortedBy, reverse: reverse);
}

/// keepHidden: show files that start with .
Stream<List<FileSystemEntity>> fileStream(String path,
    {changeCurrentPath = true,
    Sorting sortedBy = Sorting.Type,
    reverse = false,
    recursive = false,
    keepHidden = false}) async* {
  Directory _path = Directory(path);
  List<FileSystemEntity> _files = []; // Use list literal
  try {
    // Checking if the target directory contains files inside or not!
    // so that [StreamBuilder] won't emit the same old data if there are
    // no elements inside that directory.
    if (_path.listSync(recursive: recursive).length != 0) {
      if (!keepHidden) {
        yield* _path.list(recursive: recursive).transform(
            StreamTransformer.fromHandlers(
                handleData: (FileSystemEntity data, sink) {
          debugPrint("filsytem_utils -> fileStream: $data");
          _files.add(data);
          sink.add(_files);
        }));
      } else {
        yield* _path.list(recursive: recursive).transform(
            StreamTransformer.fromHandlers(
                handleData: (FileSystemEntity data, sink) {
          debugPrint("filsytem_utils -> fileStream: $data");
          if (data.basename().startsWith('.')) {
            _files.add(data);
            sink.add(_files);
          }
        }));
      }
    } else {
      yield [];
    }
  } on FileSystemException catch (e) {
    print(e);
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
      print(
          "Found matching entity: ${entity.path}, type: ${entity is Directory ? 'Directory' : 'File'}");
    }

    return matches;
  }).toList();

  int end = DateTime.now().millisecondsSinceEpoch;
  print(
      "Search completed in ${end - start} ms, found ${results.length} items (${results.where((e) => e is Directory).length} directories)");

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
  print("filesystem_utils->createFolderByPath: $folderName @ $path");
  var _directory;

  _directory = Directory(pathlib.join(path, folderName ?? ''));

  try {
    if (!_directory.existsSync()) {
      _directory.create();
    } else {
      throw FileSystemException("File already exists");
    }
    return _directory;
  } catch (e) {
    throw FileSystemException(e.toString());
  }
}

/// This function returns every [Directory] in th path
List<Directory> splitPathToDirectories(String path) {
  List<Directory> splittedPath = []; // Use list literal
  Directory pathDir = Directory(path);
  splittedPath.add(pathDir);
  for (var item in pathlib.split(path)) {
    splittedPath.add(pathDir.parent);
    pathDir = pathDir.parent;
  }
  return splittedPath.reversed.toList();
}

Future<List<FileSystemEntity>> sort(List<FileSystemEntity> elements, Sorting by,
    {bool reverse = false}) async {
  try {
    switch (by) {
      case Sorting.Type:
        if (!reverse)
          return elements
            ..sort((f1, f2) {
              bool isDir1 =
                  FileSystemEntity.isDirectorySync(f1.path.toString());
              bool isDir2 =
                  FileSystemEntity.isDirectorySync(f2.path.toString());
              return isDir1 == isDir2 ? 0 : (isDir1 ? -1 : 1);
            });
        else
          return (elements..sort()).reversed.toList();
      default:
        return elements..sort();
    }
  } catch (e) {
    print(e);
    return [];
  }
}

/// Get all available drives on Windows systems
/// Returns a list of directories representing each drive
/// Now also detects drives that require admin privileges
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
          print('Found accessible drive: $drivePath');
        } catch (permissionError) {
          // Drive exists but we don't have permission
          // Create a special metadata property to mark as protected
          drive = Directory(drivePath);
          drives.add(drive);
          // Add a "tag" to mark this as a protected drive
          drive.setProperty('requiresAdmin', true);
          print('Found protected drive: $drivePath (requires admin)');
        }
      }
    } catch (e) {
      // Ignore drives that can't be accessed or don't exist
      print('Drive not found or cannot be accessed: $drivePath - $e');
    }
  }

  return drives;
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
    print('Error listing /storage directory: $e');
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
          print('Found additional storage location: ${dir.path}');
        } catch (accessError) {
          // Path exists but we can't list files (no permission)
          print('Storage path exists but not accessible: $path');
        }
      }
    } catch (e) {
      // Path doesn't exist or other error
      print('Storage path not found or error: $path - $e');
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
        print('Error getting standard Android storage: $e');
      }

      // Try to add additional Android paths
      try {
        storageLocations.addAll(await getAdditionalAndroidPaths());
      } catch (e) {
        print('Error getting additional Android paths: $e');
      }
    } else {
      // For other platforms, fallback to application documents directory
      Directory appDocDir = await getApplicationDocumentsDirectory();
      storageLocations.add(appDocDir);
    }
  } catch (e) {
    print('Error getting storage locations: $e');
    // Fallback to app documents directory
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      storageLocations.add(appDocDir);
    } catch (e) {
      print('Error getting application documents directory: $e');
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

  // Filter for video files based on common video extensions
  List<String> videoExtensions = [
    '.mp4',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.mkv',
    '.webm',
    '.m4v',
    '.mpg',
    '.mpeg',
    '.3gp'
  ];

  List<File> videoFiles = allFiles.whereType<File>().where((file) {
    String extension = pathlib.extension(file.path).toLowerCase();
    return videoExtensions.contains(extension);
  }).toList();

  return videoFiles;
}

/// Recursively get all images in a directory and its subdirectories
Future<List<File>> getAllImages(String path, {bool recursive = true}) async {
  List<FileSystemEntity> allFiles =
      await getFoldersAndFiles(path, recursive: recursive);

  // Filter for image files based on common image extensions
  List<String> imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.tiff',
    '.ico',
    '.heic'
  ];

  List<File> imageFiles = allFiles.whereType<File>().where((file) {
    String extension = pathlib.extension(file.path).toLowerCase();
    return imageExtensions.contains(extension);
  }).toList();

  return imageFiles;
}
