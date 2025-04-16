import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Add this import for mouse buttons
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/folder_list/components/index.dart'
    as folder_list_components;

/// Displays search results from tag and filename searches
class SearchResultsView extends StatelessWidget {
  final FolderListState state;
  final bool isSelectionMode;
  final List<String> selectedFiles;
  final Function(String) toggleFileSelection;
  final VoidCallback toggleSelectionMode;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final VoidCallback onClearSearch;
  final Function(String)? onFolderTap; // Callback for folder click
  final Function(File, bool)? onFileTap; // Callback for file click
  final VoidCallback? onBackButtonPressed; // Add callback for back button
  final VoidCallback? onForwardButtonPressed; // Add callback for forward button

  const SearchResultsView({
    Key? key,
    required this.state,
    required this.isSelectionMode,
    required this.selectedFiles,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    required this.onClearSearch,
    this.onFolderTap,
    this.onFileTap,
    this.onBackButtonPressed, // New parameter
    this.onForwardButtonPressed, // New parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap the entire widget with a Listener to detect mouse button events
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // Mouse button 4 is usually the back button
        if (event.buttons == 8 && onBackButtonPressed != null) {
          onBackButtonPressed!();
        }
        // Mouse button 5 is usually the forward button
        else if (event.buttons == 16 && onForwardButtonPressed != null) {
          onForwardButtonPressed!();
        }
      },
      child: Column(
        children: [
          // Search results header with clear search button
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  _getSearchIcon(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(_getSearchTitle()),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClearSearch,
                  tooltip: 'Xóa tìm kiếm',
                ),
              ],
            ),
          ),

          // Results list
          Expanded(
            child: state.viewMode == ViewMode.grid
                ? _buildGridView()
                : _buildListView(),
          ),
        ],
      ),
    );
  }

  // Trả về biểu tượng phù hợp với loại tìm kiếm
  IconData _getSearchIcon() {
    if (state.currentSearchTag != null) {
      return Icons.local_offer;
    } else if (state.currentSearchQuery != null) {
      return Icons.search;
    } else if (state.currentMediaSearch != null) {
      switch (state.currentMediaSearch!) {
        // Using non-null assertion since we checked it's not null
        case MediaType.image:
          return Icons.photo;
        case MediaType.video:
          return Icons.movie;
        case MediaType.audio:
          return Icons.audio_file;
        case MediaType.document:
          return Icons.description;
      }
    }
    return Icons.search; // Default icon
  }

  // Tạo tiêu đề dựa trên loại tìm kiếm
  String _getSearchTitle() {
    // Đếm số lượng thư mục và tệp trong kết quả
    int folderCount = 0;
    int fileCount = 0;

    for (var entity in state.searchResults) {
      if (entity is Directory) {
        folderCount++;
      } else if (entity is File) {
        fileCount++;
      }
    }

    String countText = "";
    if (folderCount > 0 && fileCount > 0) {
      countText = " ($folderCount thư mục, $fileCount tệp)";
    } else if (folderCount > 0) {
      countText = " ($folderCount thư mục)";
    } else if (fileCount > 0) {
      countText = " ($fileCount tệp)";
    } else {
      countText = " (0 kết quả)";
    }

    if (state.currentSearchTag != null) {
      if (state.isGlobalSearch) {
        return 'Kết quả tìm kiếm toàn cục cho tag "${state.currentSearchTag}"$countText';
      } else {
        return 'Kết quả tìm kiếm cho tag "${state.currentSearchTag}"$countText';
      }
    } else if (state.currentSearchQuery != null) {
      return 'Kết quả tìm kiếm cho "${state.currentSearchQuery}"$countText';
    } else if (state.currentFilter != null) {
      return 'Kết quả lọc cho "${state.currentFilter}" (${state.filteredFiles.length} tệp)';
    } else if (state.currentMediaSearch != null) {
      String mediaType = "";
      switch (state.currentMediaSearch) {
        case MediaType.image:
          mediaType = "hình ảnh";
          break;
        case MediaType.video:
          mediaType = "video";
          break;
        case MediaType.audio:
          mediaType = "âm thanh";
          break;
        case MediaType.document:
          mediaType = "tài liệu";
          break;
      }
      return 'Kết quả tìm kiếm cho $mediaType$countText';
    }
    return 'Kết quả tìm kiếm$countText';
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final entity = state.searchResults[index];
        if (entity is File) {
          return folder_list_components.FileItem(
            file: entity,
            state: state,
            isSelectionMode: isSelectionMode,
            isSelected: selectedFiles.contains(entity.path),
            toggleFileSelection: toggleFileSelection,
            showDeleteTagDialog: showDeleteTagDialog,
            showAddTagToFileDialog: showAddTagToFileDialog,
            onFileTap: onFileTap, // Truyền callback cho file
          );
        } else if (entity is Directory) {
          // Hiển thị thư mục trong kết quả tìm kiếm
          return ListTile(
            leading: const Icon(Icons.folder, color: Colors.amber),
            // Show only folder name instead of full path
            title: Text(entity.path.split(Platform.pathSeparator).last),
            // Keep subtitle as full path for reference
            subtitle: Text(entity.path),
            onTap: () {
              if (onFolderTap != null) {
                // Sử dụng callback để chuyển đường dẫn trong tab hiện tại
                onFolderTap!(entity.path);
              }
            },
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: state.gridZoomLevel,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final entity = state.searchResults[index];
        if (entity is File) {
          return folder_list_components.FileGridItem(
            file: entity,
            state: state,
            isSelectionMode: isSelectionMode,
            isSelected: selectedFiles.contains(entity.path),
            toggleFileSelection: toggleFileSelection,
            toggleSelectionMode: toggleSelectionMode,
            onFileTap: onFileTap, // Truyền callback cho file
          );
        } else if (entity is Directory) {
          // Xử lý thư mục trong chế độ xem lưới
          return InkWell(
            onTap: () {
              if (onFolderTap != null) {
                // Sử dụng callback để chuyển đường dẫn trong tab hiện tại
                onFolderTap!(entity.path);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 48, color: Colors.amber),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      entity.path.split(Platform.pathSeparator).last,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
