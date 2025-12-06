import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/helpers/files/trash_manager.dart'; // Add import for TrashManager
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart'; // Import for FileOperations
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/core/text_utils.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'dart:async'; // Thêm import cho StreamSubscription
import 'package:cb_file_manager/helpers/files/folder_sort_manager.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import 'package:cb_file_manager/services/permission_state_service.dart';
import 'package:cb_file_manager/helpers/core/filesystem_sorter.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';

import 'folder_list_event.dart';
import 'folder_list_state.dart';

import 'package:cb_file_manager/config/languages/english_localizations.dart';

// Error message helper class using localization
// Usage: Get the localized message from UI layer using AppLocalizations.of(context)
// and pass the appropriate parameters
class SearchErrorMessages {
  // Helper methods to get localized messages
  // Currently defaults to English as BLoC doesn't have context
  static final _defaultLocalizations = EnglishLocalizations();
  
  static String noFilesFoundTag(String tag) {
    return _defaultLocalizations.noFilesFoundTag({'tag': tag});
  }

  static String noFilesFoundTagGlobal(String tag) {
    return _defaultLocalizations.noFilesFoundTagGlobal({'tag': tag});
  }

  static String noFilesFoundTags(String tags) {
    return _defaultLocalizations.noFilesFoundTags({'tags': tags});
  }

  static String noFilesFoundTagsGlobal(String tags) {
    return _defaultLocalizations.noFilesFoundTagsGlobal({'tags': tags});
  }

  static String errorSearchTag(String error) {
    return _defaultLocalizations.errorSearchTag({'error': error});
  }

  static String errorSearchTagGlobal(String error) {
    return _defaultLocalizations.errorSearchTagGlobal({'error': error});
  }

  static String errorSearchTags(String error) {
    return _defaultLocalizations.errorSearchTags({'error': error});
  }

  static String errorSearchTagsGlobal(String error) {
    return _defaultLocalizations.errorSearchTagsGlobal({'error': error});
  }


}

class FolderListBloc extends Bloc<FolderListEvent, FolderListState> {
  StreamSubscription? _tagChangeSubscription;
  StreamSubscription? _globalTagChangeSubscription;

  FolderListBloc() : super(FolderListState("/")) {
    on<FolderListInit>(_onFolderListInit);
    on<FolderListLoad>(_onFolderListLoad);
    on<FolderListRefresh>(_onFolderListRefresh);
    on<FolderListFilter>(_onFolderListFilter);
    on<FolderListLoadDrives>(_onFolderListLoadDrives);

    // Register for local tag change events
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagsChanged);

    // Register for global tag change notifications
    // NOTE: _onGlobalTagChanged now requires emit, so it cannot be used directly in this subscription.
    // If you need to handle global tag changes here, dispatch an event instead.
    _globalTagChangeSubscription =
        TagManager.instance.onGlobalTagChanged.listen((filePath) {
      // You may want to add a custom event here if needed.
    });

    // Note: AddTagToFile, RemoveTagFromFile, SearchByTag, SearchByTagGlobally,
    // SearchByFileName, and SearchMediaFiles events are now handled directly
    // in the mapEventToState method for immediate UI updates with tag changes

    on<LoadTagsFromFile>(_onLoadTagsFromFile);
    on<LoadAllTags>(_onLoadAllTags);
    on<SetViewMode>(_onSetViewMode);
    on<SetSortOption>(_onSetSortOption);
    on<SetGridZoom>(_onSetGridZoom);
    on<ClearSearchAndFilters>(_onClearSearchAndFilters);
    on<FolderListDeleteFiles>(_onFolderListDeleteFiles);
    on<SetTagSearchResults>(_onSetTagSearchResults);
    on<FolderListReloadCurrentFolder>(_onFolderListReloadCurrentFolder);
    on<FolderListDeleteTagGlobally>(_onFolderListDeleteTagGlobally);

    // Register file operation event handlers
    on<CopyFile>(_onCopyFile);
    on<CutFile>(_onCutFile);
    on<PasteFile>(_onPasteFile);
    on<RenameFileOrFolder>(_onRenameFileOrFolder);

    // Add missing event handlers
    on<SearchByFileName>(_onSearchByFileName);
    on<SearchByTag>(_onSearchByTag);
    on<SearchByTagGlobally>(_onSearchByTagGlobally);
    on<SearchByMultipleTags>(_onSearchByMultipleTags);
    on<SearchByMultipleTagsGlobally>(_onSearchByMultipleTagsGlobally);

    // Handler for adding tag search results
    on<AddTagSearchResults>(_onAddTagSearchResults);
  }

  // Xử lý khi tag thay đổi
  void _onTagsChanged(String filePath) {
    // Khi có sự kiện tag thay đổi, cập nhật lại danh sách tag
    if (filePath == "global:tag_deleted") {
      // Nếu là xóa tag toàn cục, tải lại tất cả tag
      add(LoadAllTags(state.currentPath.path));
    } else {
      // Cập nhật tag của file cụ thể
      add(LoadTagsFromFile(filePath));
    }
  }

  // Refreshes only the tags without reloading the entire folder structure
  // This preserves scroll position and selection
  void _refreshTagsOnly(String dirPath, Emitter<FolderListState> emit) async {
    try {
      // Emit loading state to notify UI about ongoing operation
      emit(state.copyWith(isLoading: true));

      // Force clear all caches
      TagManager.clearCache();

      // Keep current files and folders as is
      final currentFiles = List<FileSystemEntity>.from(state.files);

      // Only refresh the tags for these files
      Map<String, List<String>> updatedFileTags = {};
      for (final file in currentFiles) {
        if (file is File) {
          // Get updated tags for this file - avoid using cache
          final tags = await TagManager.getTags(file.path);
          if (tags.isNotEmpty) {
            updatedFileTags[file.path] = tags;
          }
        }
      }

      // Get updated unique tags for the directory
      final allUniqueTags = await TagManager.getAllUniqueTags(dirPath);

      // Update state with new tags but keep files/folders and scroll position
      emit(state.copyWith(
        isLoading: false,
        fileTags: updatedFileTags,
        allUniqueTags: allUniqueTags,
      ));
    } catch (e) {
      debugPrint('Error refreshing tags only: $e');
      // Make sure we're not stuck in loading state
      emit(state.copyWith(isLoading: false));
    }
  }

  @override
  Future<void> close() {
    // Cancel all subscriptions when bloc is closed
    _tagChangeSubscription?.cancel();
    _globalTagChangeSubscription?.cancel();
    return super.close();
  }

  void _onFolderListInit(
    FolderListInit event,
    Emitter<FolderListState> emit,
  ) async {
    // Initialize with empty folders list
    emit(state.copyWith(isLoading: true));
  }

  void _onFolderListLoad(
    FolderListLoad event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, currentPath: Directory(event.path)));

    // Special case for empty path on Windows - this is used for the drive listing view
    if (event.path.isEmpty && Platform.isWindows) {
      emit(
        state.copyWith(isLoading: false, folders: [], files: [], error: null),
      );
      return;
    }

    // Special case for mobile - add retry mechanism for folder loading
    if (Platform.isAndroid || Platform.isIOS) {
      // Add a small delay to ensure directory is ready
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final directory = Directory(event.path);
      if (await directory.exists()) {
        try {
          // Debug: Check permission status
          final permissionService = PermissionStateService.instance;
          final hasPermission =
              await permissionService.hasStorageOrPhotosPermission();
          debugPrint('DEBUG: Storage permission status: $hasPermission');

          // If no permission, try to request it
          if (!hasPermission) {
            debugPrint('DEBUG: No storage permission, requesting...');
            final granted = await permissionService.requestStorageOrPhotos();
            debugPrint('DEBUG: Permission request result: $granted');

            // If still no permission, emit error state
            if (!granted) {
              emit(state.copyWith(
                isLoading: false,
                error:
                    'Cần cấp quyền truy cập tất cả files để xem đầy đủ nội dung thư mục. Vui lòng vào Settings > Apps > CB File Manager > Permissions và bật "All files access".',
              ));
              return;
            }
          }

          // For mobile, add retry mechanism for directory listing
          List<FileSystemEntity> contents = [];
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              contents = await directory.list().toList();
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount < maxRetries) {
                debugPrint(
                    'Directory listing failed, retrying... ($retryCount/$maxRetries): $e');
                await Future.delayed(Duration(milliseconds: 200 * retryCount));
              } else {
                rethrow; // Re-throw the last error
              }
            }
          }

          // Separate folders and files
          final List<FileSystemEntity> folders = [];
          final List<FileSystemEntity> files = [];

          debugPrint('DEBUG: Directory listing found ${contents.length} items');
          debugPrint('DEBUG: Directory path: ${event.path}');

          // Debug: Log all items first
          for (var entity in contents) {
            debugPrint(
                'DEBUG: Raw item: ${entity.path} (${entity.runtimeType})');
          }

          for (var entity in contents) {
            if (entity is Directory) {
              folders.add(entity);
              debugPrint('DEBUG: Found folder: ${entity.path}');
            } else if (entity is File) {
              debugPrint('DEBUG: Found file: ${entity.path}');
              // Skip tag files - no longer needed with global tags
              // Also skip hidden config files
              if (!entity.path.endsWith('.tags') &&
                  pathlib.basename(entity.path) != '.cbfile_config.json') {
                files.add(entity);
                debugPrint('DEBUG: Added file to list: ${entity.path}');
              } else {
                debugPrint('DEBUG: Skipped file (tag/config): ${entity.path}');
              }
            }
          }

          debugPrint(
              'DEBUG: Final result - ${folders.length} folders, ${files.length} files');

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

          // Get folder-specific sort option if available (with defensive error handling)
          final folderSortManager = FolderSortManager();
          SortOption? folderSortOption;
          try {
            // Remove timeout - let it run quickly with cache
            folderSortOption =
                await folderSortManager.getFolderSortOption(event.path);
          } catch (e) {
            debugPrint(
                'Error getting folder sort option for ${event.path}: $e');
            folderSortOption = null; // Use default sort option if error occurs
          }

          // Use folder-specific sort option if available, otherwise use the current sort option
          SortOption sortOptionToUse = folderSortOption ?? state.sortOption;

          // Once we have files and folders, sort them according to the sort option
          await _sortFilesAndFolders(
            folders,
            files,
            sortOptionToUse,
            emit,
            updateSortOption: folderSortOption !=
                null, // Only update state.sortOption if we found a folder-specific one
          );

          // Emit state with files and folders (sorting will be handled later)
          final newState = state.copyWith(
            isLoading: false,
            folders: folders,
            files: files,
            fileTags: fileTags,
            error: null, // Clear any previous errors
            sortOption: folderSortOption ??
                state.sortOption, // Update the sort option if folder-specific
          );

          debugPrint(
              'DEBUG: Emitting state with ${newState.files.length} files');
          debugPrint('DEBUG: Current filter: ${newState.currentFilter}');
          debugPrint('DEBUG: Filtered files: ${newState.filteredFiles.length}');

          emit(newState);

          // Load all unique tags in this directory (async)
          add(LoadAllTags(event.path));

          // Prefetch thumbnails for the entire directory in background
          _prefetchThumbnailsForDirectory(files, event.path);
        } catch (e) {
          // Handle specific permission errors
          if (e.toString().toLowerCase().contains('permission denied') ||
              e.toString().toLowerCase().contains('access denied')) {
            emit(
              state.copyWith(
                isLoading: false,
                error:
                    "Access denied: Administrator privileges required to access ${event.path}",
                folders: [],
                files: [],
              ),
            );
          } else {
            emit(
              state.copyWith(
                isLoading: false,
                error: "Error accessing directory: ${e.toString()}",
                folders: [],
                files: [],
              ),
            );
          }
        }
      } else {
        emit(
          state.copyWith(isLoading: false, error: "Directory does not exist"),
        );
      }
    } catch (e) {
      // Improved error handling with user-friendly messages
      if (e.toString().toLowerCase().contains('permission denied') ||
          e.toString().toLowerCase().contains('access denied')) {
        emit(
          state.copyWith(
            isLoading: false,
            error:
                "Access denied: Administrator privileges required to access ${event.path}",
            folders: [],
            files: [],
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: "Error: ${e.toString()}",
            folders: [],
            files: [],
          ),
        );
      }
    }
  }

  // Helper method to sort files and folders according to a given sort option
  Future<void> _sortFilesAndFolders(
      List<FileSystemEntity> folders,
      List<FileSystemEntity> files,
      SortOption sortOption,
      Emitter<FolderListState> emit,
      {bool updateSortOption = false}) async {
    try {
      // Use FileSystemSorter to sort folders and files
      final sortedFolders = await FileSystemSorter.sortDirectories(
        folders.cast<Directory>(),
        sortOption,
      );
      
      final sortedFiles = await FileSystemSorter.sortFiles(
        files.cast<File>(),
        sortOption,
      );

      // Build file stats cache for the sorted entities
      Map<String, FileStat> fileStatsCache = {};
      final allEntities = [...sortedFolders, ...sortedFiles];
      for (var entity in allEntities) {
        try {
          fileStatsCache[entity.path] = await entity.stat();
        } catch (e) {
          // Skip entities that can't be stat'd
          continue;
        }
      }

      // Update the lists in place
      folders.clear();
      folders.addAll(sortedFolders);
      files.clear();
      files.addAll(sortedFiles);

      // Only update the sort option in state if requested
      if (updateSortOption) {
        emit(state.copyWith(
          sortOption: sortOption,
          fileStatsCache: fileStatsCache,
        ));
      } else {
        // Just update the fileStatsCache
        emit(state.copyWith(
          fileStatsCache: fileStatsCache,
        ));
      }
    } catch (e) {
      debugPrint("Error sorting files and folders: $e");
      // Don't update state on error
    }
  }

  void _onFolderListRefresh(
    FolderListRefresh event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Check if this is a system path (starts with #)
      if (event.path.startsWith('#')) {
        // For system paths, we need special handling
        if (event.path == '#tags') {
          // For tag management screen, just load all unique tags
          final allUniqueTags = await TagManager.getAllUniqueTags("");
          emit(state.copyWith(
            isLoading: false,
            allUniqueTags: allUniqueTags,
          ));
          return;
        } else if (event.path.startsWith('#tag:')) {
          // For tag search, this will be handled by SearchByTagGlobally
          // Just update loading state to false
          emit(state.copyWith(
            isLoading: false,
          ));
          return;
        }
      }

      final directory = Directory(event.path);
      if (await directory.exists()) {
        // Load folder contents first
        List<FileSystemEntity> contents = await directory.list().toList();

        // Separate folders and files
        final List<FileSystemEntity> folders = [];
        final List<FileSystemEntity> files = [];

        for (var entity in contents) {
          if (entity is Directory) {
            folders.add(entity);
          } else if (entity is File) {
            // Skip tag files
            if (!entity.path.endsWith('.tags') &&
                pathlib.basename(entity.path) != '.cbfile_config.json') {
              files.add(entity);
            }
          }
        }

        // Important: Clear the tag cache to ensure fresh data
        TagManager.clearCache();

        // Load tags for all files
        Map<String, List<String>> fileTags = {};
        for (var file in files) {
          if (file is File) {
            // Always fetch fresh data from storage
            final tags = await TagManager.getTags(file.path);
            if (tags.isNotEmpty) {
              fileTags[file.path] = tags;
            }
          }
        } // Get all unique tags for this directory
        final allUniqueTags = await TagManager.getAllUniqueTags(event.path);

        // Get folder-specific sort option if available (with defensive error handling)
        final folderSortManager = FolderSortManager();
        SortOption? folderSortOption;
        try {
          // Remove timeout - let it run quickly with cache
          folderSortOption =
              await folderSortManager.getFolderSortOption(event.path);
        } catch (e) {
          debugPrint('Error getting folder sort option for ${event.path}: $e');
          folderSortOption = null; // Use default sort option if error occurs
        }

        // Use folder-specific sort option if available, otherwise use the current sort option
        SortOption sortOptionToUse = folderSortOption ?? state.sortOption;

        // Apply sorting FIRST, then emit final state with isLoading: false
        // This ensures UI shows complete, sorted content without gaps
        
        // Use FileSystemSorter to sort folders and files
        final sortedFolders = await FileSystemSorter.sortDirectories(
          folders.cast<Directory>(),
          sortOptionToUse,
        );
        
        final sortedFiles = await FileSystemSorter.sortFiles(
          files.cast<File>(),
          sortOptionToUse,
        );

        // Build file stats cache for the sorted entities
        Map<String, FileStat> fileStatsCache = {};
        final allEntities = [...sortedFolders, ...sortedFiles];
        for (var entity in allEntities) {
          try {
            fileStatsCache[entity.path] = await entity.stat();
          } catch (e) {
            // Skip entities that can't be stat'd
            continue;
          }
        }

        // Now emit the final state with sorted content and isLoading: false
        emit(
          state.copyWith(
            isLoading: false,
            folders: sortedFolders,
            files: sortedFiles,
            fileTags: fileTags,
            allUniqueTags: allUniqueTags,
            error: null,
            currentPath: Directory(event.path),
            sortOption: folderSortOption ?? state.sortOption,
          ),
        );

        // Start thumbnail generation in background AFTER updating UI
        if (event.forceRegenerateThumbnails) {
          // Regenerate all thumbnails explicitly when requested
          unawaited(
            VideoThumbnailHelper.regenerateThumbnailsForDirectory(event.path),
          );
        } else {
          // Default: prefetch thumbnails for the current directory (non-blocking)
          _prefetchThumbnailsForDirectory(files, event.path);
        }
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Directory does not exist: ${event.path}',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error loading directory: ${e.toString()}',
        ),
      );
    } finally {
      // Extra safety: ensure loading indicator is gone
      if (state.isLoading) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }

  // Prefetch all video thumbnails in a directory without blocking UI
  void _prefetchThumbnailsForDirectory(
      List<FileSystemEntity> files, String dirPath) {
    try {
      // Skip special/system paths
      if (dirPath.startsWith('#')) return;

      // On mobile, avoid prefetch to keep things lazy and smooth
      if (Platform.isAndroid || Platform.isIOS) return;

      // Collect video file paths
      final videoPaths = files
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => FileTypeUtils.isVideoFile(p))
          .toList();

      if (videoPaths.isEmpty) return;

      // Inform helper about current directory to cancel other queues
      VideoThumbnailHelper.setCurrentDirectory(dirPath);

      // Queue preload with priority batching; do not await
      unawaited(
        VideoThumbnailHelper.optimizedBatchPreload(
          videoPaths,
          maxConcurrent: 2,
          visibleCount: 30,
        ),
      );
    } catch (e) {
      debugPrint('Error prefetching thumbnails for $dirPath: $e');
    }
  }

  // New method to generate thumbnails without blocking UI
  Future<void> _generateThumbnailsInBackground(
    List<FileSystemEntity> videoFiles,
  ) async {
    if (videoFiles.isEmpty) return;

    try {
      for (var videoFile in videoFiles) {
        if (videoFile is File) {
          try {
            // Check with the VideoThumbnailHelper if we should continue processing
            // This will prevent thumbnail generation from continuing if user navigates away
            if (VideoThumbnailHelper.shouldStopProcessing()) {
              debugPrint('Thumbnail generation canceled due to navigation');
              break;
            }

            await VideoThumbnailHelper.forceRegenerateThumbnail(
              videoFile.path,
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint(
                    'Thumbnail generation timed out for: ${videoFile.path}');
                return;
              },
            );
          } catch (e) {
            debugPrint('Error generating thumbnail for ${videoFile.path}: $e');
            // Continue with next file, don't stop on error
          }
        }
      }
    } catch (e) {
      debugPrint('Error in background thumbnail generation: $e');
    }
  }

  void _onFolderListFilter(
    FolderListFilter event,
    Emitter<FolderListState> emit,
  ) async {
    // Filter files by type (videos, images, etc.)
    if (event.fileType == null) {
      emit(state.copyWith(currentFilter: null, filteredFiles: []));
      return;
    }

    emit(state.copyWith(isLoading: true, currentFilter: event.fileType));

    try {
      final List<FileSystemEntity> filteredFiles = state.files.where((file) {
        if (file is File) {
          switch (event.fileType) {
            case 'image':
              return FileTypeUtils.isImageFile(file.path);
            case 'video':
              return FileTypeUtils.isVideoFile(file.path);
            case 'audio':
              return FileTypeUtils.isAudioFile(file.path);
            case 'document':
              return FileTypeUtils.isDocumentFile(file.path) ||
                  FileTypeUtils.isSpreadsheetFile(file.path) ||
                  FileTypeUtils.isPresentationFile(file.path);
            default:
              return true;
          }
        }
        return false;
      }).toList();

      emit(state.copyWith(isLoading: false, filteredFiles: filteredFiles));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onLoadTagsFromFile(
    LoadTagsFromFile event,
    Emitter<FolderListState> emit,
  ) async {
    try {
      final tags = await TagManager.getTags(event.filePath);

      // Only update if we have tags
      if (tags.isNotEmpty) {
        Map<String, List<String>> updatedFileTags = Map.from(state.fileTags);
        updatedFileTags[event.filePath] = tags;

        emit(state.copyWith(fileTags: updatedFileTags));
      }
    } catch (e) {
      debugPrint('Error loading tags for file: ${e.toString()}');
    }
  }

  void _onLoadAllTags(LoadAllTags event, Emitter<FolderListState> emit) async {
    try {
      // Get all unique tags across the entire file system (globally)
      final Set<String> allTags = await TagManager.getAllUniqueTags(
        event.directory,
      );
      emit(state.copyWith(allUniqueTags: allTags));
    } catch (e) {
      debugPrint('Error loading all tags: ${e.toString()}');
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
    SetSortOption event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Get file stats for sorting
      Map<String, FileStat> fileStatsCache = {};

      // Create new sorted lists by copying the original lists
      List<FileSystemEntity> sortedFolders = List.from(state.folders);
      List<FileSystemEntity> sortedFiles = List.from(state.files);
      List<FileSystemEntity> sortedFilteredFiles = List.from(
        state.filteredFiles,
      );
      List<FileSystemEntity> sortedSearchResults = List.from(
        state.searchResults,
      );

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
      ]); // Save the sort option to the current folder (with defensive error handling)
      final folderSortManager = FolderSortManager();
      debugPrint(
          'Trying to save sort option ${event.sortOption} to folder: ${state.currentPath.path}');

      bool saveResult = false;
      try {
        // Remove timeout - let it run quickly without blocking
        saveResult = await folderSortManager.saveFolderSortOption(
            state.currentPath.path, event.sortOption);
      } catch (e) {
        debugPrint(
            'Error saving folder sort option for ${state.currentPath.path}: $e');
        saveResult = false; // Continue without saving if error occurs
      }
      debugPrint('Save sort option result: $saveResult');

      // Check if sort option was actually saved (with defensive error handling)
      SortOption? savedOption;
      try {
        // Remove timeout - let it run quickly with cache
        savedOption =
            await folderSortManager.getFolderSortOption(state.currentPath.path);
      } catch (e) {
        debugPrint(
            'Error getting folder sort option for ${state.currentPath.path}: $e');
        savedOption = null; // Continue without saved option if error occurs
      }
      debugPrint('Retrieved sort option after save: ${savedOption?.name}');

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
            final aExt = pathlib.extension(a.path).toLowerCase();
            final bExt = pathlib.extension(b.path).toLowerCase();
            return aExt.compareTo(bExt);
          };
          break;
        case SortOption.typeDesc:
          compareFunction = (a, b) {
            final aExt = pathlib.extension(a.path).toLowerCase();
            final bExt = pathlib.extension(b.path).toLowerCase();
            return bExt.compareTo(aExt);
          };
          break;
        case SortOption.dateCreatedAsc:
          compareFunction = (a, b) {
            // On Windows, we can get creation time
            if (Platform.isWindows) {
              try {
                final aStats = fileStatsCache[a.path]!;
                final bStats = fileStatsCache[b.path]!;
                return aStats.changed.compareTo(bStats.changed);
              } catch (e) {
                // Fallback to modified date if any error
                final aStats = fileStatsCache[a.path]!;
                final bStats = fileStatsCache[b.path]!;
                return aStats.modified.compareTo(bStats.modified);
              }
            } else {
              // On other platforms, use modified as a fallback
              final aStats = fileStatsCache[a.path]!;
              final bStats = fileStatsCache[b.path]!;
              return aStats.modified.compareTo(bStats.modified);
            }
          };
          break;
        case SortOption.dateCreatedDesc:
          compareFunction = (a, b) {
            // On Windows, we can get creation time
            if (Platform.isWindows) {
              try {
                final aStats = fileStatsCache[a.path]!;
                final bStats = fileStatsCache[b.path]!;
                return bStats.changed.compareTo(aStats.changed);
              } catch (e) {
                // Fallback to modified date if any error
                final aStats = fileStatsCache[a.path]!;
                final bStats = fileStatsCache[b.path]!;
                return bStats.modified.compareTo(aStats.modified);
              }
            } else {
              // On other platforms, use modified as a fallback
              final aStats = fileStatsCache[a.path]!;
              final bStats = fileStatsCache[b.path]!;
              return bStats.modified.compareTo(aStats.modified);
            }
          };
          break;
        case SortOption.extensionAsc:
          compareFunction = (a, b) {
            final aExt = pathlib.extension(a.path).toLowerCase();
            final bExt = pathlib.extension(b.path).toLowerCase();
            return aExt.compareTo(bExt);
          };
          break;
        case SortOption.extensionDesc:
          compareFunction = (a, b) {
            final aExt = pathlib.extension(a.path).toLowerCase();
            final bExt = pathlib.extension(b.path).toLowerCase();
            return bExt.compareTo(aExt);
          };
          break;
        case SortOption.attributesAsc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return aAttrs.compareTo(bAttrs);
          };
          break;
        case SortOption.attributesDesc:
          compareFunction = (a, b) {
            final aStats = fileStatsCache[a.path]!;
            final bStats = fileStatsCache[b.path]!;
            // Create a string representation of attributes for comparison
            final aAttrs = '${aStats.mode},${aStats.type}';
            final bAttrs = '${bStats.mode},${bStats.type}';
            return bAttrs.compareTo(aAttrs);
          };
          break;
        default:
          compareFunction = (a, b) => pathlib
              .basename(a.path)
              .toLowerCase()
              .compareTo(pathlib.basename(b.path).toLowerCase());
      }

      // Folders always come first, then apply the sort function within each group

      // Sort folders and files separately
      sortedFolders.sort(compareFunction);
      sortedFiles.sort(compareFunction);
      sortedFilteredFiles.sort(compareFunction);
      sortedSearchResults.sort(compareFunction);

      // Emit the new state with sorted lists and the updated sort option
      emit(
        state.copyWith(
          isLoading: false,
          sortOption: event.sortOption,
          folders: sortedFolders,
          files: sortedFiles,
          filteredFiles: sortedFilteredFiles,
          searchResults: sortedSearchResults,
          fileStatsCache: fileStatsCache,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: "Error sorting files: ${e.toString()}",
        ),
      );
    }
  }

  void _onClearSearchAndFilters(
    ClearSearchAndFilters event,
    Emitter<FolderListState> emit,
  ) {
    // Reset all search and filter related state variables
    emit(
      state.copyWith(
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
      ),
    );
  }

  void _onFolderListDeleteFiles(
    FolderListDeleteFiles event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      List<String> failedDeletes = [];
      final trashManager = TrashManager(); // Create an instance of TrashManager

      for (var filePath in event.filePaths) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await trashManager.moveToTrash(filePath); // Use the instance method
          }
        } catch (e) {
          failedDeletes.add(filePath);
          debugPrint('Error deleting file $filePath: $e');
        }
      }

      if (failedDeletes.isNotEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Failed to delete ${failedDeletes.length} files',
          ),
        );
      }

      // Refresh the current directory
      add(FolderListLoad(state.currentPath.path));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error deleting files: ${e.toString()}',
        ),
      );
    }
  }

  void _onSetTagSearchResults(
    SetTagSearchResults event,
    Emitter<FolderListState> emit,
  ) {
    // Update the state with tag search results
    emit(
      state.copyWith(
        searchResults: event.results,
        currentSearchTag: event.tagName,
        isLoading: false,
        isSearchByName: false,
        isGlobalSearch: false,
        currentSearchQuery: null,
      ),
    );
  }

  // File operation handlers
  void _onCopyFile(CopyFile event, Emitter<FolderListState> emit) {
    try {
      // Use the FileOperations singleton to add the file to clipboard
      FileOperations().copyToClipboard(event.entity);
      emit(
        state.copyWith(
          error: null, // Clear any previous errors
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Error copying file/folder: ${e.toString()}'));
    }
  }

  void _onCutFile(CutFile event, Emitter<FolderListState> emit) {
    try {
      // Use the FileOperations singleton to add the file to clipboard for cutting
      FileOperations().cutToClipboard(event.entity);
      emit(
        state.copyWith(
          error: null, // Clear any previous errors
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Error cutting file/folder: ${e.toString()}'));
    }
  }

  void _onPasteFile(PasteFile event, Emitter<FolderListState> emit) async {
    if (!FileOperations().hasClipboardItem) {
      emit(state.copyWith(error: 'Nothing to paste - clipboard is empty'));
      return;
    }

    emit(state.copyWith(isLoading: true));

    try {
      // Use the FileOperations singleton to paste the file
      await FileOperations().pasteFromClipboard(event.destinationPath);

      // Refresh the current directory to show the new file/folder
      add(FolderListLoad(state.currentPath.path));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error pasting file/folder: ${e.toString()}',
        ),
      );
    }
  }

  void _onRenameFileOrFolder(
    RenameFileOrFolder event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Use the FileOperations singleton to rename the file or folder
      await FileOperations().rename(event.entity, event.newName);

      // Refresh the current directory to show the renamed file/folder
      add(FolderListLoad(state.currentPath.path));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error renaming file/folder: ${e.toString()}',
        ),
      );
    }
  }

  // Handle reloading the current folder
  void _onFolderListReloadCurrentFolder(
    FolderListReloadCurrentFolder event,
    Emitter<FolderListState> emit,
  ) async {
    // Only proceed if we have a valid current path
    if (state.currentPath.path.isNotEmpty) {
      // Use the optimized refresh that doesn't reset scroll position
      _refreshTagsOnly(state.currentPath.path, emit);
    }
  }

  // Handle deleting a tag globally
  void _onFolderListDeleteTagGlobally(
    FolderListDeleteTagGlobally event,
    Emitter<FolderListState> emit,
  ) async {
    try {
      // Delete the tag from all files in the system
      await TagManager.deleteTagGlobally(event.tag);

      // Clear tag cache to ensure fresh data
      TagManager.clearCache();

      // Notify with special path to indicate global tag deletion
      TagManager.instance.notifyTagChanged("global:tag_deleted");

      // Refresh the current directory view
      if (state.currentPath.path.isNotEmpty) {
        add(FolderListRefresh(state.currentPath.path,
            forceRegenerateThumbnails: true));
      }
    } catch (e) {
      debugPrint('Error deleting tag globally: $e');
      // No state update needed as we'll refresh the entire view
    }
  }

  // Handler for filename search
  void _onSearchByFileName(
    SearchByFileName event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final String query = event.query.toLowerCase();
      final List<FileSystemEntity> searchResults = [];

      if (event.recursive) {
        // Recursive search in current directory and subdirectories
        final currentDir = Directory(state.currentPath.path);
        
        debugPrint('🔍 Starting recursive search in: ${currentDir.path}');
        debugPrint('🔍 Query: "$query"');
        
        int scannedCount = 0;
        int matchedCount = 0;
        int errorCount = 0;
        
        // Use manual recursive search to handle permission errors gracefully
        await _recursiveSearch(
          currentDir,
          query,
          searchResults,
          (scanned, matched, errors) {
            scannedCount = scanned;
            matchedCount = matched;
            errorCount = errors;
            
            // Log progress every 100 items
            if (scannedCount % 100 == 0) {
              debugPrint('🔍 Scanned: $scannedCount, Matched: $matchedCount, Errors: $errorCount');
            }
          },
        );
        
        debugPrint('🔍 Search complete! Scanned: $scannedCount, Matched: $matchedCount, Errors: $errorCount');
      } else {
        // Search in current directory only (both files and folders)
        final allFiles = state.files;
        final allFolders = state.folders;

        // Search in files
        for (var file in allFiles) {
          final fileName = pathlib.basename(file.path);
          // Use Vietnamese normalization for matching
          if (TextUtils.matchesVietnamese(fileName, query)) {
            searchResults.add(file);
          }
        }

        // Search in folders
        for (var folder in allFolders) {
          final folderName = pathlib.basename(folder.path);
          // Use Vietnamese normalization for matching
          if (TextUtils.matchesVietnamese(folderName, query)) {
            searchResults.add(folder);
          }
        }
      }

      // Update state with search results
      emit(state.copyWith(
        isLoading: false,
        searchResults: searchResults,
        currentSearchQuery: event.query,
        currentSearchTag: null, // Clear any previous tag search
        searchRecursive: event.recursive,
        error: searchResults.isEmpty
            ? 'No files or folders found matching "${event.query}"'
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Error searching: ${e.toString()}',
      ));
    }
  }

  // Helper method for recursive search that handles permission errors gracefully
  Future<void> _recursiveSearch(
    Directory dir,
    String query,
    List<FileSystemEntity> results,
    Function(int scanned, int matched, int errors) onProgress,
  ) async {
    int scannedCount = 0;
    int matchedCount = 0;
    int errorCount = 0;
    
    try {
      // List current directory (non-recursive)
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        try {
          scannedCount++;
          
          final entityName = pathlib.basename(entity.path);
          
          // Check if entity matches query
          if (TextUtils.matchesVietnamese(entityName, query)) {
            results.add(entity);
            matchedCount++;
            debugPrint('✅ Match found: ${entity.path}');
          }
          
          // If it's a directory, recursively search it
          if (entity is Directory) {
            try {
              await _recursiveSearch(entity, query, results, (s, m, e) {
                scannedCount += s;
                matchedCount += m;
                errorCount += e;
                onProgress(scannedCount, matchedCount, errorCount);
              });
            } catch (e) {
              // Skip directories that cause errors
              errorCount++;
              debugPrint('⚠️ Skipping directory: ${entity.path} - $e');
            }
          }
          
          onProgress(scannedCount, matchedCount, errorCount);
        } catch (e) {
          // Skip individual entities that cause errors
          errorCount++;
          debugPrint('⚠️ Skipping entity: ${entity.path} - $e');
        }
      }
    } catch (e) {
      // Directory listing failed (permission denied, etc.)
      errorCount++;
      debugPrint('⚠️ Cannot access directory: ${dir.path} - $e');
    }
  }

  // Handler for tag search in current directory
  void _onSearchByTag(
    SearchByTag event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Clear tag cache to ensure fresh data
      TagManager.clearCache();

      debugPrint(
          'Searching for files with tag "${event.tag}" in directory ${state.currentPath.path}');

      // Use the improved findFilesByTag method to search including subdirectories
      final List<FileSystemEntity> results = await TagManager.findFilesByTag(
        state.currentPath.path,
        event.tag,
      );

      // Log the search results for debugging
      debugPrint('Found ${results.length} results for tag: ${event.tag}');
      for (var entity in results) {
        debugPrint('  - ${entity.path}');
      }

      emit(state.copyWith(
        isLoading: false,
        searchResults: results,
        currentSearchTag: event.tag,
        currentSearchQuery: null, // Clear any previous text search
        error: results.isEmpty
            ? SearchErrorMessages.noFilesFoundTag(event.tag)
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: SearchErrorMessages.errorSearchTag(e.toString()),
        searchResults: [], // Ensure we clear results on error
      ));
    }
  }

  // Handler for global tag search
  void _onSearchByTagGlobally(
    SearchByTagGlobally event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Clear tag cache to ensure fresh data
      TagManager.clearCache();

      debugPrint('Searching for files with tag "${event.tag}" globally');

      // Get results from both sources to ensure we find all files
      final List<FileSystemEntity> results =
          await TagManager.findFilesByTagGlobally(event.tag);

      // Log the search results for debugging
      debugPrint(
          'Found ${results.length} global results for tag: ${event.tag}');

      // Filter out any non-existent files or directories
      final List<FileSystemEntity> validResults = [];
      for (var entity in results) {
        try {
          if (entity is File && entity.existsSync()) {
            validResults.add(entity);
            debugPrint('  - ${entity.path}');
          }
        } catch (e) {
          debugPrint('Error checking file existence: ${entity.path} - $e');
        }
      }

      // If no results from TagManager, try directly from database
      if (validResults.isEmpty) {
        debugPrint(
            'No valid results from TagManager, trying database directly');
        try {
          final dbResults =
              await DatabaseManager.getInstance().findFilesByTag(event.tag);
          for (var path in dbResults) {
            try {
              final file = File(path);
              if (file.existsSync()) {
                validResults.add(file);
                debugPrint('  - (From DB) ${file.path}');
              }
            } catch (e) {
              debugPrint('Error checking file from DB: $path - $e');
            }
          }
        } catch (e) {
          debugPrint('Error querying database: $e');
        }
      }

      emit(state.copyWith(
        isLoading: false,
        searchResults: validResults,
        currentSearchTag: event.tag,
        currentSearchQuery: null, // Clear any previous text search
        error: validResults.isEmpty
            ? SearchErrorMessages.noFilesFoundTagGlobal(event.tag)
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: SearchErrorMessages.errorSearchTagGlobal(e.toString()),
        searchResults: [], // Ensure we clear results on error
      ));
    }
  }

  // Handler for adding tag search results
  void _onAddTagSearchResults(
    AddTagSearchResults event,
    Emitter<FolderListState> emit,
  ) {
    // Get the current search results
    final currentResults = List<FileSystemEntity>.from(state.searchResults);

    // Add the new results, avoiding duplicates
    for (final entity in event.results) {
      if (!currentResults.any((e) => e.path == entity.path)) {
        currentResults.add(entity);
      }
    }

    emit(state.copyWith(
      searchResults: currentResults,
      // Keep the current search tag and query unchanged
    ));
  }

  // New handler for searching by multiple tags in current directory
  void _onSearchByMultipleTags(
    SearchByMultipleTags event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Clear tag cache to ensure fresh data
      TagManager.clearCache();

      String tagListStr = event.tags.map((t) => '"$t"').join(', ');
      debugPrint(
          'Searching for files with multiple tags $tagListStr in directory ${state.currentPath.path}');

      // Start with all files containing the first tag
      List<FileSystemEntity> results = [];
      if (event.tags.isNotEmpty) {
        results = await TagManager.findFilesByTag(
          state.currentPath.path,
          event.tags.first,
        );
      }

      // For each additional tag, filter the results to only include files with all tags
      for (int i = 1; i < event.tags.length; i++) {
        String tag = event.tags[i];
        List<FileSystemEntity> filteredResults = [];

        for (var entity in results) {
          if (entity is File) {
            List<String> fileTags = await TagManager.getTags(entity.path);
            if (fileTags.contains(tag)) {
              filteredResults.add(entity);
            }
          }
        }

        results = filteredResults;
      }

      // Log the search results for debugging
      debugPrint(
          'Found ${results.length} results for multiple tags: $tagListStr');
      for (var entity in results) {
        debugPrint('  - ${entity.path}');
      }

      emit(state.copyWith(
        isLoading: false,
        searchResults: results,
        currentSearchTag: event.tags.join(", "), // Join tags for display
        currentSearchQuery: null, // Clear any previous text search
        error: results.isEmpty
            ? SearchErrorMessages.noFilesFoundTags(tagListStr)
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: SearchErrorMessages.errorSearchTags(e.toString()),
        searchResults: [], // Ensure we clear results on error
      ));
    }
  }

  // New handler for global search with multiple tags
  void _onSearchByMultipleTagsGlobally(
    SearchByMultipleTagsGlobally event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Clear tag cache to ensure fresh data
      TagManager.clearCache();

      String tagListStr = event.tags.map((t) => '"$t"').join(', ');
      debugPrint('Searching for files with multiple tags $tagListStr globally');

      // Start with all files containing the first tag
      List<FileSystemEntity> results = [];
      if (event.tags.isNotEmpty) {
        results = await TagManager.findFilesByTagGlobally(event.tags.first);
      }

      // For each additional tag, filter the results to only include files with all tags
      for (int i = 1; i < event.tags.length; i++) {
        String tag = event.tags[i];
        List<FileSystemEntity> filteredResults = [];

        for (var entity in results) {
          if (entity is File && entity.existsSync()) {
            List<String> fileTags = await TagManager.getTags(entity.path);
            if (fileTags.contains(tag)) {
              filteredResults.add(entity);
            }
          }
        }

        results = filteredResults;
      }

      // Filter out any non-existent files
      final List<FileSystemEntity> validResults = [];
      for (var entity in results) {
        try {
          if (entity is File && entity.existsSync()) {
            validResults.add(entity);
            debugPrint('  - ${entity.path}');
          }
        } catch (e) {
          debugPrint('Error checking file existence: ${entity.path} - $e');
        }
      }

      emit(state.copyWith(
        isLoading: false,
        searchResults: validResults,
        currentSearchTag: event.tags.join(", "), // Join tags for display
        currentSearchQuery: null, // Clear any previous text search
        error: validResults.isEmpty
            ? SearchErrorMessages.noFilesFoundTagsGlobal(tagListStr)
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: SearchErrorMessages.errorSearchTagsGlobal(e.toString()),
        searchResults: [], // Ensure we clear results on error
      ));
    }
  }

  // Add handler for loading drives
  void _onFolderListLoadDrives(
    FolderListLoadDrives event,
    Emitter<FolderListState> emit,
  ) async {
    // Drives will be loaded by the DriveView's FutureBuilder directly
    // This event is primarily for BLoC state management when lazy loading
    // No need to change the state here since we're already showing skeleton UI
    // Just log the event for debugging
    debugPrint(
        'FolderListLoadDrives event received - drives will load asynchronously');
  }
}
