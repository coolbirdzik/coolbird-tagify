import 'dart:io';

import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;

class TagManagementScreen extends StatefulWidget {
  final String startingDirectory;

  const TagManagementScreen({Key? key, required this.startingDirectory})
      : super(key: key);

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  // Initialize with empty set to prevent LateInitializationError
  late Future<Set<String>> _tagsFuture = Future.value({});
  String? _selectedTag;
  // Initialize with empty list to prevent LateInitializationError
  late Future<List<FileSystemEntity>> _filesByTagFuture = Future.value([]);
  bool _isSearching = false;
  bool _isGlobalSearch = true; // Default to global search

  // Database manager for ObjectBox storage
  late DatabaseManager _databaseManager;
  // User preferences singleton instance
  final UserPreferences _preferences = UserPreferences.instance;

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // Initialize database and preferences
    _initializeDatabase();
  }

  @override
  void dispose() {
    // No need to dispose the database manager as it's a singleton
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      // Initialize user preferences
      if (!_preferences.isInitialized()) {
        await _preferences.init();
      }

      // Ensure ObjectBox is enabled
      if (!_preferences.isUsingObjectBox()) {
        await _preferences.setUsingObjectBox(true);
      }

      // Get the database manager instance
      _databaseManager = DatabaseManager.getInstance();

      // Only initialize if not already initialized
      if (!_databaseManager.isInitialized()) {
        await _databaseManager.initialize();
      }

      // Initialize tags list with an empty set to avoid LateInitializationError
      _refreshTags();

      setState(() {
        _isInitializing = false;
      });

      print('Tag management screen: Database initialized successfully');
    } catch (e) {
      print('Error initializing database in tag management screen: $e');
      // Set default empty data in case of error
      setState(() {
        _tagsFuture = Future.value({});
        _filesByTagFuture = Future.value([]);
        _isInitializing = false;
      });
    }
  }

  void _refreshTags() {
    setState(() {
      // Only try to get tags if database is initialized
      if (_databaseManager.isInitialized()) {
        _tagsFuture = _databaseManager.getAllUniqueTags();
      } else {
        _tagsFuture = Future.value({});
      }
    });
  }

  void _selectTag(String tag) {
    setState(() {
      _selectedTag = tag;
      _isSearching = true;
      // Use database manager to find files
      if (_isGlobalSearch) {
        _filesByTagFuture = _findFilesByTagGlobally(tag);
      } else {
        _filesByTagFuture =
            _findFilesByTagInDirectory(widget.startingDirectory, tag);
      }
    });
  }

  // Find files with a specific tag in a directory
  Future<List<FileSystemEntity>> _findFilesByTagInDirectory(
      String directoryPath, String tag) async {
    final List<FileSystemEntity> results = [];
    final filePaths =
        await _databaseManager.findFilesByTag(tag.toLowerCase().trim());

    // Filter paths by directory
    final filteredPaths =
        filePaths.where((path) => path.startsWith(directoryPath)).toList();

    // Convert paths to FileSystemEntity objects
    for (final path in filteredPaths) {
      try {
        final directory = Directory(path);
        if (await directory.exists()) {
          results.add(directory);
        } else {
          final file = File(path);
          if (await file.exists()) {
            results.add(file);
          }
        }
      } catch (e) {
        print('Error converting path to FileSystemEntity: $e');
      }
    }

    return results;
  }

  // Find files with a specific tag globally
  Future<List<FileSystemEntity>> _findFilesByTagGlobally(String tag) async {
    final List<FileSystemEntity> results = [];
    final filePaths =
        await _databaseManager.findFilesByTag(tag.toLowerCase().trim());

    // Convert paths to FileSystemEntity objects
    for (final path in filePaths) {
      try {
        final directory = Directory(path);
        if (await directory.exists()) {
          results.add(directory);
        } else {
          final file = File(path);
          if (await file.exists()) {
            results.add(file);
          }
        }
      } catch (e) {
        print('Error converting path to FileSystemEntity: $e');
      }
    }

    return results;
  }

  void _clearTagSelection() {
    setState(() {
      _selectedTag = null;
      _isSearching = false;
      _filesByTagFuture = Future.value([]);
    });
  }

  Future<void> _showDeleteTagConfirmation(
      BuildContext context, String tag) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Tag Globally?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Are you sure you want to delete the tag "$tag" from all files?'),
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone and will remove this tag from all files.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete Tag'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        await _deleteTagGlobally(tag);
      }
    });
  }

  Future<void> _deleteTagGlobally(String tag) async {
    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Deleting tag from all files...'),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      // Use database manager to find files with this tag
      final filePaths =
          await _databaseManager.findFilesByTag(tag.toLowerCase().trim());
      int totalFiles = filePaths.length;
      int processedFiles = 0;

      // Remove tag from each file
      for (final path in filePaths) {
        final success = await _databaseManager.removeTagFromFile(path, tag);
        if (success) {
          processedFiles++;
        }
      }

      // Clear the selected tag if it was deleted
      if (_selectedTag == tag) {
        _clearTagSelection();
      }

      // Refresh the tags list
      _refreshTags();

      // Show success message
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Tag "$tag" deleted from $processedFiles files'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    showAboutDialog(
      context: context,
      applicationName: 'CoolBird File Manager',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.info_outline),
      children: [
        const Text(
            'CoolBird File Manager helps you manage your files and tags efficiently.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: _selectedTag != null ? 'Files with tag: $_selectedTag' : 'Tags',
      actions: [
        if (_selectedTag != null)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteTagConfirmation(context, _selectedTag!),
            tooltip: 'Delete this tag from all files',
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshTags,
          tooltip: 'Refresh tags',
        ),
      ],
      body: Column(
        children: [
          // Global search toggle
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SwitchListTile(
              title: const Text('Global Search'),
              subtitle: const Text('Search for tags across all directories'),
              value: _isGlobalSearch,
              onChanged: (value) {
                setState(() {
                  _isGlobalSearch = value;
                  // If a tag is already selected, update the search results
                  if (_selectedTag != null) {
                    if (_isGlobalSearch) {
                      _filesByTagFuture =
                          _findFilesByTagGlobally(_selectedTag!);
                    } else {
                      _filesByTagFuture = _findFilesByTagInDirectory(
                          widget.startingDirectory, _selectedTag!);
                    }
                  }
                });
              },
            ),
          ),
          // Content area
          Expanded(
            child: _selectedTag == null
                ? _buildTagsList()
                : _buildFilesByTagList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsList() {
    return FutureBuilder<Set<String>>(
      future: _tagsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading tags: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final tags = snapshot.data ?? {};

        if (tags.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.label_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No tags found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Add tags to files to see them here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'All Tags',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: tags.map<Widget>((tag) {
                return InputChip(
                  label: Text(tag),
                  labelStyle: const TextStyle(fontSize: 16),
                  avatar: const Icon(Icons.label, size: 18),
                  onPressed: () => _selectTag(tag),
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  deleteIcon: const Icon(Icons.delete_outline, size: 18),
                  onDeleted: () => _showDeleteTagConfirmation(context, tag),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilesByTagList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to all tags'),
                onPressed: _clearTagSelection,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FileSystemEntity>>(
            future: _filesByTagFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching for files...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error finding files: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final files = snapshot.data ?? [];

              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No files found with tag "$_selectedTag"',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  if (file is File) {
                    return _buildFileItem(context, file);
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(BuildContext context, File file) {
    final String extension = file.path.split('.').last.toLowerCase();
    IconData icon;
    Color? iconColor;

    // Determine file type and icon
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension)) {
      icon = Icons.videocam;
      iconColor = Colors.red;
    } else if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']
        .contains(extension)) {
      icon = Icons.audiotrack;
      iconColor = Colors.purple;
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
        .contains(extension)) {
      icon = Icons.description;
      iconColor = Colors.indigo;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(pathlib.basename(file.path)),
        subtitle: Text(file.path),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove this tag from the file',
          onPressed: () async {
            // Remove the tag from this file
            final success = await _databaseManager.removeTagFromFile(
                file.path, _selectedTag!);

            if (success) {
              // Refresh the file list
              setState(() {
                _filesByTagFuture = _findFilesByTagInDirectory(
                    widget.startingDirectory, _selectedTag!);
              });
            } else {
              // Show error
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error removing tag from file'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FileDetailsScreen(file: file),
            ),
          );
        },
      ),
    );
  }
}
