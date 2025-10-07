import 'dart:async';
import 'dart:io';
import '../models/objectbox/album.dart';
import '../models/objectbox/album_config.dart';
import 'album_file_scanner.dart';
import 'background_album_processor.dart';
import 'lazy_album_scanner.dart';

class OptimizedAlbumService {
  static OptimizedAlbumService? _instance;
  static OptimizedAlbumService get instance =>
      _instance ??= OptimizedAlbumService._();

  OptimizedAlbumService._();

  final AlbumFileScanner _scanner = AlbumFileScanner.instance;
  final BackgroundAlbumProcessor _processor = BackgroundAlbumProcessor.instance;
  final LazyAlbumScanner _lazyScanner = LazyAlbumScanner.instance;

  // Mock storage - replace with actual ObjectBox implementation
  final List<Album> _albums = [];
  final List<AlbumConfig> _configs = [];

  /// Initialize the service
  Future<void> initialize() async {
    await _processor.startMonitoring();
  }

  /// Create new album with config
  Future<Album> createAlbum({
    required String name,
    String? description,
    required List<String> directories,
    AlbumConfig? config,
  }) async {
    final album = Album(
      name: name,
      description: description,
    );

    // Generate ID (in real implementation, ObjectBox will handle this)
    album.id = _albums.length + 1;
    _albums.add(album);

    // Create config
    final albumConfig = config ?? AlbumConfig(albumId: album.id);
    albumConfig.directoriesList = directories;
    albumConfig.id = _configs.length + 1;
    _configs.add(albumConfig);

    // Start monitoring this album
    await _processor.addAlbumToMonitoring(album.id, directories);

    // Trigger initial scan in background
    _triggerBackgroundScan(album, albumConfig);

    return album;
  }

  /// Get album files (real-time query from disk)
  Future<List<FileInfo>> getAlbumFiles(int albumId) async {
    final album = _albums.firstWhere((a) => a.id == albumId);
    final config = _configs.firstWhere((c) => c.albumId == albumId);

    return await _scanner.scanAlbumFiles(album, config);
  }

  /// Get lazy stream of album files - returns immediately and loads more files progressively
  Stream<List<FileInfo>> getLazyAlbumFiles(int albumId) {
    final album = _albums.firstWhere((a) => a.id == albumId);
    final config = _configs.firstWhere((c) => c.albumId == albumId);

    return _lazyScanner.getLazyAlbumFiles(album, config);
  }

  /// Get immediate files (cached only, no scanning)
  List<FileInfo> getImmediateFiles(int albumId) {
    return _lazyScanner.getImmediateFiles(albumId);
  }

  /// Check if album is currently scanning
  bool isAlbumScanning(int albumId) {
    return _lazyScanner.isScanning(albumId);
  }

  /// Get scan progress (0.0 to 1.0)
  double getAlbumScanProgress(int albumId) {
    final config = _configs.firstWhere((c) => c.albumId == albumId);
    return _lazyScanner.getScanProgress(albumId, config);
  }

  /// Get album config
  AlbumConfig? getAlbumConfig(int albumId) {
    try {
      return _configs.firstWhere((c) => c.albumId == albumId);
    } catch (e) {
      return null;
    }
  }

  /// Update album config
  Future<void> updateAlbumConfig(AlbumConfig config) async {
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      _configs[index] = config;

      // Clear cache to force rescan
      _scanner.clearCache(config.albumId);

      // Refresh monitoring
      await _processor.refreshMonitoring();
    }
  }

  /// Add directories to album
  Future<void> addDirectoriesToAlbum(
      int albumId, List<String> directories) async {
    final config = getAlbumConfig(albumId);
    if (config != null) {
      final currentDirs = config.directoriesList;
      final newDirs = [...currentDirs, ...directories];
      config.directoriesList = newDirs.toSet().toList(); // Remove duplicates

      await updateAlbumConfig(config);

      // Trigger background scan for new directories
      final album = _albums.firstWhere((a) => a.id == albumId);
      _triggerBackgroundScan(album, config);
    }
  }

  /// Remove directories from album
  Future<void> removeDirectoriesFromAlbum(
      int albumId, List<String> directories) async {
    final config = getAlbumConfig(albumId);
    if (config != null) {
      final currentDirs = config.directoriesList;
      final newDirs =
          currentDirs.where((dir) => !directories.contains(dir)).toList();
      config.directoriesList = newDirs;

      await updateAlbumConfig(config);
    }
  }

  /// Get all albums
  Future<List<Album>> getAllAlbums() async {
    return List.from(_albums);
  }

  /// Get album by ID
  Future<Album?> getAlbum(int albumId) async {
    try {
      return _albums.firstWhere((a) => a.id == albumId);
    } catch (e) {
      return null;
    }
  }

  /// Delete album
  Future<void> deleteAlbum(int albumId) async {
    _albums.removeWhere((a) => a.id == albumId);
    _configs.removeWhere((c) => c.albumId == albumId);

    // Stop monitoring
    final config = getAlbumConfig(albumId);
    if (config != null) {
      await _processor.removeAlbumFromMonitoring(config.directoriesList);
    }

    // Clear cache
    _scanner.clearCache(albumId);
  }

  /// Trigger background scan for album
  void _triggerBackgroundScan(Album album, AlbumConfig config) {
    // Run scan in background without blocking UI
    Timer(const Duration(milliseconds: 100), () async {
      try {
        final files = await _scanner.scanAlbumFiles(album, config);
        config.updateScanStats(files.length);
        await updateAlbumConfig(config);
      } catch (e) {
        print('Background scan error for album ${album.name}: $e');
      }
    });
  }

  /// Refresh album (force rescan with lazy loading)
  Future<void> refreshAlbum(int albumId) async {
    // Clear both caches
    _scanner.clearCache(albumId);
    _lazyScanner.refreshAlbum(albumId);

    // Lazy scanner will automatically start loading files progressively
    print('Album $albumId refreshed - files will load progressively');
  }

  /// Get album statistics
  Future<AlbumStats> getAlbumStats(int albumId) async {
    final config = getAlbumConfig(albumId);
    if (config == null) {
      return AlbumStats(fileCount: 0, lastScanTime: null, totalSize: 0);
    }

    // Get current file count (may trigger scan)
    final files = await getAlbumFiles(albumId);
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);

    return AlbumStats(
      fileCount: files.length,
      lastScanTime: config.lastScanTime,
      totalSize: totalSize,
    );
  }

  /// Search files in album
  Future<List<FileInfo>> searchAlbumFiles(int albumId, String query) async {
    final files = await getAlbumFiles(albumId);

    if (query.isEmpty) return files;

    final lowerQuery = query.toLowerCase();
    return files
        .where((file) => file.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get files by type
  Future<List<FileInfo>> getFilesByType(int albumId,
      {bool? imagesOnly, bool? videosOnly}) async {
    final files = await getAlbumFiles(albumId);

    if (imagesOnly == true) {
      return files.where((file) => file.isImage).toList();
    } else if (videosOnly == true) {
      return files.where((file) => file.isVideo).toList();
    }

    return files;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _processor.stopMonitoring();
    _scanner.clearAllCache();
  }
}

class AlbumStats {
  final int fileCount;
  final DateTime? lastScanTime;
  final int totalSize;

  AlbumStats({
    required this.fileCount,
    required this.lastScanTime,
    required this.totalSize,
  });

  String get formattedSize {
    if (totalSize < 1024) return '${totalSize} B';
    if (totalSize < 1024 * 1024)
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024)
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedLastScan {
    if (lastScanTime == null) return 'Never';

    final now = DateTime.now();
    final diff = now.difference(lastScanTime!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
