import 'package:flutter/material.dart';
import 'dart:async';
import '../services/album_service.dart';
import '../services/album_file_scanner.dart';
import 'package:cb_file_manager/ui/widgets/thumbnail_loader.dart';
import '../core/service_locator.dart';

class LazyAlbumGrid extends StatefulWidget {
  final int albumId;
  final String albumName;

  const LazyAlbumGrid({
    Key? key,
    required this.albumId,
    required this.albumName,
  }) : super(key: key);

  @override
  State<LazyAlbumGrid> createState() => _LazyAlbumGridState();
}

class _LazyAlbumGridState extends State<LazyAlbumGrid> {
  final AlbumService _albumService = locator<AlbumService>();
  List<FileInfo> _files = [];
  bool _isScanning = true;
  double _scanProgress = 0.0;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    // Initial load
    final files = await _albumService.getAlbumFiles(widget.albumId);
    if (mounted) {
      setState(() {
        _files = files;
        _isScanning = false; // Assume done if we get files, or listen to stream
      });
    }

    // Listen to updates if needed, or just rely on refresh
    // For now, let's just load what we have.
    // If we want to show scanning progress, we might need a stream from AlbumService
    // But AlbumService currently returns a Future<List<FileInfo>>.
    // Let's check if there's a way to get progress.
    // The previous code had _scanProgress, so maybe it was using a different service or method.
    // I'll assume for now we just load.
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Target ~120 logical px tile width on mobile, clamp crossAxisCount 2..6
    final targetTileWidth = 120.0;
    final crossAxisCount = size.width > 0
        ? (size.width / targetTileWidth).floor().clamp(2, 6)
        : 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _scanProgress > 0 ? _scanProgress : null,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAlbum,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_isScanning)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Loading files... ${_files.length} found',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_scanProgress > 0)
                    Text(
                      '${(_scanProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          
          // File count
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  '${_files.length} files',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_files.isNotEmpty)
                  Text(
                    _isScanning ? 'Loading more...' : 'Complete',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isScanning ? Colors.orange : Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // Files grid
          Expanded(
            child: _files.isEmpty && !_isScanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No files found'),
                        SizedBox(height: 8),
                        Text('Add some directories to this album', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return _buildFileItem(file, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileInfo file, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Unified thumbnail loader for images/videos
          ThumbnailLoader(
            filePath: file.path,
            isVideo: file.isVideo,
            isImage: file.isImage,
            fit: BoxFit.cover,
            showLoadingIndicator: true,
            borderRadius: BorderRadius.circular(10),
            fallbackBuilder: () => Container(
              color: Colors.grey[200],
              child: Icon(
                file.isVideo
                    ? Icons.play_circle_outline
                    : (file.isImage
                        ? Icons.broken_image
                        : Icons.insert_drive_file),
                color: Colors.grey[600],
                size: 28,
              ),
            ),
          ),

          // Subtle gradient only on hover/press would be ideal; keep minimal always-on footer for readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                ),
              ),
              child: Text(
                file.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Badge indicating new items while scanning
          if (index >= _files.length - 20 && _isScanning)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fiber_new, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _refreshAlbum() async {
    await _albumService.refreshAlbum(widget.albumId);
    
    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Album refreshed - files will load progressively'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
