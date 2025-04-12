import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';

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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildListView() {
    return ListView(
      children: [
        // Folders list
        ...folders.map((folder) => FolderItem(folder: folder)).toList(),

        // Files list
        ...files
            .map((file) => FileItem(
                  file: file,
                  state: state,
                  isSelectionMode: isSelectionMode,
                  isSelected: selectedFiles.contains(file.path),
                  toggleFileSelection: toggleFileSelection,
                  showDeleteTagDialog: showDeleteTagDialog,
                  showAddTagToFileDialog: showAddTagToFileDialog,
                ))
            .toList(),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: state
            .gridZoomLevel, // Sử dụng gridZoomLevel từ state thay vì hardcode 3
        childAspectRatio: 0.75,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          // Render folder item
          return FolderGridItem(folder: folders[index]);
        } else {
          // Render file item
          final fileIndex = index - folders.length;
          return FileGridItem(
            file: files[fileIndex],
            state: state,
            isSelectionMode: isSelectionMode,
            isSelected: selectedFiles.contains(files[fileIndex].path),
            toggleFileSelection: toggleFileSelection,
            toggleSelectionMode: toggleSelectionMode,
          );
        }
      },
    );
  }
}
