import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:path/path.dart' as pathlib;

import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListBloc extends Bloc<FolderListEvent, FolderListState> {
  FolderListBloc() : super(FolderListState("/")) {
    on<FolderListInit>(_onFolderListInit);
    on<FolderListLoad>(_onFolderListLoad);
    on<FolderListFilter>(_onFolderListFilter);
    on<AddTagToFile>(_onAddTagToFile);
    on<RemoveTagFromFile>(_onRemoveTagFromFile);
    on<SearchByTag>(_onSearchByTag);
    on<SearchByTagGlobally>(_onSearchByTagGlobally);
    on<SearchByFileName>(_onSearchByFileName);
    on<SearchMediaFiles>(_onSearchMediaFiles);
    on<LoadTagsFromFile>(_onLoadTagsFromFile);
    on<LoadAllTags>(_onLoadAllTags);
    on<SetViewMode>(_onSetViewMode);
    on<SetSortOption>(_onSetSortOption);
    on<SetGridZoom>(_onSetGridZoom);
    on<ClearSearchAndFilters>(_onClearSearchAndFilters);
    on<FolderListDeleteFiles>(_onFolderListDeleteFiles);
    on<SetTagSearchResults>(
        _onSetTagSearchResults); // Add this line to register the event handler
  }

  @override
  Stream<FolderListState> mapEventToState(FolderListEvent event) async* {
    if (event is SetTagSearchResults) {
      yield state.copyWith(
        searchResults: event.results,
        currentSearchTag: event.tagName,
        isLoading: false,
      );
    }
  }

  void _onFolderListInit(
      FolderListInit event, Emitter<FolderListState> emit) async {
    // Initialize with empty folders list
    emit(state.copyWith(isLoading: true));
    emit(state.copyWith(isLoading: false));
  }

  void _onFolderListLoad(
      FolderListLoad event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      currentPath: Directory(event.path),
    ));

    // Special case for empty path on Windows - this is used for the drive listing view
    if (event.path.isEmpty && Platform.isWindows) {
      emit(state.copyWith(
          isLoading: false, folders: [], files: [], error: null));
      return;
    }

    try {
      final directory = Directory(event.path);
      if (await directory.exists()) {
        try {
          List<FileSystemEntity> contents = await directory.list().toList();

          // Separate folders and files
          final List<FileSystemEntity> folders = [];
          final List<FileSystemEntity> files = [];

          for (var entity in contents) {
            if (entity is Directory) {
              folders.add(entity);
            } else if (entity is File) {
              // Skip tag files - no longer needed with global tags
              if (!entity.path.endsWith('.tags')) {
                files.add(entity);
              }
            }
          }

          // Load tags for all files
          Map<String, List<String>> fileTags = {};
          for (var file in files) {
            if (file is File) {
              final tags = await TagManager.getTags(file.path);
              if (tags.isNotEmpty) {
                fileTags[file.path] = tags;
              }
            }
          }

          emit(state.copyWith(
            isLoading: false,
            folders: folders,
            files: files,
            fileTags: fileTags,
            error: null, // Clear any previous errors
          ));

          // Load all unique tags in this directory (async)
          add(LoadAllTags(event.path));
        } catch (e) {
          // Handle specific permission errors
          if (e.toString().toLowerCase().contains('permission denied') ||
              e.toString().toLowerCase().contains('access denied')) {
            emit(state.copyWith(
              isLoading: false,
              error:
                  "Access denied: Administrator privileges required to access ${event.path}",
              folders: [],
              files: [],
            ));
          } else {
            emit(state.copyWith(
              isLoading: false,
              error: "Error accessing directory: ${e.toString()}",
              folders: [],
              files: [],
            ));
          }
        }
      } else {
        emit(state.copyWith(
            isLoading: false, error: "Directory does not exist"));
      }
    } catch (e) {
      // Improved error handling with user-friendly messages
      if (e.toString().toLowerCase().contains('permission denied') ||
          e.toString().toLowerCase().contains('access denied')) {
        emit(state.copyWith(
          isLoading: false,
          error:
              "Access denied: Administrator privileges required to access ${event.path}",
          folders: [],
          files: [],
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: "Error: ${e.toString()}",
          folders: [],
          files: [],
        ));
      }
    }
  }

  void _onFolderListFilter(
      FolderListFilter event, Emitter<FolderListState> emit) async {
    // Filter files by type (videos, images, etc.)
    if (event.fileType == null) {
      emit(state.copyWith(currentFilter: null, filteredFiles: []));
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      currentFilter: event.fileType,
    ));

    try {
      final List<FileSystemEntity> filteredFiles = state.files.where((file) {
        if (file is File) {
          String extension = file.path.split('.').last.toLowerCase();
          switch (event.fileType) {
            case 'image':
              return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
                  .contains(extension);
            case 'video':
              return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv']
                  .contains(extension);
            case 'audio':
              return ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
                  .contains(extension);
            case 'document':
              return ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
                  .contains(extension);
            default:
              return true;
          }
        }
        return false;
      }).toList();

      emit(state.copyWith(
        isLoading: false,
        filteredFiles: filteredFiles,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onAddTagToFile(
      AddTagToFile event, Emitter<FolderListState> emit) async {
    try {
      // Use TagManager to add the tag
      final success = await TagManager.addTag(event.filePath, event.tag);

      if (success) {
        // Update state with new tags
        final tags = await TagManager.getTags(event.filePath);

        // Create a copy of the current fileTags map
        final Map<String, List<String>> updatedFileTags =
            Map.from(state.fileTags);
        updatedFileTags[event.filePath] = tags;

        emit(state.copyWith(fileTags: updatedFileTags));

        // Also update all unique tags
        final currentDir = state.currentPath.path;
        add(LoadAllTags(currentDir));
      }
    } catch (e) {
      emit(state.copyWith(error: "Error adding tag: ${e.toString()}"));
    }
  }

  void _onRemoveTagFromFile(
      RemoveTagFromFile event, Emitter<FolderListState> emit) async {
    try {
      // Use TagManager to remove the tag
      final success = await TagManager.removeTag(event.filePath, event.tag);

      if (success) {
        // Update state with new tags
        final tags = await TagManager.getTags(event.filePath);

        // Create a copy of the current fileTags map
        final Map<String, List<String>> updatedFileTags =
            Map.from(state.fileTags);

        if (tags.isEmpty) {
          updatedFileTags.remove(event.filePath);
        } else {
          updatedFileTags[event.filePath] = tags;
        }

        emit(state.copyWith(fileTags: updatedFileTags));

        // Also update all unique tags
        final currentDir = state.currentPath.path;
        add(LoadAllTags(currentDir));
      }
    } catch (e) {
      emit(state.copyWith(error: "Error removing tag: ${e.toString()}"));
    }
  }

  void _onSearchByTag(SearchByTag event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      isSearchByName: false,
      isGlobalSearch: false,
    ));

    try {
      // Use TagManager to search for files with the given tag within current directory
      final matchingFiles =
          await TagManager.findFilesByTag(state.currentPath.path, event.tag);

      emit(state.copyWith(
        isLoading: false,
        searchResults: matchingFiles,
        currentSearchTag: event.tag,
        currentSearchQuery: null,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, error: "Error searching by tag: ${e.toString()}"));
    }
  }

  void _onSearchByTagGlobally(
      SearchByTagGlobally event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      isSearchByName: false,
      isGlobalSearch: true,
    ));

    try {
      // Use TagManager to search for files with the given tag across all directories
      final matchingFiles = await TagManager.findFilesByTagGlobally(event.tag);

      emit(state.copyWith(
        isLoading: false,
        searchResults: matchingFiles,
        currentSearchTag: event.tag,
        currentSearchQuery: null,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          error: "Error searching by tag globally: ${e.toString()}"));
    }
  }

  void _onSearchByFileName(
      SearchByFileName event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      isSearchByName: true,
    ));

    try {
      final String query = event.query.toLowerCase();
      final String path = state.currentPath.path;
      final List<FileSystemEntity> matchingFiles = [];

      // Function to search directory for matching files và thư mục
      Future<void> searchDirectory(String dirPath, bool recursive) async {
        final Directory dir = Directory(dirPath);
        if (!await dir.exists()) return;

        await for (var entity in dir.list(recursive: recursive)) {
          final String name = pathlib.basename(entity.path).toLowerCase();
          if (name.contains(query)) {
            matchingFiles.add(entity);
          }
        }
      }

      // Perform search
      await searchDirectory(path, event.recursive);

      emit(state.copyWith(
        isLoading: false,
        searchResults: matchingFiles,
        currentSearchQuery: event.query,
        currentSearchTag: null,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, error: "Error searching files: ${e.toString()}"));
    }
  }

  void _onSearchMediaFiles(
      SearchMediaFiles event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(
      isLoading: true,
      isSearchByMedia: true,
      isSearchByName: false,
      searchRecursive: event.recursive,
      currentMediaSearch: _convertMediaSearchTypeToMediaType(event.mediaType),
      currentSearchTag: null,
      currentSearchQuery: null,
    ));

    try {
      final String path = state.currentPath.path;
      final List<FileSystemEntity> matchingFiles = [];

      // Define media type extensions
      List<String> targetExtensions = [];
      String mediaTypeLabel = '';

      // Set up the file extensions to search for based on media type
      switch (event.mediaType) {
        case MediaSearchType.images:
          targetExtensions = [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
            'heic',
            'heif'
          ];
          mediaTypeLabel = 'images';
          break;
        case MediaSearchType.videos:
          targetExtensions = [
            'mp4',
            'mov',
            'avi',
            'mkv',
            'flv',
            'wmv',
            'webm',
            '3gp',
            'm4v'
          ];
          mediaTypeLabel = 'videos';
          break;
        case MediaSearchType.all:
          targetExtensions = [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
            'heic',
            'heif',
            'mp4',
            'mov',
            'avi',
            'mkv',
            'flv',
            'wmv',
            'webm',
            '3gp',
            'm4v'
          ];
          mediaTypeLabel = 'media files';
          break;
      }

      // Function to search directory for matching files
      Future<void> searchDirectory(String dirPath, bool recursive) async {
        final Directory dir = Directory(dirPath);
        if (!await dir.exists()) return;

        await for (var entity in dir.list(recursive: recursive)) {
          if (entity is File) {
            final String extension = entity.path.split('.').last.toLowerCase();
            if (targetExtensions.contains(extension)) {
              matchingFiles.add(entity);
            }
          }
        }
      }

      // Perform search
      await searchDirectory(path, event.recursive);

      emit(state.copyWith(
        isLoading: false,
        searchResults: matchingFiles,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          error: "Error searching media files: ${e.toString()}"));
    }
  }

  // Helper method to convert MediaSearchType to MediaType
  MediaType _convertMediaSearchTypeToMediaType(MediaSearchType searchType) {
    switch (searchType) {
      case MediaSearchType.images:
        return MediaType.image;
      case MediaSearchType.videos:
        return MediaType.video;
      case MediaSearchType.audio:
        return MediaType.audio; // Handle the audio case
      case MediaSearchType.all:
        return MediaType.image; // Default to image type when searching all
    }
  }

  void _onLoadTagsFromFile(
      LoadTagsFromFile event, Emitter<FolderListState> emit) async {
    try {
      final tags = await TagManager.getTags(event.filePath);

      // Only update if we have tags
      if (tags.isNotEmpty) {
        Map<String, List<String>> updatedFileTags = Map.from(state.fileTags);
        updatedFileTags[event.filePath] = tags;

        emit(state.copyWith(fileTags: updatedFileTags));
      }
    } catch (e) {
      print('Error loading tags for file: ${e.toString()}');
    }
  }

  void _onLoadAllTags(LoadAllTags event, Emitter<FolderListState> emit) async {
    try {
      // Get all unique tags across the entire file system (globally)
      final Set<String> allTags =
          await TagManager.getAllUniqueTags(event.directory);
      emit(state.copyWith(allUniqueTags: allTags));
    } catch (e) {
      print('Error loading all tags: ${e.toString()}');
    }
  }

  void _onSetViewMode(SetViewMode event, Emitter<FolderListState> emit) {
    emit(state.copyWith(viewMode: event.viewMode));
  }

  void _onSetGridZoom(SetGridZoom event, Emitter<FolderListState> emit) {
    // Update the grid zoom level
    emit(state.copyWith(gridZoomLevel: event.zoomLevel));
  }

  void _onSetSortOption(
      SetSortOption event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Get file stats for sorting
      Map<String, FileStat> fileStatsCache = {};

      // Create new sorted lists by copying the original lists
      List<FileSystemEntity> sortedFolders = List.from(state.folders);
      List<FileSystemEntity> sortedFiles = List.from(state.files);
      List<FileSystemEntity> sortedFilteredFiles =
          List.from(state.filteredFiles);
      List<FileSystemEntity> sortedSearchResults =
          List.from(state.searchResults);

      // Cache file stats for better performance
      Future<void> cacheFileStats(List<FileSystemEntity> entities) async {
        for (var entity in entities) {
          if (!fileStatsCache.containsKey(entity.path)) {
            fileStatsCache[entity.path] = await entity.stat();
          }
        }
      }

      // Wait for all file stats to be loaded
      await Future.wait([
        cacheFileStats(sortedFolders),
        cacheFileStats(sortedFiles),
        cacheFileStats(sortedFilteredFiles),
        cacheFileStats(sortedSearchResults),
      ]);

      // Define the sorting function based on the selected sort option
      int Function(FileSystemEntity, FileSystemEntity) compareFunction;

      switch (event.sortOption) {
        case SortOption.nameAsc:
          compareFunction = (a, b) => pathlib
              .basename(a.path)
              .toLowerCase()
              .compareTo(pathlib.basename(b.path).toLowerCase());
          break;
        case SortOption.nameDesc:
          compareFunction = (a, b) => pathlib
              .basename(b.path)
              .toLowerCase()
              .compareTo(pathlib.basename(a.path).toLowerCase());
          break;
        case SortOption.dateAsc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            return aStats.modified.compareTo(bStats.modified);
          };
          break;
        case SortOption.dateDesc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            return bStats.modified.compareTo(aStats.modified);
          };
          break;
        case SortOption.sizeAsc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            return aStats.size.compareTo(bStats.size);
          };
          break;
        case SortOption.sizeDesc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            return bStats.size.compareTo(aStats.size);
          };
          break;
        case SortOption.typeAsc:
          compareFunction = (a, b) {
            final aExt = a.path.split('.').last.toLowerCase();
            final bExt = b.path.split('.').last.toLowerCase();
            return aExt.compareTo(bExt);
          };
          break;
        default:
          compareFunction = (a, b) => pathlib
              .basename(a.path)
              .toLowerCase()
              .compareTo(pathlib.basename(b.path).toLowerCase());
      }

      // Sort folders and files separately
      sortedFolders.sort(compareFunction);
      sortedFiles.sort(compareFunction);
      sortedFilteredFiles.sort(compareFunction);
      sortedSearchResults.sort(compareFunction);

      // Emit the new state with sorted lists and the updated sort option
      emit(state.copyWith(
        isLoading: false,
        sortOption: event.sortOption,
        folders: sortedFolders,
        files: sortedFiles,
        filteredFiles: sortedFilteredFiles,
        searchResults: sortedSearchResults,
        fileStatsCache: fileStatsCache,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, error: "Error sorting files: ${e.toString()}"));
    }
  }

  void _onClearSearchAndFilters(
      ClearSearchAndFilters event, Emitter<FolderListState> emit) {
    // Reset all search and filter related state variables
    emit(state.copyWith(
      currentSearchTag: null,
      currentSearchQuery: null,
      currentFilter: null,
      searchResults: [],
      filteredFiles: [],
      isSearchByName: false,
      isSearchByMedia: false,
      isGlobalSearch: false,
      searchRecursive: false,
      currentMediaSearch: null,
      error: null, // Also clear any previous error messages
    ));
  }

  void _onFolderListDeleteFiles(
      FolderListDeleteFiles event, Emitter<FolderListState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      List<String> failedDeletes = [];

      for (var filePath in event.filePaths) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          failedDeletes.add(filePath);
          print('Error deleting file $filePath: $e');
        }
      }

      if (failedDeletes.isNotEmpty) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Failed to delete ${failedDeletes.length} files',
        ));
      }

      // Refresh the current directory
      add(FolderListLoad(state.currentPath.path));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Error deleting files: ${e.toString()}',
      ));
    }
  }

  void _onSetTagSearchResults(
      SetTagSearchResults event, Emitter<FolderListState> emit) {
    // Update the state with tag search results
    emit(state.copyWith(
      searchResults: event.results,
      currentSearchTag: event.tagName,
      isLoading: false,
      isSearchByName: false,
      isGlobalSearch: false,
      currentSearchQuery: null,
    ));
  }
}
