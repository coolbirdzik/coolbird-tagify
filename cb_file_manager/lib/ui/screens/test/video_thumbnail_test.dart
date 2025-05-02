import 'dart:io';
import 'dart:typed_data'; // Added import for Uint8List
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// Ensure the helper is correctly imported
import '../../../helpers/video_thumbnail_helper.dart';

/// A test screen to verify video thumbnails are working
class VideoThumbnailTestScreen extends StatefulWidget {
  const VideoThumbnailTestScreen({Key? key}) : super(key: key);

  @override
  State<VideoThumbnailTestScreen> createState() =>
      _VideoThumbnailTestScreenState();
}

class _VideoThumbnailTestScreenState extends State<VideoThumbnailTestScreen> {
  String? _selectedVideoPath;
  Uint8List? _thumbnailBytes;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _pickVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _thumbnailBytes = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        _selectedVideoPath = result.files.first.path;
        setState(() {}); // Update UI to show selected path immediately

        // Generate thumbnail
        // The following line causes the error according to the message.
        // Ensure VideoThumbnailHelper in the imported file actually has this static method.
        _thumbnailBytes = await VideoThumbnailHelper.generateThumbnailData(
            _selectedVideoPath!);

        if (_thumbnailBytes == null) {
          _errorMessage =
              'Could not generate thumbnail for $_selectedVideoPath';
        }
      } else {
        _errorMessage = 'No video selected';
      }
    } catch (e, stackTrace) {
      // Add stack trace for better debugging
      _errorMessage = 'Error picking/processing video: $e\n$stackTrace';
      debugPrint(
          'Error picking/processing video: $e\n$stackTrace'); // Log error
    } finally {
      // Ensure state is updated correctly even if mounted status changes during async operation
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Thumbnail Test'),
        actions: [
          // Add a button to clear cache for testing
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Thumbnail Cache',
            onPressed: () async {
              await VideoThumbnailHelper.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thumbnail cache cleared')),
              );
              // Reset state
              setState(() {
                _selectedVideoPath = null;
                _thumbnailBytes = null;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          // Added for small screens
          padding: const EdgeInsets.all(16.0), // Added padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _pickVideo, // Disable button while loading
                child: const Text('Select Video File'),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              if (_selectedVideoPath != null &&
                  !_isLoading) // Show path only when not loading
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Selected: $_selectedVideoPath',
                      textAlign: TextAlign.center), // Added center align
                ),
              if (_errorMessage != null &&
                  !_isLoading) // Show error only when not loading
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center, // Added center align
                  ),
                ),
              if (_thumbnailBytes != null &&
                  !_isLoading) // Show thumbnail only when not loading
                Column(
                  children: [
                    const Text('Thumbnail Generated Successfully:'),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(
                        // Added constraints for large thumbnails
                        maxWidth: 300,
                        maxHeight: 200,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Image.memory(
                        _thumbnailBytes!,
                        fit: BoxFit.contain, // Use contain to see aspect ratio
                        errorBuilder: (context, error, stackTrace) {
                          // Handle potential errors decoding the image bytes
                          return const Center(
                            child: Text(
                              'Error displaying thumbnail image',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
