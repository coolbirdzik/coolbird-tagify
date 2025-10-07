import 'package:objectbox/objectbox.dart';

/// Entity class for storing album configuration in ObjectBox
@Entity()
class AlbumConfig {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Album ID this config belongs to
  @Index()
  int albumId;

  /// Include subdirectories when scanning
  bool includeSubdirectories;

  /// Supported file extensions (comma-separated)
  String fileExtensions;

  /// Auto refresh when directory changes
  bool autoRefresh;

  /// Maximum number of files to include
  int maxFileCount;

  /// Sort files by: 'name', 'date', 'size'
  String sortBy;

  /// Sort in ascending order
  bool sortAscending;

  /// Exclude patterns (comma-separated regex patterns)
  String excludePatterns;

  /// Enable auto rules for this album
  bool enableAutoRules;

  /// Directories to scan (comma-separated paths)
  String directories;

  /// Last scan timestamp
  DateTime? lastScanTime;

  /// Number of files found in last scan
  int fileCount;

  /// Creates a new album config
  AlbumConfig({
    required this.albumId,
    this.includeSubdirectories = true,
    this.fileExtensions = '.jpg,.jpeg,.png,.gif,.bmp,.webp,.tiff,.tif,.mp4,.avi,.mov,.wmv,.flv,.webm,.mkv,.m4v',
    this.autoRefresh = true,
    this.maxFileCount = 10000,
    this.sortBy = 'date',
    this.sortAscending = false,
    this.excludePatterns = '',
    this.enableAutoRules = true,
    this.directories = '',
    this.lastScanTime,
    this.fileCount = 0,
  });

  /// Get file extensions as list
  List<String> get fileExtensionsList {
    if (fileExtensions.isEmpty) return [];
    return fileExtensions.split(',').map((e) => e.trim()).toList();
  }

  /// Set file extensions from list
  set fileExtensionsList(List<String> extensions) {
    fileExtensions = extensions.join(',');
  }

  /// Get exclude patterns as list
  List<String> get excludePatternsList {
    if (excludePatterns.isEmpty) return [];
    return excludePatterns.split(',').map((e) => e.trim()).toList();
  }

  /// Set exclude patterns from list
  set excludePatternsList(List<String> patterns) {
    excludePatterns = patterns.join(',');
  }

  /// Get directories as list
  List<String> get directoriesList {
    if (directories.isEmpty) return [];
    return directories.split(',').map((e) => e.trim()).toList();
  }

  /// Set directories from list
  set directoriesList(List<String> dirs) {
    directories = dirs.join(',');
  }

  /// Update scan statistics
  void updateScanStats(int foundFileCount) {
    lastScanTime = DateTime.now();
    fileCount = foundFileCount;
  }

  /// Creates a copy of this config with updated fields
  AlbumConfig copyWith({
    int? albumId,
    bool? includeSubdirectories,
    String? fileExtensions,
    bool? autoRefresh,
    int? maxFileCount,
    String? sortBy,
    bool? sortAscending,
    String? excludePatterns,
    bool? enableAutoRules,
    String? directories,
    DateTime? lastScanTime,
    int? fileCount,
  }) {
    return AlbumConfig(
      albumId: albumId ?? this.albumId,
      includeSubdirectories: includeSubdirectories ?? this.includeSubdirectories,
      fileExtensions: fileExtensions ?? this.fileExtensions,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      maxFileCount: maxFileCount ?? this.maxFileCount,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      enableAutoRules: enableAutoRules ?? this.enableAutoRules,
      directories: directories ?? this.directories,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      fileCount: fileCount ?? this.fileCount,
    )..id = id;
  }

  @override
  String toString() {
    return 'AlbumConfig{id: $id, albumId: $albumId, '
           'includeSubdirectories: $includeSubdirectories, '
           'autoRefresh: $autoRefresh, fileCount: $fileCount}';
  }
}
