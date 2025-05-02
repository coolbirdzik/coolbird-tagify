import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/helpers/frame_timing_optimizer.dart';

import 'file_item.dart';
import 'file_grid_item.dart';
import 'folder_item.dart';
import 'folder_grid_item.dart';

class FileView extends StatelessWidget {
  final List<File> files;
  final List<Directory> folders;
  final FolderListState state;
  final bool isSelectionMode;
  final bool isGridView;
  final List<String> selectedFiles;
  final Function(String) toggleFileSelection;
  final Function() toggleSelectionMode;
  final Function(BuildContext, String, List<String>) showDeleteTagDialog;
  final Function(BuildContext, String) showAddTagToFileDialog;
  final Function(String)? onFolderTap;
  final Function(File, bool)? onFileTap; // Thêm callback cho file click

  const FileView({
    Key? key,
    required this.files,
    required this.folders,
    required this.state,
    required this.isSelectionMode,
    required this.isGridView,
    required this.selectedFiles,
    required this.toggleFileSelection,
    required this.toggleSelectionMode,
    required this.showDeleteTagDialog,
    required this.showAddTagToFileDialog,
    this.onFolderTap,
    this.onFileTap, // Thêm parameter mới
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Optimize frame timing before building view
    FrameTimingOptimizer().optimizeBeforeHeavyOperation();

    if (isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildListView() {
    // Optimize scrolling with frame timing
    FrameTimingOptimizer().optimizeScrolling();

    return ListView.builder(
      // Add better scrolling physics for smoother scrolling
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Add caching for better performance during scrolling
      cacheExtent: 500,
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        // Use RepaintBoundary to reduce rendering load during scrolling
        return RepaintBoundary(
          child: index < folders.length
              ? FolderItem(folder: folders[index], onTap: onFolderTap)
              : FileItem(
                  file: files[index - folders.length],
                  state: state,
                  isSelectionMode: isSelectionMode,
                  isSelected: selectedFiles
                      .contains(files[index - folders.length].path),
                  toggleFileSelection: toggleFileSelection,
                  showDeleteTagDialog: showDeleteTagDialog,
                  showAddTagToFileDialog: showAddTagToFileDialog,
                  onFileTap: onFileTap,
                ),
        );
      },
    );
  }

  Widget _buildGridView() {
    // Optimize scrolling with frame timing
    FrameTimingOptimizer().optimizeScrolling();

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      // Add physics for better scrolling performance
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Add caching for better scroll performance
      cacheExtent:
          500, // Cache more items to reduce loading during fast scrolling
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: state.gridZoomLevel,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        // Use RepaintBoundary for better rendering performance
        return RepaintBoundary(
          child: index < folders.length
              // Render folder item
              ? FolderGridItem(folder: folders[index], onTap: onFolderTap)
              // Render file item
              : FileGridItem(
                  file: files[index - folders.length],
                  state: state,
                  isSelectionMode: isSelectionMode,
                  isSelected: selectedFiles
                      .contains(files[index - folders.length].path),
                  toggleFileSelection: toggleFileSelection,
                  toggleSelectionMode: toggleSelectionMode,
                  onFileTap: onFileTap,
                ),
        );
      },
    );
  }
}
