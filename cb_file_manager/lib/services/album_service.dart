import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/objectbox/album.dart';
import '../models/objectbox/album_file.dart';
import '../models/objectbox/objectbox_database_provider.dart';
import '../objectbox.g.dart';
import '../helpers/core/filesystem_utils.dart';
import 'package:path/path.dart' as path;

/// Service class for managing albums and their file associations
class AlbumService {
  static AlbumService? _instance;
  static AlbumService get instance => _instance ??= AlbumService._();

  final ObjectBoxDatabaseProvider _dbProvider = ObjectBoxDatabaseProvider();

  AlbumService._();

  // Broadcast album update events (albumId) so UI can refresh incrementally
  final StreamController<int> _albumUpdatedController =
      StreamController<int>.broadcast();
  Stream<int> get albumUpdatedStream => _albumUpdatedController.stream;

  // Progress tracking for background operations
  final StreamController<Map<String, dynamic>> _progressController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;

  Future<Store?> _getStore() async {
    await _dbProvider.initialize();
    return _dbProvider.getStore();
  }

  /// Get all albums
  Future<List<Album>> getAllAlbums() async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumBox = store.box<Album>();
      return albumBox.getAll();
    } catch (e) {
      debugPrint('Error getting all albums: $e');
      return [];
    }
  }

  /// Get album by ID
  Future<Album?> getAlbumById(int id) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumBox = store.box<Album>();
      return albumBox.get(id);
    } catch (e) {
      debugPrint('Error getting album by ID $id: $e');
      return null;
    }
  }

  /// Create a new album
  Future<Album?> createAlbum({
    required String name,
    String? description,
    String? coverImagePath,
    String? colorTheme,
  }) async {
    try {
      // Check if album with same name already exists
      final existingAlbums = await getAllAlbums();
      if (existingAlbums
          .any((album) => album.name.toLowerCase() == name.toLowerCase())) {
        throw Exception('Album with name "$name" already exists');
      }

      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumBox = store.box<Album>();

      final album = Album(
        name: name,
        description: description,
        coverImagePath: coverImagePath,
        colorTheme: colorTheme,
      );

      final id = albumBox.put(album);
      album.id = id;

      debugPrint('Created album: ${album.name} with ID: $id');
      return album;
    } catch (e) {
      debugPrint('Error creating album: $e');
      return null;
    }
  }

  /// Update an existing album
  Future<bool> updateAlbum(Album album) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumBox = store.box<Album>();

      album.updateModifiedTime();
      albumBox.put(album);

      debugPrint('Updated album: ${album.name}');
      return true;
    } catch (e) {
      debugPrint('Error updating album: $e');
      return false;
    }
  }

  /// Delete an album and all its file associations
  Future<bool> deleteAlbum(int albumId) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumBox = store.box<Album>();
      final albumFileBox = store.box<AlbumFile>();

      // Delete all file associations first
      final albumFiles = await getAlbumFiles(albumId);
      for (final albumFile in albumFiles) {
        albumFileBox.remove(albumFile.id);
      }

      // Delete the album
      final success = albumBox.remove(albumId);

      debugPrint('Deleted album ID: $albumId, success: $success');
      return success;
    } catch (e) {
      debugPrint('Error deleting album: $e');
      return false;
    }
  }

  /// Get all files in an album
  Future<List<AlbumFile>> getAlbumFiles(int albumId) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumFileBox = store.box<AlbumFile>();

      final query =
          albumFileBox.query(AlbumFile_.albumId.equals(albumId)).build();
      final albumFiles = query.find();
      query.close();

      // Sort by order index
      albumFiles.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      return albumFiles;
    } catch (e) {
      debugPrint('Error getting album files: $e');
      return [];
    }
  }

  /// Add a single file to an album
  Future<bool> addFileToAlbum(int albumId, String filePath,
      {String? caption}) async {
    try {
      // Check if file exists
      if (!await File(filePath).exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Check if file is already in album
      if (await isFileInAlbum(albumId, filePath)) {
        debugPrint('File already exists in album: $filePath');
        return false;
      }

      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumFileBox = store.box<AlbumFile>();

      // Get next order index
      final existingFiles = await getAlbumFiles(albumId);
      final nextOrderIndex =
          existingFiles.isEmpty ? 0 : existingFiles.last.orderIndex + 1;

      final albumFile = AlbumFile(
        albumId: albumId,
        filePath: filePath,
        orderIndex: nextOrderIndex,
        caption: caption,
      );

      albumFileBox.put(albumFile);

      // Update album modified time
      final album = await getAlbumById(albumId);
      if (album != null) {
        await updateAlbum(album);
      }

      debugPrint('Added file to album: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error adding file to album: $e');
      return false;
    }
  }

  /// Add multiple files to an album
  Future<int> addFilesToAlbum(int albumId, List<String> filePaths) async {
    int successCount = 0;

    for (final filePath in filePaths) {
      if (await addFileToAlbum(albumId, filePath)) {
        successCount++;
      }
    }

    debugPrint('Added $successCount out of ${filePaths.length} files to album');
    return successCount;
  }

  /// Add all images from a folder to an album
  Future<int> addFolderToAlbum(int albumId, String folderPath,
      {bool recursive = true}) async {
    try {
      final imageFiles = await getAllImages(folderPath, recursive: recursive);
      final filePaths = imageFiles.map((file) => file.path).toList();
      return await addFilesToAlbum(albumId, filePaths);
    } catch (e) {
      debugPrint('Error adding folder to album: $e');
      return 0;
    }
  }

  /// Add files from directory with detailed result
  Future<Map<String, dynamic>> addFilesFromDirectory(
      int albumId, String directoryPath,
      {bool recursive = true}) async {
    try {
      final imageFiles =
          await getAllImages(directoryPath, recursive: recursive);
      final filePaths = imageFiles.map((file) => file.path).toList();
      final addedCount = await addFilesToAlbum(albumId, filePaths);

      return {
        'total': filePaths.length,
        'added': addedCount,
        'skipped': filePaths.length - addedCount,
      };
    } catch (e) {
      debugPrint('Error adding files from directory: $e');
      return {
        'total': 0,
        'added': 0,
        'skipped': 0,
        'error': e.toString(),
      };
    }
  }

  /// Add files from directory in background with minimal UI updates
  Future<void> addFilesFromDirectoryInBackground(
    int albumId,
    String directoryPath, {
    bool recursive = true,
  }) async {
    try {
      // First, get file list on background isolate to avoid UI freeze
      _progressController.add({
        'albumId': albumId,
        'status': 'scanning',
        'current': 0,
        'total': 0,
      });

      final imageFiles = await compute(_getImageFilesIsolate, {
        'directoryPath': directoryPath,
        'recursive': recursive,
      });

      final totalFiles = imageFiles.length;
      if (totalFiles == 0) {
        _progressController.add({
          'albumId': albumId,
          'status': 'completed',
          'current': 0,
          'total': 0,
        });
        return;
      }

      _progressController.add({
        'albumId': albumId,
        'status': 'processing',
        'current': 0,
        'total': totalFiles,
      });

      // Process files in small batches on main thread to keep UI responsive
      const batchSize = 5;
      int processedFiles = 0;
      int addedCount = 0;

      for (int i = 0; i < imageFiles.length; i += batchSize) {
        final batch = imageFiles.skip(i).take(batchSize).toList();

        // Process batch
        for (final filePath in batch) {
          final added = await addFileToAlbum(albumId, filePath);
          processedFiles++;
          if (added) addedCount++;
        }

        // Update progress after each small batch
        _progressController.add({
          'albumId': albumId,
          'status': 'processing',
          'current': processedFiles,
          'total': totalFiles,
        });

        // Notify UI update after each batch if files were added
        if (addedCount > 0) {
          _albumUpdatedController.add(albumId);
          addedCount = 0; // Reset for next batch
        }

        // Yield to UI thread between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Final updates
      _progressController.add({
        'albumId': albumId,
        'status': 'completed',
        'current': totalFiles,
        'total': totalFiles,
      });

      _albumUpdatedController.add(albumId);
    } catch (e) {
      debugPrint('Error (background) adding files from directory: $e');
      _progressController.add({
        'albumId': albumId,
        'status': 'error',
        'error': e.toString(),
      });
    }
  }

  /// Remove a file from an album
  Future<bool> removeFileFromAlbum(int albumId, String filePath) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumFileBox = store.box<AlbumFile>();

      final query = albumFileBox
          .query(AlbumFile_.albumId.equals(albumId) &
              AlbumFile_.filePath.equals(filePath))
          .build();

      final albumFiles = query.find();
      query.close();

      if (albumFiles.isNotEmpty) {
        albumFileBox.remove(albumFiles.first.id);

        // Update album modified time
        final album = await getAlbumById(albumId);
        if (album != null) {
          await updateAlbum(album);
        }

        debugPrint('Removed file from album: $filePath');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error removing file from album: $e');
      return false;
    }
  }

  /// Check if a file is in an album
  Future<bool> isFileInAlbum(int albumId, String filePath) async {
    try {
      final store = await _getStore();
      if (store == null) throw Exception('Database not initialized');

      final albumFileBox = store.box<AlbumFile>();

      final query = albumFileBox
          .query(AlbumFile_.albumId.equals(albumId) &
              AlbumFile_.filePath.equals(filePath))
          .build();

      final count = query.count();
      query.close();

      return count > 0;
    } catch (e) {
      debugPrint('Error checking if file is in album: $e');
      return false;
    }
  }

  /// Search for image files across the system
  Future<List<File>> searchImageFiles(String searchQuery,
      {String? rootPath}) async {
    try {
      final searchPath = rootPath ?? '/storage/emulated/0';
      final allImages = await getAllImages(searchPath, recursive: true);

      if (searchQuery.trim().isEmpty) {
        return allImages;
      }

      final query = searchQuery.toLowerCase();
      return allImages.where((file) {
        final fileName = path.basename(file.path).toLowerCase();
        final filePath = file.path.toLowerCase();
        return fileName.contains(query) || filePath.contains(query);
      }).toList();
    } catch (e) {
      debugPrint('Error searching image files: $e');
      return [];
    }
  }

  /// Isolate function to get image files without blocking UI
  static Future<List<String>> _getImageFilesIsolate(
      Map<String, dynamic> params) async {
    final directoryPath = params['directoryPath'] as String;
    final recursive = params['recursive'] as bool;

    final imageFiles = await getAllImages(directoryPath, recursive: recursive);
    return imageFiles.map((f) => f.path).toList();
  }
}
