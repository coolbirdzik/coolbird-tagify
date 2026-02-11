import 'dart:io';

import 'package:equatable/equatable.dart';

// Define view modes
enum ViewMode { list, grid, details, gridPreview }

// Define sort options
enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
  typeAsc,
  typeDesc, // Added type descending
  dateCreatedAsc, // Added date created
  dateCreatedDesc, // Added date created descending
  extensionAsc, // Added extension
  extensionDesc, // Added extension descending
  attributesAsc, // Added file attributes
  attributesDesc // Added file attributes descending
}

// Define column visibility options for details view
class ColumnVisibility {
  final bool name;
  final bool size;
  final bool type;
  final bool dateModified;
  final bool dateCreated;
  final bool attributes;

  const ColumnVisibility({
    this.name = true, // Name is always visible by default
    this.size = true,
    this.type = true,
    this.dateModified = true,
    this.dateCreated = false,
    this.attributes = false,
  });

  // Create a copy with modified values
  ColumnVisibility copyWith({
    bool? name,
    bool? size,
    bool? type,
    bool? dateModified,
    bool? dateCreated,
    bool? attributes,
  }) {
    return ColumnVisibility(
      name: name ?? this.name,
      size: size ?? this.size,
      type: type ?? this.type,
      dateModified: dateModified ?? this.dateModified,
      dateCreated: dateCreated ?? this.dateCreated,
      attributes: attributes ?? this.attributes,
    );
  }

  // Convert to map for storage
  Map<String, bool> toMap() {
    return {
      'name': name,
      'size': size,
      'type': type,
      'dateModified': dateModified,
      'dateCreated': dateCreated,
      'attributes': attributes,
    };
  }

  // Create from map
  factory ColumnVisibility.fromMap(Map<String, dynamic> map) {
    return ColumnVisibility(
      name: map['name'] ?? true,
      size: map['size'] ?? true,
      type: map['type'] ?? true,
      dateModified: map['dateModified'] ?? true,
      dateCreated: map['dateCreated'] ?? false,
      attributes: map['attributes'] ?? false,
    );
  }
}

// Define media types for search
enum MediaType { image, video, audio, document }

class FolderListState extends Equatable {
  static const Object _unset = Object();
  final bool isLoading;
  final String? error;
  final Directory currentPath;
  final List<FileSystemEntity> folders;
  final List<FileSystemEntity> files;
  final List<FileSystemEntity> searchResults;
  final bool hasMoreSearchResults;
  final bool isLoadingMoreSearchResults;
  final int? searchResultsTotal;
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
  final int
      clipboardRevision; // Revision counter to trigger rebuild on clipboard changes

  FolderListState(
    String initialPath, {
    this.isLoading = false,
    this.error,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? searchResults,
    this.hasMoreSearchResults = false,
    this.isLoadingMoreSearchResults = false,
    this.searchResultsTotal,
    List<FileSystemEntity>? filteredFiles,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
    this.currentFilter,
    this.currentSearchTag,
    this.currentSearchQuery,
    this.viewMode = ViewMode.list,
    this.sortOption = SortOption.dateDesc,
    this.gridZoomLevel = 3, // Default level for grid view
    Map<String, FileStat>? fileStatsCache,
    this.currentMediaSearch,
    this.isSearchByName = false,
    this.isSearchByMedia = false,
    this.isGlobalSearch = false,
    this.searchRecursive = false,
    this.clipboardRevision = 0,
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
    Object? error = _unset,
    Directory? currentPath,
    List<FileSystemEntity>? folders,
    List<FileSystemEntity>? files,
    List<FileSystemEntity>? searchResults,
    bool? hasMoreSearchResults,
    bool? isLoadingMoreSearchResults,
    Object? searchResultsTotal = _unset,
    List<FileSystemEntity>? filteredFiles,
    Map<String, List<String>>? fileTags,
    Set<String>? allUniqueTags,
    Object? currentFilter = _unset,
    Object? currentSearchTag = _unset,
    Object? currentSearchQuery = _unset,
    ViewMode? viewMode,
    SortOption? sortOption,
    int? gridZoomLevel,
    Map<String, FileStat>? fileStatsCache,
    Object? currentMediaSearch = _unset,
    bool? isSearchByName,
    bool? isSearchByMedia,
    bool? isGlobalSearch,
    bool? searchRecursive,
    int? clipboardRevision,
  }) {
    return FolderListState(
      currentPath?.path ?? this.currentPath.path,
      isLoading: isLoading ?? this.isLoading,
      error: error == _unset ? this.error : error as String?,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      searchResults: searchResults ?? this.searchResults,
      hasMoreSearchResults: hasMoreSearchResults ?? this.hasMoreSearchResults,
      isLoadingMoreSearchResults:
          isLoadingMoreSearchResults ?? this.isLoadingMoreSearchResults,
      searchResultsTotal: searchResultsTotal == _unset
          ? this.searchResultsTotal
          : searchResultsTotal as int?,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      fileTags: fileTags ?? this.fileTags,
      allUniqueTags: allUniqueTags ?? this.allUniqueTags,
      currentFilter: currentFilter == _unset
          ? this.currentFilter
          : currentFilter as String?,
      currentSearchTag: currentSearchTag == _unset
          ? this.currentSearchTag
          : currentSearchTag as String?,
      currentSearchQuery: currentSearchQuery == _unset
          ? this.currentSearchQuery
          : currentSearchQuery as String?,
      viewMode: viewMode ?? this.viewMode,
      sortOption: sortOption ?? this.sortOption,
      gridZoomLevel: gridZoomLevel ?? this.gridZoomLevel,
      fileStatsCache: fileStatsCache ?? this.fileStatsCache,
      currentMediaSearch: currentMediaSearch == _unset
          ? this.currentMediaSearch
          : currentMediaSearch as MediaType?,
      isSearchByName: isSearchByName ?? this.isSearchByName,
      isSearchByMedia: isSearchByMedia ?? this.isSearchByMedia,
      isGlobalSearch: isGlobalSearch ?? this.isGlobalSearch,
      searchRecursive: searchRecursive ?? this.searchRecursive,
      clipboardRevision: clipboardRevision ?? this.clipboardRevision,
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
        hasMoreSearchResults,
        isLoadingMoreSearchResults,
        searchResultsTotal,
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
        // NOTE: clipboardRevision is intentionally excluded from props
        // to prevent full rebuild when clipboard changes (copy/cut operations)
        // Only items affected by cut should show visual feedback
      ];
}
