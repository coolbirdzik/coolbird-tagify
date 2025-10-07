import 'package:flutter/material.dart';
import 'dart:async';
import '../services/optimized_album_service.dart';
import '../services/album_file_scanner.dart';

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
  final OptimizedAlbumService _albumService = OptimizedAlbumService.instance;
  StreamSubscription<List<FileInfo>>? _filesSubscription;
  List<FileInfo> _files = [];
  bool _isScanning = false;
  double _scanProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    // Get immediate files first (cached)
    final immediateFiles = _albumService.getImmediateFiles(widget.albumId);
    if (immediateFiles.isNotEmpty) {
      setState(() {
        _files = immediateFiles;
      });
    }

    // Start lazy loading stream
    _filesSubscription = _albumService.getLazyAlbumFiles(widget.albumId).listen(
      (files) {
        setState(() {
          _files = files;
          _isScanning = _albumService.isAlbumScanning(widget.albumId);
          _scanProgress = _albumService.getAlbumScanProgress(widget.albumId);
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _filesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 1,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // File thumbnail/icon
          if (file.isImage)
            Image.network(
              'file://${file.path}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          else if (file.isVideo)
            Container(
              color: Colors.black87,
              child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
            )
          else
            Container(
              color: Colors.grey[200],
              child: const Icon(Icons.insert_drive_file, color: Colors.grey),
            ),

          // File info overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              child: Text(
                file.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Loading indicator for new items
          if (index >= _files.length - 20 && _isScanning)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
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
