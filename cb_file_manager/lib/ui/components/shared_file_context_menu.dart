import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/ui/dialogs/open_with_dialog.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:cb_file_manager/helpers/trash_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:path/path.dart' as pathlib;

/// A shared context menu for files
///
/// This menu is used by both grid view and list view to provide a consistent UI
class SharedFileContextMenu extends StatelessWidget {
  final File file;
  final List<String> fileTags;
  final bool isVideo;
  final bool isImage;
  final Function(BuildContext, String)? showAddTagToFileDialog;

  const SharedFileContextMenu({
    Key? key,
    required this.file,
    required this.fileTags,
    required this.isVideo,
    required this.isImage,
    this.showAddTagToFileDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with file icon and name
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isVideo
                    ? EvaIcons.videoOutline
                    : isImage
                        ? EvaIcons.imageOutline
                        : EvaIcons.fileOutline,
                color: isVideo
                    ? Colors.red
                    : isImage
                        ? Colors.blue
                        : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _basename(file),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Actions
        if (isVideo)
          ListTile(
            leading: const Icon(EvaIcons.playCircleOutline, color: Colors.red),
            title: Text(
              'Play Video',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerFullScreen(file: file),
                ),
              );
            },
          ),

        if (isImage)
          ListTile(
            leading: const Icon(EvaIcons.imageOutline, color: Colors.blue),
            title: Text(
              'View Image',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(file: file),
                ),
              );
            },
          ),

        ListTile(
          leading: const Icon(EvaIcons.eyeOutline),
          title: Text(
            'Open File',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            ExternalAppHelper.openFileWithApp(file.path, 'shell_open');
          },
        ),

        ListTile(
          leading: const Icon(EvaIcons.externalLinkOutline),
          title: Text(
            'Open With...',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => OpenWithDialog(filePath: file.path),
            );
          },
        ),

        // Copy option
        ListTile(
          leading: const Icon(EvaIcons.copyOutline),
          title: Text(
            'Copy',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            // Dispatch copy event to the bloc
            context.read<FolderListBloc>().add(CopyFile(file));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Copied "${_basename(file)}" to clipboard')),
            );
          },
        ),

        // Cut option
        ListTile(
          leading: const Icon(Icons.content_cut),
          title: Text(
            'Cut',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            // Dispatch cut event to the bloc
            context.read<FolderListBloc>().add(CutFile(file));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cut "${_basename(file)}" to clipboard')),
            );
          },
        ),

        // Rename option
        ListTile(
          leading: const Icon(EvaIcons.editOutline),
          title: Text(
            'Rename',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            _showRenameDialog(context);
          },
        ),

        // Tag management option
        if (showAddTagToFileDialog != null)
          ListTile(
            leading: const Icon(EvaIcons.bookmarkOutline, color: Colors.green),
            title: Text(
              'Manage Tags',
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.pop(context);
              showAddTagToFileDialog!(context, file.path);
            },
          ),

        // File details
        ListTile(
          leading: const Icon(EvaIcons.infoOutline),
          title: Text(
            'Properties',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FileDetailsScreen(file: file),
              ),
            );
          },
        ),

        // Move to trash
        ListTile(
          leading: const Icon(EvaIcons.trash2Outline, color: Colors.red),
          title: Text(
            'Move to Trash',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmDialog(context);
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // Helper method to show rename dialog
  void _showRenameDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final String fileName = _basename(file);
    final String extension = pathlib.extension(file.path);
    final String fileNameWithoutExt =
        pathlib.basenameWithoutExtension(file.path);

    // Pre-fill with current name without extension
    nameController.text = fileNameWithoutExt;
    nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: fileNameWithoutExt.length,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current name: $fileName'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'New name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final String newName = nameController.text.trim() + extension;
              if (newName.isEmpty || newName == fileName) {
                Navigator.pop(context);
                return;
              }

              // Dispatch rename event with correct event type
              context.read<FolderListBloc>().add(
                    RenameFileOrFolder(file, newName),
                  );
              Navigator.pop(context);

              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Renamed file to "$newName"')),
              );
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  // Helper method to show delete confirmation dialog
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text(
            'Are you sure you want to move "${_basename(file)}" to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _moveToTrash(context);
            },
            child: const Text(
              'MOVE TO TRASH',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to move file to trash
  Future<void> _moveToTrash(BuildContext context) async {
    final trashManager = TrashManager();
    try {
      await trashManager.moveToTrash(file.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_basename(file)} moved to trash'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await trashManager.restoreFromTrash(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Helper to get file extension
  String _getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  // Helper to get file basename
  String _basename(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }
}

/// A shared context menu for folders
class SharedFolderContextMenu extends StatelessWidget {
  final Directory folder;
  final Function(String)? onNavigate;

  const SharedFolderContextMenu({
    Key? key,
    required this.folder,
    this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with folder name and icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.folder, color: Colors.amber[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _basename(folder),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Action items
        ListTile(
          leading: Icon(Icons.folder_open_outlined,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Open Folder',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            if (onNavigate != null) {
              onNavigate!(folder.path);
            } else {
              Navigator.pushNamed(
                context,
                '/folder',
                arguments: {'path': folder.path},
              );
            }
          },
        ),

        // Copy option for folder
        ListTile(
          leading: Icon(EvaIcons.copyOutline,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Copy',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            // Dispatch copy event to the bloc
            context.read<FolderListBloc>().add(CopyFile(folder));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Copied "${_basename(folder)}" to clipboard')),
            );
          },
        ),

        // Cut option for folder
        ListTile(
          leading: Icon(Icons.content_cut,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Cut',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            // Dispatch cut event to the bloc
            context.read<FolderListBloc>().add(CutFile(folder));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Cut "${_basename(folder)}" to clipboard')),
            );
          },
        ),

        // Paste option for folder (if there's something in clipboard)
        ListTile(
          leading: Icon(Icons.content_paste,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Paste Here',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            // Dispatch paste event to the bloc
            context.read<FolderListBloc>().add(PasteFile(folder.path));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pasting...')),
            );
          },
        ),

        // Rename option for folder
        ListTile(
          leading: Icon(EvaIcons.editOutline,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Rename',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            _showRenameDialog(context);
          },
        ),

        // Properties
        ListTile(
          leading: Icon(Icons.info_outline,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            'Properties',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            _showFolderDetails(context);
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // Helper to show rename dialog
  void _showRenameDialog(BuildContext context) {
    final TextEditingController controller =
        TextEditingController(text: _basename(folder));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _basename(folder)) {
                context
                    .read<FolderListBloc>()
                    .add(RenameFileOrFolder(folder, newName));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed folder to "$newName"')),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  // Helper to show folder details
  void _showFolderDetails(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    folder.stat().then((stat) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Folder Properties'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('Name', _basename(folder)),
                const Divider(),
                _infoRow('Path', folder.path),
                const Divider(),
                _infoRow('Modified', stat.modified.toString().split('.')[0]),
                const Divider(),
                _infoRow('Accessed', stat.accessed.toString().split('.')[0]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }).catchError((error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting folder properties: $error')),
      );
    });
  }

  // Helper for folder properties display
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get folder basename
  String _basename(Directory dir) {
    String path = dir.path;
    // Handle trailing slash
    if (path.endsWith(Platform.pathSeparator)) {
      path = path.substring(0, path.length - 1);
    }
    return path.split(Platform.pathSeparator).last;
  }
}

/// Helper function to show file context menu
void showFileContextMenu({
  required BuildContext context,
  required File file,
  required List<String> fileTags,
  required bool isVideo,
  required bool isImage,
  Function(BuildContext, String)? showAddTagToFileDialog,
}) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SharedFileContextMenu(
      file: file,
      fileTags: fileTags,
      isVideo: isVideo,
      isImage: isImage,
      showAddTagToFileDialog: showAddTagToFileDialog,
    ),
  );
}

/// Helper function to show folder context menu
void showFolderContextMenu({
  required BuildContext context,
  required Directory folder,
  Function(String)? onNavigate,
}) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SharedFolderContextMenu(
      folder: folder,
      onNavigate: onNavigate,
    ),
  );
}
