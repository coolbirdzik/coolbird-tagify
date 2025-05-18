import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/tab_manager/components/tag_dialogs.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

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
    // Get the last part of the path for the title
    final String title = isSelectionMode
        ? '${selectedFiles.length} selected'
        : currentPath.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      elevation: 0,
      actions: _buildAppBarActions(context),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (isSelectionMode) {
      return [
        // Grid size slider when in grid view and selection mode
        if (isGridView)
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14.0),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                ),
              ),
              child: Slider(
                value: currentGridZoomLevel.toDouble(),
                min: 2,
                max: 5,
                divisions: 3,
                onChanged: (value) => setGridZoomLevel(value.toInt()),
              ),
            ),
          ),
        // Action buttons for selection mode
        TextButton.icon(
          icon: Icon(EvaIcons.plusCircleOutline, size: 18),
          label: const Text('Tag'),
          onPressed: () => showBatchAddTagDialog(context, selectedFiles),
        ),
        TextButton.icon(
          icon: Icon(EvaIcons.trash2Outline, size: 18),
          label: const Text('Delete'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[400],
          ),
          onPressed: () {
            BlocProvider.of<FolderListBloc>(context)
                .add(FolderListDeleteFiles(selectedFiles));
            toggleSelectionMode();
          },
        ),
        IconButton(
          icon: Icon(EvaIcons.close, size: 24),
          tooltip: 'Cancel selection',
          onPressed: clearSelection,
        ),
        const SizedBox(width: 8),
      ];
    } else {
      return [
        // View toggle button
        IconButton(
          icon: Icon(
            isGridView ? EvaIcons.listOutline : EvaIcons.gridOutline,
            size: 24,
          ),
          tooltip: isGridView ? 'Switch to list view' : 'Switch to grid view',
          onPressed: toggleViewMode,
        ),
        // Grid size slider when in grid view
        if (isGridView)
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14.0),
              ),
              child: Slider(
                value: currentGridZoomLevel.toDouble(),
                min: 2,
                max: 5,
                divisions: 3,
                onChanged: (value) => setGridZoomLevel(value.toInt()),
              ),
            ),
          ),
        // Search button
        IconButton(
          icon: Icon(EvaIcons.searchOutline, size: 24),
          tooltip: 'Search',
          onPressed: showSearchScreen,
        ),
        // More actions menu
        PopupMenuButton<String>(
          icon: Icon(EvaIcons.moreVerticalOutline, size: 24),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                refresh();
                break;
              case 'select_all':
                toggleSelectionMode();
                break;
              case 'manage_tags':
                showManageTagsDialog(context, allTags, currentPath);
                break;
              case 'photo_gallery':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageGalleryScreen(path: currentPath),
                  ),
                );
                break;
              case 'video_gallery':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoGalleryScreen(path: currentPath),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(EvaIcons.refreshOutline,
                      size: 20, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  const Text('Refresh'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'select_all',
              child: Row(
                children: [
                  Icon(EvaIcons.checkmarkSquare2Outline,
                      size: 20, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  const Text('Select All'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'manage_tags',
              child: Row(
                children: [
                  Icon(EvaIcons.pricetags,
                      size: 20, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  const Text('Manage Tags'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'photo_gallery',
              child: Row(
                children: [
                  Icon(EvaIcons.imageOutline,
                      size: 20, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  const Text('Photo Gallery'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'video_gallery',
              child: Row(
                children: [
                  Icon(EvaIcons.videoOutline,
                      size: 20, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  const Text('Video Gallery'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ];
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
