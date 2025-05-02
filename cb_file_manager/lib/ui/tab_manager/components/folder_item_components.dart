import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/helpers/folder_thumbnail_service.dart';
import 'package:cb_file_manager/widgets/lazy_video_thumbnail.dart';
import 'package:path/path.dart' as path;

/// Component for displaying a folder item in grid view
class FolderGridItem extends StatelessWidget {
  final Directory folder;
  final Function(String) onNavigate;

  FolderGridItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onSecondaryTap: () => _showFolderContextMenu(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: InkWell(
          onTap: () => onNavigate(folder.path),
          onLongPress: () => _showFolderContextMenu(context),
          child: Column(
            children: [
              // Thumbnail/Icon section
              Expanded(
                flex: 3,
                child: FolderThumbnail(folder: folder),
              ),
              // Text section
              Container(
                height: 40,
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                alignment: Alignment.center,
                child: Text(
                  folder.basename(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FolderContextMenu(folder: folder),
    );
  }
}

/// Component for displaying a folder item in list view
class FolderListItem extends StatelessWidget {
  final Directory folder;
  final Function(String) onNavigate;

  FolderListItem({
    Key? key,
    required this.folder,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onSecondaryTap: () => _showContextMenuAtPosition(context),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: InkWell(
          onLongPress: () => _showFolderContextMenu(context),
          child: ListTile(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: FolderThumbnail(
                folder: folder,
                size: 40,
              ),
            ),
            title: Text(
              folder.basename(),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: FutureBuilder<FileStat>(
              future: folder.stat(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    '${snapshot.data!.modified.toString().split('.')[0]}',
                    style: TextStyle(
                        color:
                            isDarkMode ? Colors.grey[400] : Colors.grey[800]),
                  );
                }
                return Text('Loading...',
                    style: TextStyle(
                        color:
                            isDarkMode ? Colors.grey[500] : Colors.grey[700]));
              },
            ),
            onTap: () => onNavigate(folder.path),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'properties') {
                  _showFolderContextMenu(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'properties',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('Folder Properties'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenuAtPosition(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _showPopupMenu(context, position + Offset(size.width / 2, size.height / 2));
  }

  void _showPopupMenu(BuildContext context, Offset position) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.open_in_new,
                  color: isDarkMode ? Colors.white70 : Colors.black87),
              const SizedBox(width: 8),
              Text('Open',
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
          onTap: () => onNavigate(folder.path),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.settings,
                  color: isDarkMode ? Colors.white70 : Colors.black87),
              const SizedBox(width: 8),
              Text('Properties',
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showFolderContextMenu(context);
            });
          },
        ),
      ],
    );
  }

  void _showFolderContextMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FolderContextMenu(folder: folder),
    );
  }
}

/// Widget for displaying folder thumbnail
class FolderThumbnail extends StatefulWidget {
  final Directory folder;
  final double size;

  const FolderThumbnail({
    Key? key,
    required this.folder,
    this.size = 80,
  }) : super(key: key);

  @override
  State<FolderThumbnail> createState() => _FolderThumbnailState();
}

class _FolderThumbnailState extends State<FolderThumbnail> {
  final FolderThumbnailService _thumbnailService = FolderThumbnailService();
  String? _thumbnailPath;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(FolderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder.path != widget.folder.path) {
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (_disposed) return;

    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final path =
          await _thumbnailService.getFolderThumbnail(widget.folder.path);

      if (_disposed) return;

      setState(() {
        _thumbnailPath = path;
        _isLoading = false;
      });

      debugPrint('Loaded thumbnail for folder: ${widget.folder.path}');
      debugPrint('Thumbnail path: ${_thumbnailPath ?? "null"}');
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (!_disposed) {
        setState(() {
          _thumbnailPath = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  bool _isVideoPath(String? path) {
    if (path == null) return false;
    return path.startsWith("video::");
  }

  String _getVideoPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[1];
    }
    return path.substring(7);
  }

  String _getThumbnailPath(String path) {
    if (!path.startsWith("video::")) return path;

    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[2];
    }
    return path.substring(7);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: SizedBox(
          width: widget.size * 0.5,
          height: widget.size * 0.5,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Default folder icon when no thumbnail
    if (_thumbnailPath == null || _loadFailed) {
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }

    final bool isVideo = _isVideoPath(_thumbnailPath);
    final String videoPath = _getVideoPath(_thumbnailPath!);
    final String thumbnailPath = _getThumbnailPath(_thumbnailPath!);

    try {
      if (isVideo) {
        if (!File(videoPath).existsSync()) {
          debugPrint('Video file does not exist: $videoPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          // Use AspectRatio to maintain proper video aspect ratio
          child: Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9, // Standard video aspect ratio
                child: LazyVideoThumbnail(
                  videoPath: videoPath,
                  width: double.infinity,
                  height: double.infinity,
                  keepAlive: true,
                  fallbackBuilder: () => Container(
                    color: Colors.blueGrey[900],
                    child: Center(
                      child: Icon(
                        EvaIcons.videoOutline,
                        size: widget.size * 0.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: widget.size * 0.25 < 16 ? widget.size * 0.25 : 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final file = File(thumbnailPath);
        if (!file.existsSync()) {
          debugPrint('Image file does not exist: $thumbnailPath');
          return Center(
            child: Icon(
              EvaIcons.folderOutline,
              size: widget.size * 0.7,
              color: Colors.amber[700],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.amber[600]!,
              width: 1.5,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1, // Square aspect ratio for images
            child: Image.file(
              file,
              fit: BoxFit.contain, // Use contain to respect aspect ratio
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.medium,
              cacheWidth: (widget.size * 3).toInt(),
              cacheHeight: (widget.size * 3).toInt(),
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image loading error: $error');
                return Center(
                  child: Icon(
                    EvaIcons.folderOutline,
                    size: widget.size * 0.7,
                    color: Colors.amber[700],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating image widget: $e');
      return Center(
        child: Icon(
          EvaIcons.folderOutline,
          size: widget.size * 0.7,
          color: Colors.amber[700],
        ),
      );
    }
  }
}

/// Context menu for folders
class FolderContextMenu extends StatefulWidget {
  final Directory folder;

  const FolderContextMenu({
    Key? key,
    required this.folder,
  }) : super(key: key);

  @override
  State<FolderContextMenu> createState() => _FolderContextMenuState();
}

class _FolderContextMenuState extends State<FolderContextMenu> {
  final FolderThumbnailService _thumbnailService = FolderThumbnailService();
  bool _isLoadingMedia = false;
  List<File> _mediaFiles = [];
  String? _currentThumbnailPath;
  bool _hasCustomThumbnail = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingMedia = true;
    });

    try {
      // Check if there's a custom thumbnail
      _hasCustomThumbnail =
          _thumbnailService.hasCustomThumbnail(widget.folder.path);

      // Get current thumbnail
      _currentThumbnailPath =
          await _thumbnailService.getFolderThumbnail(widget.folder.path);

      // Load media files for selection
      _mediaFiles = await _thumbnailService
          .getMediaFilesForThumbnailSelection(widget.folder.path);
    } catch (e) {
      debugPrint('Error loading folder media: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMedia = false;
        });
      }
    }
  }

  // Helper function to check if path is a video with special prefix
  bool _isVideoThumbnail(String? path) {
    return path != null && path.startsWith("video::");
  }

  // Extract the original video path from the combined path
  String _getVideoPath(String path) {
    if (!path.startsWith("video::")) return path;

    // New format: video::originalVideoPath::thumbnailPath
    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[1]; // Return the original video path
    }
    // Old format fallback: video::path
    return path.substring(7);
  }

  // Extract the thumbnail path from the combined path
  String _getThumbnailPath(String path) {
    if (!path.startsWith("video::")) return path;

    // New format: video::originalVideoPath::thumbnailPath
    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[2]; // Return the thumbnail path
    }
    // Old format fallback: video::path
    return path.substring(7);
  }

  // Helper function to get actual path without video:: prefix
  String _getActualPath(String? path) {
    if (path == null) return "";
    if (!path.startsWith("video::")) return path;

    // New format: video::originalVideoPath::thumbnailPath
    final parts = path.split("::");
    if (parts.length >= 3) {
      return parts[2]; // Return the thumbnail path for display
    }
    // Old format fallback: video::path
    return path.substring(7);
  }

  // Helper to check if a file should be highlighted as the current thumbnail
  bool _isCurrentThumbnail(File file, bool isVideo) {
    if (_currentThumbnailPath == null) return false;

    if (_isVideoThumbnail(_currentThumbnailPath)) {
      if (!isVideo) return false; // Not a match if comparing video with image

      // For video thumbnails, compare the original video path
      final currentVideoPath = _getVideoPath(_currentThumbnailPath!);
      return file.path == currentVideoPath;
    } else {
      // For regular images, direct comparison
      return _currentThumbnailPath == file.path;
    }
  }

  Future<void> _setCustomThumbnail(String filePath) async {
    await _thumbnailService.setCustomThumbnail(widget.folder.path, filePath);
    setState(() {
      _currentThumbnailPath = filePath;
      _hasCustomThumbnail = true;
    });
    // Close bottom sheet
    if (mounted) {
      Navigator.pop(context);
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder thumbnail updated')),
      );
    }
  }

  Future<void> _resetThumbnail() async {
    await _thumbnailService.clearCustomThumbnail(widget.folder.path);
    setState(() {
      _hasCustomThumbnail = false;
    });
    await _loadData(); // Reload data to show auto thumbnail
    // Show confirmation
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder thumbnail reset to automatic')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
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
                    'Folder Properties',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Folder info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current thumbnail preview
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _currentThumbnailPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: _isVideoThumbnail(_currentThumbnailPath)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Actual video thumbnail image
                                    Image.file(
                                      File(_getActualPath(
                                          _currentThumbnailPath!)),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        debugPrint(
                                            'Error loading video thumbnail: $error');
                                        return Container(
                                          color: Colors.blueGrey[800],
                                          child: Center(
                                            child: Icon(
                                              Icons.movie_outlined,
                                              size: 40,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Play button overlay
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(
                                  File(_getActualPath(_currentThumbnailPath!)),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        'Error loading image in context menu: $error');
                                    return Icon(
                                      Icons.folder,
                                      size: 40,
                                      color: Colors.amber[700],
                                    );
                                  },
                                ),
                        )
                      : Icon(
                          Icons.folder,
                          size: 40,
                          color: Colors.amber[700],
                        ),
                ),
                const SizedBox(width: 16),

                // Folder details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.folder.basename(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.folder.path,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasCustomThumbnail
                            ? 'Custom thumbnail set'
                            : 'Automatic thumbnail',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasCustomThumbnail
                              ? Colors.green[700]
                              : (isDarkMode
                                  ? Colors.blue[300]
                                  : Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Thumbnail options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thumbnail Options',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Reset thumbnail button
                if (_hasCustomThumbnail)
                  ElevatedButton.icon(
                    onPressed: _resetThumbnail,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset to Automatic Thumbnail'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      foregroundColor: textColor,
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  'Choose from media files in this folder:',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Media files grid
          Flexible(
            child: _isLoadingMedia
                ? const Center(child: CircularProgressIndicator())
                : _mediaFiles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No media files found in this folder',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        itemCount: _mediaFiles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final file = _mediaFiles[index];
                          final extension =
                              path.extension(file.path).toLowerCase();
                          final isVideo = [
                            '.mp4',
                            '.mkv',
                            '.mov',
                            '.avi',
                            '.wmv',
                            '.webm',
                            '.flv'
                          ].contains(extension);

                          // Check if this file matches the current thumbnail (handling video:: prefix)
                          final bool isCurrentThumbnail =
                              _isCurrentThumbnail(file, isVideo);

                          return GestureDetector(
                            onTap: () => _setCustomThumbnail(
                                isVideo ? "video::${file.path}" : file.path),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isCurrentThumbnail
                                          ? Colors.blue
                                          : isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                      width: isCurrentThumbnail ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: isVideo
                                        ? LazyVideoThumbnail(
                                            videoPath: file.path,
                                            width: 80,
                                            height: 80,
                                            keepAlive: true,
                                            fallbackBuilder: () => Container(
                                              color: Colors.blueGrey[800],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.movie_outlined,
                                                  size: 30,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Image.file(
                                            file,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(Icons.broken_image),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                if (isVideo && !isCurrentThumbnail)
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                if (isCurrentThumbnail)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
