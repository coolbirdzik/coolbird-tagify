import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/models/objectbox/album.dart';
import 'package:cb_file_manager/models/objectbox/album_file.dart';
import 'package:cb_file_manager/services/album_service.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_viewer_screen.dart';
import 'package:cb_file_manager/ui/utils/route.dart';
import 'package:cb_file_manager/ui/widgets/app_progress_indicator.dart';

import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'create_album_dialog.dart';
import 'batch_add_dialog.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/components/common/shared_action_bar.dart';
import 'package:cb_file_manager/ui/components/common/skeleton_helper.dart';
import 'package:cb_file_manager/services/smart_album_service.dart';
import 'package:cb_file_manager/services/album_auto_rule_service.dart';
import 'auto_rules_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({
    Key? key,
    required this.album,
  }) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final AlbumService _albumService = AlbumService.instance;

  List<AlbumFile> _albumFiles = [];
  List<File> _imageFiles = [];
  List<File> _originalImageFiles = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};
  double _thumbnailSize = 3.0; // Grid crossAxisCount
  String? _searchQuery;
  bool _isShuffled = false;
  late UserPreferences _preferences;
  bool _isSmartAlbum = false;
  bool _cancelSmartScan = false;
  Timer? _autoRescanTimer;
  int _activeRulesCount = 0;
  int _sourceFoldersCount = 0;
  DateTime? _lastScanTime;

  // Listen album updates to refresh UI incrementally
  StreamSubscription<int>? _albumUpdateSub;
  StreamSubscription<Map<String, dynamic>>? _progressSub;
  Timer? _refreshDebounce;

  // Progress tracking state
  bool _isBackgroundProcessing = false;
  int _currentProgress = 0;
  int _totalProgress = 0;
  String _progressStatus = '';
  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    _preferences = UserPreferences.instance;
    _loadGridPreference();
    _initSmartStateAndLoad();

    // Subscribe to album updates and refresh grid progressively
    _albumUpdateSub = AlbumService.instance.albumUpdatedStream
        .where((id) => id == widget.album.id)
        .listen((_) => _scheduleAlbumReload());

    // Subscribe to progress updates
    _progressSub = AlbumService.instance.progressStream
        .where((progress) => progress['albumId'] == widget.album.id)
        .listen(_handleProgressUpdate);
  }

  Future<void> _initSmartStateAndLoad() async {
    try {
      _isSmartAlbum =
          await SmartAlbumService.instance.isSmartAlbum(widget.album.id);
    } catch (_) {
      _isSmartAlbum = false;
    }
    if (mounted) {
      if (_isSmartAlbum) {
        await _refreshSmartStatus();
        await _loadCachedSmartImages();
        _startAutoRescan();
      }
      _loadAlbumFiles(initial: true);
    }
  }

  Future<void> _refreshSmartStatus() async {
    try {
      final allRules = await AlbumAutoRuleService.instance.loadRules();
      final rules = allRules
          .where((r) => r.albumId == widget.album.id && r.isActive)
          .toList();
      final roots =
          await SmartAlbumService.instance.getScanRoots(widget.album.id);
      final last =
          await SmartAlbumService.instance.getLastScanTime(widget.album.id);
      if (mounted) {
        setState(() {
          _activeRulesCount = rules.length;
          _sourceFoldersCount = roots.length;
          _lastScanTime = last;
        });
      }
    } catch (_) {}
  }

  String _smartStatusText() {
    final last = _lastScanTime != null
        ? DateFormat('HH:mm dd/MM').format(_lastScanTime!)
        : 'Never';
    return '$_activeRulesCount rules • $_sourceFoldersCount sources • Last: $last';
  }

  Future<void> _loadGridPreference() async {
    try {
      await _preferences.init();
      final size = await _preferences.getImageGalleryThumbnailSize();
      if (mounted) {
        setState(() {
          _thumbnailSize = size;
        });
      }
    } catch (_) {}
  }

  void _handleProgressUpdate(Map<String, dynamic> progress) {
    // Debounce progress updates to avoid spamming UI thread
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isBackgroundProcessing = progress['status'] != 'completed' &&
              progress['status'] != 'error';
          _currentProgress = progress['current'] ?? 0;
          _totalProgress = progress['total'] ?? 0;

          switch (progress['status']) {
            case 'scanning':
              _progressStatus = 'Scanning files...';
              break;
            case 'processing':
              _progressStatus =
                  'Adding files... ($_currentProgress/$_totalProgress)';
              break;
            case 'completed':
              _progressStatus = 'Completed!';
              // Hide progress after 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _isBackgroundProcessing = false;
                  });
                }
              });
              break;
            case 'error':
              _progressStatus =
                  'Error: ${progress['error'] ?? 'Unknown error'}';
              break;
          }
        });
      }
    });
  }

  Future<void> _loadAlbumFiles({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (_isSmartAlbum) {
        await _scanSmartAlbumImages();
        return;
      }

      final albumFiles = await _albumService.getAlbumFiles(widget.album.id);
      final imageFiles = <File>[];

      for (final albumFile in albumFiles) {
        final file = File(albumFile.filePath);
        if (await file.exists()) {
          imageFiles.add(file);
        }
      }

      if (mounted) {
        setState(() {
          _albumFiles = albumFiles;
          _originalImageFiles = List<File>.from(imageFiles);
          _applyFiltersAndOrder();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading album files: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanSmartAlbumImages() async {
    // Load active rules for this album
    final allRules = await AlbumAutoRuleService.instance.loadRules();
    final rules = allRules
        .where((r) => r.albumId == widget.album.id && r.isActive)
        .toList();
    if (mounted) {
      // Immediately prune any currently displayed items that no longer match rules
      if (rules.isNotEmpty && _originalImageFiles.isNotEmpty) {
        _originalImageFiles = _originalImageFiles.where((f) {
          final base = pathlib.basename(f.path);
          return rules.any((r) => r.matches(base));
        }).toList();
        _applyFiltersAndOrder();
      } else if (rules.isEmpty) {
        // No rules -> clear current items to reflect new config
        _originalImageFiles = [];
        _applyFiltersAndOrder();
      }
      setState(() {
        // Keep current cached display; only update incrementally during scan
        _cancelSmartScan = false;
        _isBackgroundProcessing = true;
        _isLoading = false; // Ensure grid is visible while scanning
        _progressStatus = rules.isEmpty
            ? 'No rules configured for this album'
            : 'Scanning...';
        _currentProgress = 0;
        _totalProgress = 0; // Unknown total -> indeterminate
      });
    }

    if (rules.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundProcessing = false;
        });
      }
      return;
    }

    // Use configured scan roots if available; otherwise, stop and ask user to configure
    List<String> roots =
        await SmartAlbumService.instance.getScanRoots(widget.album.id);
    if (roots.isEmpty) {
      if (mounted) {
        setState(() {
          _isBackgroundProcessing = false;
          _progressStatus = 'No scan locations configured';
        });
      }
      return;
    }
    int matched = 0;
    int processed = 0;
    final imageExts = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.tif',
      '.tiff'
    };

    Future<void> scanDir(Directory dir) async {
      try {
        await for (final entity
            in dir.list(recursive: false, followLinks: false)) {
          if (_cancelSmartScan) return;
          if (entity is File) {
            processed++;
            final ext = pathlib.extension(entity.path).toLowerCase();
            if (imageExts.contains(ext)) {
              final name = pathlib.basename(entity.path);
              if (rules.any((r) => r.matches(name))) {
                matched++;
                if (mounted) {
                  if (!_originalImageFiles.any((f) => f.path == entity.path)) {
                    _originalImageFiles.add(entity);
                  }
                  // Apply filters in-place to update UI progressively
                  _applyFiltersAndOrder();
                  // Update status occasionally
                  if (matched % 20 == 0 || processed % 200 == 0) {
                    setState(() {
                      _progressStatus = 'Scanning device... matched $matched';
                    });
                  }
                }
              }
            }
          } else if (entity is Directory) {
            // Recurse into subdirectory
            await scanDir(entity);
          }
        }
      } catch (_) {
        // Ignore directories we cannot access
      }
    }

    for (final rootPath in roots) {
      if (_cancelSmartScan) break;
      await scanDir(Directory(rootPath));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isBackgroundProcessing = false;
        _progressStatus = 'Completed! Found $matched images';
      });
    }

    // Cache results
    try {
      await SmartAlbumService.instance.setCachedFiles(
          widget.album.id, _originalImageFiles.map((f) => f.path).toList());
    } catch (_) {}
  }

  Future<List<String>> _getStorageRoots() async {
    final roots = <String>[];
    try {
      if (Platform.isAndroid) {
        // Typical Android storage roots
        final base = Directory('/storage');
        if (await base.exists()) {
          try {
            await for (final entity in base.list(recursive: false)) {
              if (entity is Directory) roots.add(entity.path);
            }
          } catch (_) {}
        }
        // Ensure the primary internal storage is included
        const emu0 = '/storage/emulated/0';
        if (await Directory(emu0).exists()) roots.add(emu0);
      } else if (Platform.isWindows) {
        for (var c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
          final drive = Directory('$c:\\');
          try {
            if (await drive.exists()) roots.add(drive.path);
          } catch (_) {}
        }
      } else if (Platform.isMacOS) {
        // macOS volumes
        final vols = Directory('/Volumes');
        if (await vols.exists()) {
          try {
            await for (final entity in vols.list(recursive: false)) {
              if (entity is Directory) roots.add(entity.path);
            }
          } catch (_) {}
        }
        // Home directory
        final home = Directory(Platform.environment['HOME'] ?? '');
        if (await home.exists()) roots.add(home.path);
      } else {
        // Linux and others
        final home = Directory(Platform.environment['HOME'] ?? '');
        if (await home.exists()) roots.add(home.path);
        for (final p in ['/mnt', '/media']) {
          final d = Directory(p);
          if (await d.exists()) {
            try {
              await for (final e in d.list(recursive: false)) {
                if (e is Directory) roots.add(e.path);
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // Deduplicate
    return roots.toSet().toList();
  }

  Future<void> _loadCachedSmartImages() async {
    try {
      final cached =
          await SmartAlbumService.instance.getCachedFiles(widget.album.id);
      if (cached.isNotEmpty && mounted) {
        // Load current active rules for this album and filter cached list to avoid stale/unfiltered cache
        final allRules = await AlbumAutoRuleService.instance.loadRules();
        final rules = allRules
            .where((r) => r.albumId == widget.album.id && r.isActive)
            .toList();

        final files = <File>[];
        for (final p in cached) {
          final f = File(p);
          if (f.existsSync()) {
            if (rules.isEmpty) {
              // If no rules, show nothing until a scan happens (consistent with scan path)
              // Skip adding files
            } else {
              final base = pathlib.basename(p);
              if (rules.any((r) => r.matches(base))) {
                files.add(f);
              }
            }
          }
        }

        setState(() {
          _originalImageFiles = files;
          _applyFiltersAndOrder();
          _isLoading = false;
        });
      }
    } catch (_) {}
  }

  void _startAutoRescan() {
    _autoRescanTimer?.cancel();
    // Auto rescan every 5 minutes (lightweight incremental without true FS watchers)
    _autoRescanTimer = Timer.periodic(const Duration(minutes: 5), (t) {
      if (!_isBackgroundProcessing) {
        _scanSmartAlbumImages();
      }
    });
  }

  Future<void> _showManageSourcesDialog() async {
    final service = SmartAlbumService.instance;
    List<String> roots = await service.getScanRoots(widget.album.id);

    await showDialog(
      context: context,
      builder: (context) {
        List<String> localRoots = List.from(roots);
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Scan Locations'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (localRoots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'No locations selected. Add folders to scan for this album.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: localRoots.length,
                      itemBuilder: (context, index) {
                        final p = localRoots[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder),
                          title: Text(p,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                localRoots.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final dir =
                            await FilePicker.platform.getDirectoryPath();
                        if (dir != null && dir.isNotEmpty) {
                          setState(() {
                            if (!localRoots.contains(dir)) localRoots.add(dir);
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add folder'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await service.setScanRoots(widget.album.id, localRoots);
                  if (mounted) Navigator.pop(context);
                  // Re-scan with new roots
                  if (mounted && _isSmartAlbum) {
                    _scanSmartAlbumImages();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleAlbumReload() {
    // No debounce for instant UI feedback
    if (mounted) {
      _loadAlbumFiles();
    }
  }

  void _applyFiltersAndOrder() {
    // Start from original list
    List<File> files = List<File>.from(_originalImageFiles);

    // Apply search filter
    if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
      final q = _searchQuery!.toLowerCase();
      files = files
          .where((f) => pathlib.basename(f.path).toLowerCase().contains(q))
          .toList();
    }

    // Apply shuffle
    if (_isShuffled) {
      files.shuffle();
    }

    _imageFiles = files;
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
      _applyFiltersAndOrder();
    });
  }

  void _showSearchDialog() {
    String query = _searchQuery ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search in Album'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter image name...',
            prefixIcon: Icon(Icons.search),
          ),
          controller: TextEditingController(text: query),
          onChanged: (value) => query = value,
          onSubmitted: (_) {
            RouteUtils.safePopDialog(context);
            setState(() {
              _searchQuery = query.trim().isEmpty ? null : query.trim();
              _applyFiltersAndOrder();
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              RouteUtils.safePopDialog(context);
              setState(() {
                _searchQuery = query.trim().isEmpty ? null : query.trim();
                _applyFiltersAndOrder();
              });
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFilesMenu() async {
    final result = await showDialog(
      context: context,
      builder: (context) => BatchAddDialog(albumId: widget.album.id),
    );

    if (result != null && mounted) {
      String message;
      if (result is Map<String, dynamic>) {
        if (result.containsKey('error')) {
          message = 'Error: ${result['error']}';
        } else if (result.containsKey('background')) {
          message = 'Adding files in background...';
        } else {
          final added = result['added'] ?? 0;
          final total = result['total'] ?? 0;
          message = 'Added $added out of $total files';
        }
      } else {
        message = 'Files added successfully';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Only reload if not background operation
      if (result is Map<String, dynamic> && !result.containsKey('background')) {
        _loadAlbumFiles();
      }
    }
  }

  Future<void> _editAlbum() async {
    final result = await showDialog<Album>(
      context: context,
      builder: (context) => CreateAlbumDialog(editingAlbum: widget.album),
    );

    if (result != null) {
      // Update the album reference and reload if needed
      setState(() {
        // The album object is updated in place
      });
    }
  }

  Future<void> _removeSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Remove ${_selectedFilePaths.length} ${_selectedFilePaths.length == 1 ? 'image' : 'images'}?'),
        content: const Text(
            'Remove selected images from this album? The original files will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int successCount = 0;
      for (final filePath in _selectedFilePaths) {
        if (await _albumService.removeFileFromAlbum(
            widget.album.id, filePath)) {
          successCount++;
        }
      }

      setState(() {
        _isSelectionMode = false;
        _selectedFilePaths.clear();
      });

      await _loadAlbumFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Removed $successCount ${successCount == 1 ? 'image' : 'images'} from album'),
          ),
        );
      }
    }
  }

  Widget _buildGridView() {
    final columns = _thumbnailSize.round();
    final thumbSize = _calculateThumbnailSize(context, columns);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (thumbSize * pixelRatio).round();

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) {
        final file = _imageFiles[index];
        final isSelected = _selectedFilePaths.contains(file.path);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedFilePaths.remove(file.path);
                } else {
                  _selectedFilePaths.add(file.path);
                }
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    file: file,
                    imageFiles: _imageFiles,
                    initialIndex: index,
                  ),
                ),
              );
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedFilePaths.add(file.path);
              });
            }
          },
          child: RepaintBoundary(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[200],
                    child: Hero(
                      tag: file.path,
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        cacheWidth: cacheWidth,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: frame != null
                                ? child
                                : SkeletonHelper.box(
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.blue : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateThumbnailSize(BuildContext context, int columns) {
    const double padding = 8.0; // outer padding
    const double spacing = 8.0; // grid spacing
    final double width = MediaQuery.of(context).size.width;
    final double totalSpacing = (columns - 1) * spacing + padding * 2;
    final double available = (width - totalSpacing).clamp(50.0, width);
    return available / columns;
  }

  @override
  void dispose() {
    _albumUpdateSub?.cancel();
    _progressSub?.cancel();
    _refreshDebounce?.cancel();
    _progressDebounce?.cancel();
    _autoRescanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelectionMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${_selectedFilePaths.length} selected'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedFilePaths.clear();
              });
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.remove_circle),
              tooltip: 'Remove from album',
              onPressed:
                  _selectedFilePaths.isEmpty ? null : _removeSelectedFiles,
            ),
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: () {
                setState(() {
                  if (_selectedFilePaths.length == _imageFiles.length) {
                    _selectedFilePaths.clear();
                  } else {
                    _selectedFilePaths.addAll(_imageFiles.map((f) => f.path));
                  }
                });
              },
            ),
          ],
        ),
        body: _buildGridView(),
      );
    }

    return BaseScreen(
      title: widget.album.name,
      automaticallyImplyLeading: true,
      actions: [
        // Quick selection toggle
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select Images',
          onPressed: () {
            setState(() {
              _isSelectionMode = true;
            });
          },
        ),
        // Search in album
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: _showSearchDialog,
        ),
        // Grid size control
        IconButton(
          icon: const Icon(Icons.grid_view),
          tooltip: 'Grid Size',
          onPressed: () => SharedActionBar.showGridSizeDialog(
            context,
            currentGridSize: _thumbnailSize.round(),
            onApply: (size) async {
              setState(() {
                _thumbnailSize = size.toDouble();
              });
              try {
                await _preferences
                    .setImageGalleryThumbnailSize(size.toDouble());
              } catch (_) {}
            },
          ),
        ),
        // Shuffle toggle
        IconButton(
          icon: const Icon(Icons.shuffle),
          color: _isShuffled ? Theme.of(context).colorScheme.primary : null,
          tooltip: _isShuffled ? 'Unshuffle' : 'Shuffle',
          onPressed: _toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showAddFilesMenu,
          tooltip: 'Add images',
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                _editAlbum();
                break;
              case 'select':
                setState(() {
                  _isSelectionMode = true;
                });
                break;
              case 'shuffle':
                _toggleShuffle();
                break;
              case 'clear_search':
                setState(() {
                  _searchQuery = null;
                  _applyFiltersAndOrder();
                });
                break;
              case 'manage_rules':
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AutoRulesScreen(
                      scopedAlbumId: widget.album.id,
                      scopedAlbumName: widget.album.name,
                    ),
                  ),
                );
                if (mounted && _isSmartAlbum) {
                  await _loadCachedSmartImages();
                  _scanSmartAlbumImages();
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Album'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.checklist),
                  SizedBox(width: 8),
                  Text('Select Images'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'shuffle',
              child: Row(
                children: [
                  Icon(Icons.shuffle),
                  SizedBox(width: 8),
                  Text('Shuffle'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_search',
              child: Row(
                children: [
                  Icon(Icons.clear),
                  SizedBox(width: 8),
                  Text('Clear Search'),
                ],
              ),
            ),
            if (_isSmartAlbum)
              const PopupMenuItem(
                value: 'manage_rules',
                child: Row(
                  children: [
                    Icon(Icons.rule),
                    SizedBox(width: 8),
                    Text('Manage Rules'),
                  ],
                ),
              ),
          ],
        ),
      ],
      body: Column(
        children: [
          if (_isSmartAlbum)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Smart Album (dynamic by rules)'),
                        const SizedBox(height: 2),
                        Text(
                          _smartStatusText(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showManageSourcesDialog,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Sources'),
                  ),
                  if (_isBackgroundProcessing)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _cancelSmartScan = true;
                          _isBackgroundProcessing = false;
                          _progressStatus = 'Canceled';
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      if (!_isBackgroundProcessing) {
                        setState(() {
                          _isLoading = true;
                        });
                        _scanSmartAlbumImages();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rescan'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AutoRulesScreen(
                              scopedAlbumId: widget.album.id,
                              scopedAlbumName: widget.album.name),
                        ),
                      );
                      if (mounted && _isSmartAlbum) {
                        await _loadCachedSmartImages();
                        _scanSmartAlbumImages();
                        await _refreshSmartStatus();
                      }
                    },
                    icon: const Icon(Icons.rule),
                    label: const Text('Rules'),
                  ),
                ],
              ),
            ),
          if (_searchQuery != null && _searchQuery!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Search: "$_searchQuery"'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _searchQuery = null;
                          _applyFiltersAndOrder();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_isBackgroundProcessing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progressStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  AppProgressIndicator(
                    value: (_totalProgress > 0)
                        ? _currentProgress / _totalProgress
                        : null,
                    backgroundColor: Colors.grey[300],
                  ),
                ],
              ),
            ),
          if (_isLoading && !_isBackgroundProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: AppProgressIndicatorBeautiful(),
            ),
          Expanded(
            child: (_imageFiles.isEmpty && !_isLoading)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery == null || _searchQuery!.isEmpty
                              ? 'No images in this album'
                              : 'No images match your search',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add images to start building your album',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddFilesMenu,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Add Images'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _thumbnailSize.round(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      final file = _imageFiles[index];
                      final filePath = file.path;
                      final isSelected = _selectedFilePaths.contains(filePath);

                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (_selectedFilePaths.contains(filePath)) {
                                _selectedFilePaths.remove(filePath);
                              } else {
                                _selectedFilePaths.add(filePath);
                              }
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  file: file,
                                  imageFiles: _imageFiles,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedFilePaths.add(filePath);
                            });
                          }
                        },
                        child: Hero(
                          tag: filePath,
                          child: Container(
                            decoration: BoxDecoration(
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 3,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(isSelected ? 9 : 12),
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                                cacheWidth: (_thumbnailSize * 100).round(),
                                frameBuilder: (BuildContext context,
                                    Widget child,
                                    int? frame,
                                    bool wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: frame != null
                                        ? child
                                        : SkeletonHelper.box(
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFilesMenu,
        tooltip: 'Add images',
        child: const Icon(Icons.add),
      ),
    );
  }
}
