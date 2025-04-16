import 'dart:io';

import 'package:equatable/equatable.dart';

// Define view modes
enum ViewMode { list, grid }

// Define sort options
enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
  typeAsc
}

// Define media types for search
enum MediaType { image, video, audio, document }

class FolderListState extends Equatable {
  final bool isLoading;
  final String? error;
  final Directory currentPath;
  final List<FileSystemEntity> folders;
  final List<FileSystemEntity> files;
  final List<FileSystemEntity> searchResults;
  final List<FileSystemEntity> filteredFiles;
  final Map<String, List<String>> fileTags;
  final Set<String> allUniqueTags; // All unique tags found in the directory
  final String? currentFilter; // Current filter for file types
  final String? currentSearchTag; // The tag being searched for
  final String? currentSearchQuery; // Text query for file search
  final ViewMode viewMode;
  final SortOption sortOption;
  final int gridZoomLevel;
  final Map<String, FileStat>
      fileStatsCache; // Cache for file stats to improve performance
  final MediaType? currentMediaSearch; // For media searches
  final bool isSearchByName; // Flag for search by name operations
  final bool isSearchByMedia; // Flag for search by media type
  final bool isGlobalSearch; // Flag for global tag searches
  final bool searchRecursive; // Flag for recursive search operations

  FolderListState(
    String initialPath, {
    this.isLoading = false,
    this.error,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? searchResults,
    List<FileSystemEntity>? filteredFiles,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
    this.currentFilter,
    this.currentSearchTag,
    this.currentSearchQuery,
    this.viewMode = ViewMode.list,
    this.sortOption = SortOption.nameAsc,
    this.gridZoomLevel = 3, // Default level for grid view
    Map<String, FileStat>? fileStatsCache,
    this.currentMediaSearch,
    this.isSearchByName = false,
    this.isSearchByMedia = false,
    this.isGlobalSearch = false,
    this.searchRecursive = false,
  })  : currentPath = Directory(initialPath),
        folders = folders ?? [],
        files = files ?? [],
        searchResults = searchResults ?? [],
        filteredFiles = filteredFiles ?? [],
        fileTags = fileTags ?? {},
        allUniqueTags = allUniqueTags ?? {},
        fileStatsCache = fileStatsCache ?? {};

  // Helper getters
  List<String> get allTags => allUniqueTags.toList();
  bool get isSearchActive =>
      currentSearchTag != null || currentSearchQuery != null;

  // Helper method to get tags for a specific file
  List<String> getTagsForFile(String filePath) {
    return fileTags[filePath] ?? [];
  }

  // Create a new state with updated fields
  FolderListState copyWith({
    bool? isLoading,
    String? error,
    Directory? currentPath,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? searchResults,
    List<FileSystemEntity>? filteredFiles,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
    String? currentFilter,
    String? currentSearchTag,
    String? currentSearchQuery,
    ViewMode? viewMode,
    SortOption? sortOption,
    int? gridZoomLevel,
    Map<String, FileStat>? fileStatsCache,
    MediaType? currentMediaSearch,
    bool? isSearchByName,
    bool? isSearchByMedia,
    bool? isGlobalSearch,
    bool? searchRecursive,
  }) {
    return FolderListState(
      currentPath?.path ?? this.currentPath.path,
      isLoading: isLoading ?? this.isLoading,
      error:
          error, // Not using "?? this.error" to allow clearing errors by passing null
      folders: folders ?? this.folders,
      files: files ?? this.files,
      searchResults: searchResults ?? this.searchResults,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      fileTags: fileTags ?? this.fileTags,
      allUniqueTags: allUniqueTags ?? this.allUniqueTags,
      currentFilter: currentFilter, // Allow clearing by passing null
      currentSearchTag: currentSearchTag, // Allow clearing by passing null
      currentSearchQuery: currentSearchQuery, // Allow clearing by passing null
      viewMode: viewMode ?? this.viewMode,
      sortOption: sortOption ?? this.sortOption,
      gridZoomLevel: gridZoomLevel ?? this.gridZoomLevel,
      fileStatsCache: fileStatsCache ?? this.fileStatsCache,
      currentMediaSearch: currentMediaSearch, // Allow clearing by passing null
      isSearchByName: isSearchByName ?? this.isSearchByName,
      isSearchByMedia: isSearchByMedia ?? this.isSearchByMedia,
      isGlobalSearch: isGlobalSearch ?? this.isGlobalSearch,
      searchRecursive: searchRecursive ?? this.searchRecursive,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        currentPath.path,
        folders,
        files,
        searchResults,
        filteredFiles,
        fileTags,
        allUniqueTags,
        currentFilter,
        currentSearchTag,
        currentSearchQuery,
        viewMode,
        sortOption,
        gridZoomLevel,
        currentMediaSearch,
        isSearchByName,
        isSearchByMedia,
        isGlobalSearch,
        searchRecursive,
      ];
}
