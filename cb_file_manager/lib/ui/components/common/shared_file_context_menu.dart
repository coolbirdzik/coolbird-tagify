import 'dart:io';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import '../../controllers/file_operations_handler.dart';
import '../../screens/folder_list/file_details_screen.dart';
import '../../screens/media_gallery/image_viewer_screen.dart';
import '../../screens/media_gallery/video_player_full_screen.dart';
import '../../dialogs/open_with_dialog.dart';
import '../../../helpers/files/external_app_helper.dart';
import '../../../helpers/files/trash_manager.dart';
import 'package:path/path.dart' as pathlib;
import '../../tab_manager/components/tag_dialogs.dart' as tag_dialogs;
import '../../../services/network_browsing/webdav_service.dart';
import '../../../helpers/network/streaming_helper.dart';
import '../../../services/network_browsing/ftp_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../../config/languages/app_localizations.dart';
import 'package:cb_file_manager/bloc/selection/selection.dart';
import '../../../helpers/media/folder_thumbnail_service.dart';
import '../../../helpers/media/video_thumbnail_helper.dart';
import '../../utils/file_type_utils.dart';
import '../../dialogs/folder_thumbnail_picker_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';
import '../../screens/folder_list/folder_list_state.dart';
import '../../../helpers/files/windows_shell_context_menu.dart';
import '../../controllers/inline_rename_controller.dart';
import '../../../core/service_locator.dart';
import '../../../helpers/core/user_preferences.dart';

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
    final currentService = StreamingHelper.instance.currentNetworkService;
    String? webDavSize;
    String? webDavModified;
    String? remotePath;
    String? remoteFileName;
    if (currentService is WebDAVService) {
      remotePath = currentService.getRemotePathFromLocal(file.path);
      if (remotePath != null) {
        remoteFileName = pathlib.basename(remotePath);
        final meta = currentService.getMeta(remotePath);
        if (meta != null) {
          if (meta.size >= 0) {
            webDavSize = _formatSize(meta.size);
          }
          webDavModified = meta.modified.toString().split('.').first;
        }
      }
    } else if (currentService is FTPService) {
      // For FTP, UI path is used as key
      remotePath = file.path;
      remoteFileName = pathlib.basename(file.path);
      final meta = currentService.getMeta(file.path);
      if (meta != null) {
        if (meta.size >= 0) {
          webDavSize = _formatSize(meta.size);
        }
        if (meta.modified != null) {
          webDavModified = meta.modified!.toString().split('.').first;
        }
      }
    }

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
                    ? remix.Remix.video_line
                    : isImage
                        ? remix.Remix.image_line
                        : remix.Remix.file_3_line,
                color: isVideo
                    ? Colors.red
                    : isImage
                        ? Colors.blue
                        : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remoteFileName ?? _basename(file),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (webDavSize != null || webDavModified != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (webDavSize != null) ...[
                            const Icon(remix.Remix.hard_drive_2_line, size: 14),
                            const SizedBox(width: 4),
                            Text(webDavSize,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54)),
                          ],
                          if (webDavModified != null) ...[
                            const SizedBox(width: 12),
                            const Icon(remix.Remix.calendar_event_line,
                                size: 14),
                            const SizedBox(width: 4),
                            Text(webDavModified,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(remix.Remix.close_line),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Actions
        if (isVideo)
          ListTile(
            leading:
                const Icon(remix.Remix.play_circle_line, color: Colors.red),
            title: Text(
              AppLocalizations.of(context)!.playVideo,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () async {
              Navigator.pop(context);
              await _openVideoWithUserPreference(context, file);
            },
          ),

        if (isImage)
          ListTile(
            leading: const Icon(remix.Remix.image_line, color: Colors.blue),
            title: Text(
              AppLocalizations.of(context)!.viewImage,
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
          leading: const Icon(remix.Remix.eye_line),
          title: Text(
            AppLocalizations.of(context)!.openFile,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            ExternalAppHelper.openFileWithApp(file.path, 'shell_open');
          },
        ),

        ListTile(
          leading: const Icon(remix.Remix.external_link_line),
          title: Text(
            AppLocalizations.of(context)!.openWith,
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
        ListTile(
          leading: const Icon(remix.Remix.apps_line),
          title: Text(
            AppLocalizations.of(context)!.chooseDefaultApp,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => OpenWithDialog(
                filePath: file.path,
                saveAsDefaultOnSelect: true,
              ),
            );
          },
        ),

        if ((currentService is WebDAVService || currentService is FTPService) &&
            remotePath != null)
          ListTile(
            leading: const Icon(remix.Remix.download_line, color: Colors.blue),
            title: Text(
              AppLocalizations.of(context)!.download,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () async {
              Navigator.pop(context);
              try {
                final fileName = remoteFileName ?? _basename(file);
                final String? saveLocation = await FilePicker.platform.saveFile(
                  dialogTitle: 'Save "$fileName" as...',
                  fileName: fileName,
                );
                if (saveLocation == null) return;
                await StreamingHelper.instance
                    .downloadFile(file.path, saveLocation);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .downloadedTo(saveLocation))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .downloadFailed(e.toString())),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),

        // Copy option
        ListTile(
          leading: const Icon(remix.Remix.file_copy_line),
          title: Text(
            AppLocalizations.of(context)!.copy,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            FileOperationsHandler.copyToClipboard(
                context: context, entity: file);
          },
        ),

        // Cut option
        ListTile(
          leading: const Icon(remix.Remix.scissors_cut_line),
          title: Text(
            AppLocalizations.of(context)!.cut,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            FileOperationsHandler.cutToClipboard(
                context: context, entity: file);
          },
        ),

        // Rename option
        ListTile(
          leading: const Icon(remix.Remix.edit_line),
          title: Text(
            AppLocalizations.of(context)!.rename,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () async {
            Navigator.pop(context);
            await _renameEntity(context: context, entity: file);
          },
        ),

        // Tag management option - always show
        ListTile(
          leading: const Icon(remix.Remix.bookmark_line, color: Colors.green),
          title: Text(
            AppLocalizations.of(context)!.manageTags,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            if (showAddTagToFileDialog != null) {
              showAddTagToFileDialog!(context, file.path);
            } else {
              _showTagManagementDialog(context);
            }
          },
        ),

        // File details
        ListTile(
          leading: const Icon(remix.Remix.information_line),
          title: Text(
            AppLocalizations.of(context)!.properties,
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
          leading: const Icon(remix.Remix.delete_bin_2_line, color: Colors.red),
          title: Text(
            AppLocalizations.of(context)!.moveToTrash,
            style: const TextStyle(color: Colors.red),
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

  // Show tag management dialog
  void _showTagManagementDialog(BuildContext context) {
    tag_dialogs.showAddTagToFileDialog(context, file.path);
  }

  // Helper method to show delete confirmation dialog
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.moveItemsToTrashConfirmation(
            1, AppLocalizations.of(context)!.file)),
        content: Text(AppLocalizations.of(context)!
            .moveToTrashConfirmMessage(_basename(file))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _moveToTrash(context);
            },
            child: Text(
              AppLocalizations.of(context)!.moveToTrash.toUpperCase(),
              style: const TextStyle(color: Colors.red),
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
            content: Text(
                AppLocalizations.of(context)!.movedToTrash(_basename(file))),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.undo.toUpperCase(),
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
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .errorWithMessage(e.toString()))),
        );
      }
    }
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
  final List<String> folderTags;
  final Function(BuildContext, String)? showAddTagToFileDialog;

  const SharedFolderContextMenu({
    Key? key,
    required this.folder,
    this.onNavigate,
    this.folderTags = const [],
    this.showAddTagToFileDialog,
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
              Icon(remix.Remix.folder_line, color: Colors.amber[700]),
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
                icon: const Icon(remix.Remix.close_line),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Action items
        ListTile(
          leading: Icon(remix.Remix.folder_open_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.openFolder,
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
          leading: Icon(remix.Remix.file_copy_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.copy,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            FileOperationsHandler.copyToClipboard(
              context: context,
              entity: folder,
            );
          },
        ),

        // Cut option for folder
        ListTile(
          leading: Icon(remix.Remix.scissors_cut_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.cut,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            FileOperationsHandler.cutToClipboard(
              context: context,
              entity: folder,
            );
          },
        ),

        // Paste option for folder (if there's something in clipboard)
        ListTile(
          leading: Icon(remix.Remix.clipboard_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.pasteHere,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            FileOperationsHandler.pasteFromClipboard(
              context: context,
              destinationPath: folder.path,
            );
          },
        ),

        // Rename option for folder
        ListTile(
          leading: Icon(remix.Remix.edit_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.rename,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () async {
            Navigator.pop(context);
            await _renameEntity(context: context, entity: folder);
          },
        ),

        // Tag management option
        ListTile(
          leading: const Icon(remix.Remix.bookmark_line, color: Colors.green),
          title: Text(
            AppLocalizations.of(context)!.manageTags,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          onTap: () {
            Navigator.pop(context);
            _showTagManagementDialog(context);
          },
        ),

        // Properties
        ListTile(
          leading: Icon(remix.Remix.information_line,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          title: Text(
            AppLocalizations.of(context)!.properties,
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

  // Show tag management dialog for folders
  void _showTagManagementDialog(BuildContext context) {
    tag_dialogs.showAddTagToFileDialog(context, folder.path);
  }

  // Helper to show folder details
  void _showFolderDetails(BuildContext context) {
    folder.stat().then((stat) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.folderProperties),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow(
                    AppLocalizations.of(context)!.fileName, _basename(folder)),
                const Divider(),
                _infoRow(AppLocalizations.of(context)!.filePath, folder.path),
                const Divider(),
                _infoRow(AppLocalizations.of(context)!.fileModified,
                    stat.modified.toString().split('.')[0]),
                const Divider(),
                _infoRow(AppLocalizations.of(context)!.fileAccessed,
                    stat.accessed.toString().split('.')[0]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close.toUpperCase()),
            ),
          ],
        ),
      );
    }).catchError((error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .errorGettingFolderProperties(error.toString()))),
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
  required Offset globalPosition,
}) {
  // Always show positioned menu at cursor/tap location
  _showFileContextMenuDesktop(
    context: context,
    globalPosition: globalPosition,
    file: file,
    fileTags: fileTags,
    isVideo: isVideo,
    isImage: isImage,
    showAddTagToFileDialog: showAddTagToFileDialog,
  );
}

void _showFileContextMenuDesktop({
  required BuildContext context,
  required Offset globalPosition,
  required File file,
  required List<String> fileTags,
  required bool isVideo,
  required bool isImage,
  Function(BuildContext, String)? showAddTagToFileDialog,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final canShowShellMenu = Platform.isWindows &&
      FileSystemEntity.typeSync(file.path) != FileSystemEntityType.notFound;

  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & overlay.size,
  );

  showMenu<String>(
    context: context,
    position: position,
    items: [
      if (isVideo)
        PopupMenuItem(
          value: 'play_video',
          child: _menuRow(AppLocalizations.of(context)!.playVideo,
              remix.Remix.play_circle_line),
        ),
      if (isImage)
        PopupMenuItem(
          value: 'view_image',
          child: _menuRow(
              AppLocalizations.of(context)!.viewImage, remix.Remix.image_line),
        ),
      PopupMenuItem(
        value: 'open',
        child: _menuRow(
            AppLocalizations.of(context)!.open, remix.Remix.file_3_line),
      ),
      PopupMenuItem(
        value: 'open_with',
        child: _menuRow(AppLocalizations.of(context)!.openWith,
            remix.Remix.external_link_line),
      ),
      PopupMenuItem(
        value: 'choose_default_app',
        child: _menuRow(AppLocalizations.of(context)!.chooseDefaultApp,
            remix.Remix.apps_line),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'copy',
        child: _menuRow(
            AppLocalizations.of(context)!.copy, remix.Remix.file_copy_line),
      ),
      PopupMenuItem(
        value: 'cut',
        child: _menuRow(
            AppLocalizations.of(context)!.cut, remix.Remix.scissors_cut_line),
      ),
      PopupMenuItem(
        value: 'rename',
        child: _menuRow(
            AppLocalizations.of(context)!.rename, remix.Remix.edit_line),
      ),
      PopupMenuItem(
        value: 'tags',
        child: _menuRow(AppLocalizations.of(context)!.manageTags,
            remix.Remix.bookmark_line),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'properties',
        child: _menuRow(AppLocalizations.of(context)!.properties,
            remix.Remix.information_line),
      ),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(AppLocalizations.of(context)!.moveToTrash,
            remix.Remix.delete_bin_2_line,
            color: Colors.red),
      ),
      if (canShowShellMenu) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'more_options',
          child: _menuRow(AppLocalizations.of(context)!.moreOptions,
              remix.Remix.more_2_line),
        ),
      ],
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'play_video':
        await _openVideoWithUserPreference(context, file);
        break;
      case 'view_image':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ImageViewerScreen(file: file)),
        );
        break;
      case 'open':
        ExternalAppHelper.openFileWithApp(file.path, 'shell_open');
        break;
      case 'open_with':
        showDialog(
          context: context,
          builder: (context) => OpenWithDialog(filePath: file.path),
        );
        break;
      case 'choose_default_app':
        showDialog(
          context: context,
          builder: (context) => OpenWithDialog(
            filePath: file.path,
            saveAsDefaultOnSelect: value == 'choose_default_app',
          ),
        );
        break;
      case 'copy':
        FileOperationsHandler.copyToClipboard(context: context, entity: file);
        break;
      case 'cut':
        FileOperationsHandler.cutToClipboard(context: context, entity: file);
        break;
      case 'rename':
        await _renameEntity(context: context, entity: file);
        break;
      case 'tags':
        if (showAddTagToFileDialog != null) {
          showAddTagToFileDialog(context, file.path);
        } else {
          tag_dialogs.showAddTagToFileDialog(context, file.path);
        }
        break;
      case 'properties':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => FileDetailsScreen(file: file)),
        );
        break;
      case 'delete':
        _moveToTrashStandalone(context, file);
        break;
      case 'more_options':
        await WindowsShellContextMenu.showForPaths(
          paths: [file.path],
          globalPosition: globalPosition,
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
        );
        break;
    }
  });
}

Widget _menuRow(String title, IconData icon, {Color? color}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: color)),
    ],
  );
}

Future<void> _moveToTrashStandalone(BuildContext context, File file) async {
  final trashManager = TrashManager();
  try {
    await trashManager.moveToTrash(file.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_fileBaseName(file)} moved to trash'),
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

String _fileBaseName(File file) {
  return file.path.split(Platform.pathSeparator).last;
}

Future<void> _renameEntity({
  required BuildContext context,
  required FileSystemEntity entity,
}) async {
  if (_tryStartInlineRename(context, entity)) {
    return;
  }

  await FileOperationsHandler.showRenameDialog(
    context: context,
    entity: entity,
  );
}

bool _tryStartInlineRename(BuildContext context, FileSystemEntity entity) {
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (!isDesktop) {
    return false;
  }

  final ViewMode? viewMode = () {
    try {
      return context.read<FolderListBloc>().state.viewMode;
    } catch (_) {
      return null;
    }
  }();
  final bool supportsInlineRename = viewMode == ViewMode.grid ||
      viewMode == ViewMode.gridPreview ||
      viewMode == ViewMode.details;
  if (!supportsInlineRename) {
    return false;
  }

  final inlineRenameController = InlineRenameScope.maybeOf(context);
  if (inlineRenameController == null) {
    return false;
  }

  inlineRenameController.startRename(entity.path);
  return true;
}

Future<void> _openVideoWithUserPreference(
  BuildContext context,
  File file,
) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

  final openedPreferred =
      await ExternalAppHelper.openWithPreferredVideoApp(file.path);
  if (openedPreferred) return;

  bool useSystemDefault = false;
  try {
    useSystemDefault =
        await locator<UserPreferences>().getUseSystemDefaultForVideo();
  } catch (_) {
    useSystemDefault = false;
  }

  if (useSystemDefault) {
    final opened = await ExternalAppHelper.openWithSystemDefault(file.path);
    if (!opened && navigator.mounted) {
      await showDialog<void>(
        context: navigator.context,
        builder: (_) => OpenWithDialog(filePath: file.path),
      );
    }
    return;
  }

  if (!navigator.mounted) return;
  await navigator.push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerFullScreen(file: file),
    ),
  );
}

/// Helper function to show folder context menu
void showFolderContextMenu({
  required BuildContext context,
  required Directory folder,
  Function(String)? onNavigate,
  List<String> folderTags = const [],
  Function(BuildContext, String)? showAddTagToFileDialog,
  Offset? globalPosition, // Optional position for context menu
}) {
  // Always use popup menu at the provided position, or center of screen if not provided
  final screenSize = MediaQuery.of(context).size;
  final effectivePosition =
      globalPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);

  _showFolderContextMenuDesktop(
    context: context,
    globalPosition: effectivePosition,
    folder: folder,
    onNavigate: onNavigate,
    folderTags: folderTags,
    showAddTagToFileDialog: showAddTagToFileDialog,
  );
}

/// Desktop folder context menu using popup menu at cursor position
void _showFolderContextMenuDesktop({
  required BuildContext context,
  required Offset globalPosition,
  required Directory folder,
  Function(String)? onNavigate,
  List<String> folderTags = const [],
  Function(BuildContext, String)? showAddTagToFileDialog,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final canShowShellMenu = Platform.isWindows &&
      FileSystemEntity.typeSync(folder.path) != FileSystemEntityType.notFound;

  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & overlay.size,
  );
  final l10n = AppLocalizations.of(context)!;

  showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(
        value: 'open',
        child: _menuRow(l10n.openFolder, remix.Remix.folder_open_line),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'copy',
        child: _menuRow(l10n.copy, remix.Remix.file_copy_line),
      ),
      PopupMenuItem(
        value: 'cut',
        child: _menuRow(l10n.cut, remix.Remix.scissors_cut_line),
      ),
      PopupMenuItem(
        value: 'paste',
        child: _menuRow(l10n.pasteHere, remix.Remix.clipboard_line),
      ),
      PopupMenuItem(
        value: 'rename',
        child: _menuRow(l10n.rename, remix.Remix.edit_line),
      ),
      PopupMenuItem(
        value: 'tags',
        child: _menuRow(l10n.manageTags, remix.Remix.bookmark_line),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'properties',
        child: _menuRow(l10n.properties, remix.Remix.information_line),
      ),
      if (canShowShellMenu) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'more_options',
          child: _menuRow(l10n.moreOptions, remix.Remix.more_2_line),
        ),
      ],
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'open':
        if (onNavigate != null) {
          onNavigate(folder.path);
        }
        break;
      case 'copy':
        FileOperationsHandler.copyToClipboard(context: context, entity: folder);
        break;
      case 'cut':
        FileOperationsHandler.cutToClipboard(context: context, entity: folder);
        break;
      case 'paste':
        FileOperationsHandler.pasteFromClipboard(
          context: context,
          destinationPath: folder.path,
        );
        break;
      case 'rename':
        await _renameEntity(context: context, entity: folder);
        break;
      case 'tags':
        if (showAddTagToFileDialog != null) {
          showAddTagToFileDialog(context, folder.path);
        } else {
          tag_dialogs.showAddTagToFileDialog(context, folder.path);
        }
        break;
      case 'properties':
        _showFolderPropertiesDialog(context, folder);
        break;
      case 'more_options':
        await WindowsShellContextMenu.showForPaths(
          paths: [folder.path],
          globalPosition: globalPosition,
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
        );
        break;
    }
  });
}

void _showFolderPropertiesDialog(BuildContext context, Directory folder) {
  final folderName = folder.path.split(Platform.pathSeparator).last;
  final l10n = AppLocalizations.of(context)!;
  final thumbnailService = FolderThumbnailService();
  Future<String?> customThumbnailFuture =
      thumbnailService.getCustomThumbnailPath(folder.path);

  folder.stat().then((stat) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.properties),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _propertyRow(l10n.fileName, folderName),
                const Divider(),
                _propertyRow(l10n.filePath, folder.path),
                const Divider(),
                _propertyRow(
                    l10n.fileModified, stat.modified.toString().split('.')[0]),
                const Divider(),
                _propertyRow(
                    l10n.fileAccessed, stat.accessed.toString().split('.')[0]),
                const Divider(),
                Text(
                  l10n.folderThumbnail,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                FutureBuilder<String?>(
                  future: customThumbnailFuture,
                  builder: (context, snapshot) {
                    final value = snapshot.data;
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(l10n.loadingThumbnails);
                    }

                    if (value == null || value.isEmpty) {
                      return Text(l10n.thumbnailAuto);
                    }

                    final displayValue = value.startsWith('video::')
                        ? value.substring(7)
                        : value;
                    return Text(displayValue);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final selectedPath =
                            await showFolderThumbnailPickerDialog(
                          dialogContext,
                          folder.path,
                        );
                        if (selectedPath == null) {
                          return;
                        }

                        final isImage = FileTypeUtils.isImageFile(selectedPath);
                        final isVideo =
                            VideoThumbnailHelper.isSupportedVideoFormat(
                                selectedPath);
                        if (!isImage && !isVideo) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(l10n.invalidThumbnailFile)),
                            );
                          }
                          return;
                        }

                        await thumbnailService.setCustomThumbnail(
                          folder.path,
                          selectedPath,
                          isVideo: isVideo,
                        );
                        if (dialogContext.mounted) {
                          setState(() {
                            customThumbnailFuture = Future.value(isVideo
                                ? 'video::$selectedPath'
                                : selectedPath);
                          });
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.folderThumbnailSet)),
                          );
                        }
                      },
                      child: Text(l10n.chooseThumbnail.toUpperCase()),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        await thumbnailService
                            .clearCustomThumbnail(folder.path);
                        if (dialogContext.mounted) {
                          setState(() {
                            customThumbnailFuture = Future.value(null);
                          });
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.folderThumbnailCleared)),
                          );
                        }
                      },
                      child: Text(l10n.clearThumbnail.toUpperCase()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }).catchError((error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(l10n.errorGettingFolderProperties(error.toString()))),
    );
  });
}

Widget _propertyRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Helper function to show context menu for multiple selected files
void showMultipleFilesContextMenu({
  required BuildContext context,
  required List<String> selectedPaths,
  required Offset globalPosition,
  required VoidCallback onClearSelection,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final canShowShellMenu = Platform.isWindows &&
      selectedPaths.isNotEmpty &&
      selectedPaths.every((path) =>
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound);

  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & overlay.size,
  );

  final l10n = AppLocalizations.of(context)!;
  final count = selectedPaths.length;

  showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(
        enabled: false,
        child: Text(l10n.itemsSelected(count),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'copy',
        child: _menuRow(l10n.copy, remix.Remix.file_copy_line),
      ),
      PopupMenuItem(
        value: 'cut',
        child: _menuRow(l10n.cut, remix.Remix.scissors_cut_line),
      ),
      PopupMenuItem(
        value: 'tags',
        child: _menuRow(l10n.manageTags, remix.Remix.bookmark_line),
      ),
      PopupMenuItem(
        value: 'delete',
        child: _menuRow(l10n.deleteTitle, remix.Remix.delete_bin_2_line,
            color: Colors.red),
      ),
      if (canShowShellMenu) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'more_options',
          child: _menuRow(l10n.moreOptions, remix.Remix.more_2_line),
        ),
      ],
    ],
  ).then((value) {
    if (value == null) return;
    if (value == 'more_options') {
      WindowsShellContextMenu.showForPaths(
        paths: selectedPaths,
        globalPosition: globalPosition,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      return;
    }

    final bloc = context.read<FolderListBloc>();
    List<FileSystemEntity> entitiesList = [];
    List<String> files = [];
    List<String> folders = [];

    for (var path in selectedPaths) {
      if (FileSystemEntity.isDirectorySync(path)) {
        entitiesList.add(Directory(path));
        folders.add(path);
      } else {
        entitiesList.add(File(path));
        files.add(path);
      }
    }

    switch (value) {
      case 'copy':
        bloc.add(CopyFiles(entitiesList));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.copiedToClipboard('$count items'))),
        );
        break;
      case 'cut':
        bloc.add(CutFiles(entitiesList));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cutToClipboard('$count items'))),
        );
        break;
      case 'tags':
        // Show batch tag dialog for all selected items (files and folders)
        tag_dialogs.showBatchAddTagDialog(context, selectedPaths);
        break;
      case 'delete':
        SelectionBloc? selectionBloc;
        try {
          selectionBloc = context.read<SelectionBloc>();
        } catch (_) {
          selectionBloc = null;
        }
        FileOperationsHandler.handleDelete(
          context: context,
          folderListBloc: bloc,
          selectedFiles: files,
          selectedFolders: folders,
          selectionBloc: selectionBloc,
          permanent: false,
          onClearSelection: onClearSelection,
        );
        break;
    }
  });
}
