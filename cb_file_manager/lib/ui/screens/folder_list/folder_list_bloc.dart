import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart'; // Add import for TrashManager
import 'package:cb_file_manager/helpers/filesystem_utils.dart'; // Import for FileOperations
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart';
import 'dart:async'; // Thêm import cho StreamSubscription
import 'package:cb_file_manager/helpers/folder_sort_manager.dart';

import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListBloc extends Bloc<FolderListEvent, FolderListState> {
  StreamSubscription? _tagChangeSubscription;
  StreamSubscription? _globalTagChangeSubscription;

  FolderListBloc() : super(FolderListState("/")) {
    on<FolderListInit>(_onFolderListInit);
    on<FolderListLoad>(_onFolderListLoad);
    on<FolderListRefresh>(_onFolderListRefresh);
    on<FolderListFilter>(_onFolderListFilter);

    // Register for local tag change events
    _tagChangeSubscription = TagManager.onTagChanged.listen(_onTagsChanged);

    // Register for global tag change notifications
    _globalTagChangeSubscription =
        TagManager.instance.onGlobalTagChanged.listen(_onGlobalTagChanged);

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

  // Handle global tag change notifications
  void _onGlobalTagChanged(String filePath) {
    // If this is a file that should affect the current view
    if (state.currentPath.path.isNotEmpty) {
      try {
        // Special case for global tag deletion
        if (filePath == "global:tag_deleted") {
          // Just refresh file tags without reloading the entire list
          _refreshTagsOnly(state.currentPath.path);
          return;
        }

        // Check if this is a request to preserve scroll position
        bool preserveScroll = false;
        String actualPath = filePath;

        if (filePath.startsWith("preserve_scroll:")) {
          preserveScroll = true;
          actualPath = filePath.substring("preserve_scroll:".length);
        }

        final parentPath = Directory(actualPath).parent.path;

        // If the changed file is in the current directory
        if (parentPath == state.currentPath.path) {
          if (preserveScroll) {
            // Use the optimized refresh that preserves scroll position
            _refreshTagsOnly(state.currentPath.path);
          } else {
            // Full refresh if preserveScroll is false
            add(FolderListRefresh(state.currentPath.path,
                forceRegenerateThumbnails: true));
          }
        }
      } catch (e) {
        print('Error handling global tag change: $e');
      }
    }
  }

  // Refreshes only the tags without reloading the entire folder structure
  // This preserves scroll position and selection
  void _refreshTagsOnly(String dirPath) async {
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
      print('Error refreshing tags only: $e');
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
    emit(state.copyWith(isLoading: false));
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
              // Also skip hidden config files
              if (!entity.path.endsWith('.tags') &&
                  pathlib.basename(entity.path) != '.cbfile_config.json') {
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

          // Get folder-specific sort option if available
          final folderSortManager = FolderSortManager();
          final folderSortOption =
              await folderSortManager.getFolderSortOption(event.path);

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
          emit(
            state.copyWith(
              isLoading: false,
              folders: folders,
              files: files,
              fileTags: fileTags,
              error: null, // Clear any previous errors
              sortOption: folderSortOption ??
                  state.sortOption, // Update the sort option if folder-specific
            ),
          );

          // Load all unique tags in this directory (async)
          add(LoadAllTags(event.path));
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
      // Get file stats for sorting
      Map<String, FileStat> fileStatsCache = {};

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
        cacheFileStats(folders),
        cacheFileStats(files),
      ]);

      // Define the sorting function based on the selected sort option
      int Function(FileSystemEntity, FileSystemEntity) compareFunction;

      switch (sortOption) {
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
            if (FolderSortManager().isWindows) {
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
            if (FolderSortManager().isWindows) {
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
      final folderFirstCompare = (FileSystemEntity a, FileSystemEntity b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        // If both are directories or both are files, use the specific compare function
        if (aIsDir == bIsDir) {
          return compareFunction(a, b);
        }

        // Otherwise, directories come first
        return aIsDir ? -1 : 1;
      };

      // Sort folders and files with the folder-first comparison
      folders.sort(compareFunction);
      files.sort(compareFunction);

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
      print("Error sorting files and folders: $e");
      // Don't update state on error
    }
  }

  void _onFolderListRefresh(
    FolderListRefresh event,
    Emitter<FolderListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
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
        }

        // Get all unique tags for this directory
        final allUniqueTags = await TagManager.getAllUniqueTags(event.path);

        // Get folder-specific sort option if available
        final folderSortManager = FolderSortManager();
        final folderSortOption =
            await folderSortManager.getFolderSortOption(event.path);

        // Use folder-specific sort option if available, otherwise use the current sort option
        SortOption sortOptionToUse = folderSortOption ?? state.sortOption;

        // IMPORTANT: Update UI state IMMEDIATELY to show content, even before thumbnails are ready
        // This prevents UI blocking while thumbnails are generated
        emit(
          state.copyWith(
            isLoading: false, // Set to false right away so UI is not blocked
            folders: folders,
            files: files,
            fileTags: fileTags,
            allUniqueTags: allUniqueTags,
            error: null,
            currentPath: Directory(event.path),
            sortOption: folderSortOption ??
                state.sortOption, // Update sort option if folder-specific
          ),
        );

        // Apply sorting after emitting the initial state
        await _sortFilesAndFolders(
          folders,
          files,
          sortOptionToUse,
          emit,
          updateSortOption: false, // Already updated the sort option
        );

        // Start thumbnail generation in background AFTER updating UI
        if (event.forceRegenerateThumbnails) {
          // Find video files
          final videoFiles = files.where((file) {
            if (file is File) {
              String extension = file.path.split('.').last.toLowerCase();
              return [
                'mp4',
                'mov',
                'avi',
                'mkv',
                'flv',
                'wmv',
                'webm',
                '3gp',
                'm4v',
              ].contains(extension);
            }
            return false;
          }).toList();

          // Don't await here - process in background
          _generateThumbnailsInBackground(videoFiles);
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
              print('Thumbnail generation canceled due to navigation');
              break;
            }

            await VideoThumbnailHelper.forceRegenerateThumbnail(
              videoFile.path,
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print('Thumbnail generation timed out for: ${videoFile.path}');
                return;
              },
            );
          } catch (e) {
            print('Error generating thumbnail for ${videoFile.path}: $e');
            // Continue with next file, don't stop on error
          }
        }
      }
    } catch (e) {
      print('Error in background thumbnail generation: $e');
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
          String extension = file.path.split('.').last.toLowerCase();
          switch (event.fileType) {
            case 'image':
              return [
                'jpg',
                'jpeg',
                'png',
                'gif',
                'webp',
                'bmp',
              ].contains(extension);
            case 'video':
              return [
                'mp4',
                'mov',
                'avi',
                'mkv',
                'flv',
                'wmv',
              ].contains(extension);
            case 'audio':
              return [
                'mp3',
                'wav',
                'ogg',
                'm4a',
                'aac',
                'flac',
              ].contains(extension);
            case 'document':
              return [
                'pdf',
                'doc',
                'docx',
                'txt',
                'xls',
                'xlsx',
                'ppt',
                'pptx',
              ].contains(extension);
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
      print('Error loading tags for file: ${e.toString()}');
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
      ]);

      // Save the sort option to the current folder
      final folderSortManager = FolderSortManager();
      await folderSortManager.saveFolderSortOption(
          state.currentPath.path, event.sortOption);

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
            if (FolderSortManager().isWindows) {
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
            if (FolderSortManager().isWindows) {
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
      final folderFirstCompare = (FileSystemEntity a, FileSystemEntity b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        // If both are directories or both are files, use the specific compare function
        if (aIsDir == bIsDir) {
          return compareFunction(a, b);
        }

        // Otherwise, directories come first
        return aIsDir ? -1 : 1;
      };

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
          print('Error deleting file $filePath: $e');
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
      _refreshTagsOnly(state.currentPath.path);
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
      print('Error deleting tag globally: $e');
      // No state update needed as we'll refresh the entire view
    }
  }
}
