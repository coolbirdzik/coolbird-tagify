import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/album_service.dart';
import '../models/objectbox/album_config.dart';
import '../widgets/lazy_album_grid.dart';

class LazyAlbumDemoPage extends StatefulWidget {
  const LazyAlbumDemoPage({Key? key}) : super(key: key);

  @override
  State<LazyAlbumDemoPage> createState() => _LazyAlbumDemoPageState();
}

class _LazyAlbumDemoPageState extends State<LazyAlbumDemoPage> {
  final AlbumService _albumService = AlbumService.instance;
  int? _currentAlbumId;
  String _albumName = '';

  @override
  void initState() {
    super.initState();
    _albumService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lazy Loading Album Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _currentAlbumId == null ? _buildSetupView() : _buildAlbumView(),
    );
  }

  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lazy Loading Album System',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('• Hiển thị ảnh ngay lập tức (không chờ scan hết)'),
                  Text('• Load dần dần 20 ảnh mỗi lần'),
                  Text('• Progress indicator realtime'),
                  Text('• Background processing không block UI'),
                  Text('• Cache thông minh'),
                  Text('• Auto refresh khi có file mới'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          TextField(
            decoration: const InputDecoration(
              labelText: 'Album Name',
              border: OutlineInputBorder(),
              hintText: 'Enter album name...',
            ),
            onChanged: (value) => _albumName = value,
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createAlbum,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Create Album & Select Directories'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Card(
            color: Colors.orange,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'How it works:',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Chọn thư mục chứa nhiều ảnh/video\n'
                    '2. Album sẽ hiển thị ngay lập tức\n'
                    '3. Files load dần dần trong background\n'
                    '4. Không cần chờ scan hết mới thấy ảnh',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumView() {
    return LazyAlbumGrid(
      albumId: _currentAlbumId!,
      albumName: _albumName,
    );
  }

  void _createAlbum() async {
    if (_albumName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter album name')),
      );
      return;
    }

    try {
      // Pick directories
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory == null) {
        return; // User cancelled
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating album...'),
            ],
          ),
        ),
      );

      // Create album with optimized config
      final album = await _albumService.createAlbum(
        name: _albumName.trim(),
        description: 'Demo album with lazy loading',
        directories: [selectedDirectory],
        config: AlbumConfig(
          albumId: 0, // Will be set by service
          includeSubdirectories: true,
          autoRefresh: true,
          maxFileCount: 5000, // Allow many files
          sortBy: 'date',
          sortAscending: false,
        ),
      );

      if (album == null) {
        throw Exception('Failed to create album');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to album view
      setState(() {
        _currentAlbumId = album.id;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Album "${album.name}" created! Files will load progressively.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating album: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _albumService.dispose();
    super.dispose();
  }
}
