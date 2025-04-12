import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/components/shared_action_bar.dart';

import 'tag_dialogs.dart';

class FolderListAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPath;
  final bool isSelectionMode;
  final bool isGridView;
  final List<String> selectedFiles;
  final List<String> allTags;
  final Function() toggleViewMode;
  final Function() toggleSelectionMode;
  final Function() clearSelection;
  final Function() showSearchScreen;
  final Function() refresh;
  final Function(int) setGridZoomLevel;
  final int currentGridZoomLevel;

  const FolderListAppBar({
    Key? key,
    required this.currentPath,
    required this.isSelectionMode,
    required this.isGridView,
    required this.selectedFiles,
    required this.allTags,
    required this.toggleViewMode,
    required this.toggleSelectionMode,
    required this.clearSelection,
    required this.showSearchScreen,
    required this.refresh,
    required this.setGridZoomLevel,
    required this.currentGridZoomLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        isSelectionMode ? '${selectedFiles.length} selected' : 'Files',
      ),
      actions: _buildAppBarActions(context),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (isSelectionMode) {
      return [
        // Selection mode actions
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel selection',
          onPressed: clearSelection,
        ),
        if (selectedFiles.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.label),
            tooltip: 'Add tags',
            onPressed: () {
              showBatchAddTagDialog(context, selectedFiles);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete selected',
            onPressed: () {
              _showDeleteConfirmationDialog(context);
            },
          ),
        ],
      ];
    } else {
      // Normal mode actions
      return [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: showSearchScreen,
        ),
        // Add grid size adjustment button only when in grid view
        if (isGridView)
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'Adjust grid size',
            onPressed: () {
              _showGridSizeDialog(context);
            },
          ),
        IconButton(
          icon: Icon(isGridView ? Icons.list : Icons.grid_view),
          tooltip: isGridView ? 'List view' : 'Grid view',
          onPressed: toggleViewMode,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: refresh,
        ),
        SharedActionBar.buildMoreOptionsMenu(
          onSelectionModeToggled: toggleSelectionMode,
          onManageTagsPressed: () {
            showManageTagsDialog(context, allTags);
          },
          onGallerySelected: (value) {
            if (value == 'image_gallery') {
              // Open image gallery
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    path: currentPath,
                    recursive: false,
                  ),
                ),
              );
            } else if (value == 'video_gallery') {
              // Open video gallery
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoGalleryScreen(
                    path: currentPath,
                    recursive: false,
                  ),
                ),
              );
            }
          },
          currentPath: currentPath,
        ),
      ];
    }
  }

  void _showGridSizeDialog(BuildContext context) {
    int tempGridSize = currentGridZoomLevel;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Adjust Grid Size'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Columns: $tempGridSize'),
                  Slider(
                    value: tempGridSize.toDouble(),
                    min: UserPreferences.minGridZoomLevel.toDouble(),
                    max: UserPreferences.maxGridZoomLevel.toDouble(),
                    divisions: (UserPreferences.maxGridZoomLevel -
                        UserPreferences.minGridZoomLevel),
                    label: tempGridSize.toString(),
                    onChanged: (double value) {
                      setState(() {
                        tempGridSize = value.round();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _sizePreviewBox(2, tempGridSize),
                      _sizePreviewBox(3, tempGridSize),
                      _sizePreviewBox(4, tempGridSize),
                      _sizePreviewBox(5, tempGridSize),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _sizePreviewBox(6, tempGridSize),
                      _sizePreviewBox(7, tempGridSize),
                      _sizePreviewBox(8, tempGridSize),
                      _sizePreviewBox(9, tempGridSize),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _sizePreviewBox(10, tempGridSize),
                      _sizePreviewBox(11, tempGridSize),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Larger', style: TextStyle(fontSize: 12)),
                      Text('Smaller', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    setGridZoomLevel(tempGridSize);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sizePreviewBox(int size, int currentSize) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: currentSize == size ? Colors.blue : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.count(
            crossAxisCount: size,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              size * size,
              (index) => Container(
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$size',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selectedFiles.length} items?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete these items?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              BlocProvider.of<FolderListBloc>(context)
                  .add(FolderListDeleteFiles(selectedFiles));
              Navigator.of(context).pop();
              clearSelection();
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
