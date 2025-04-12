import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';

class SearchDialog extends StatefulWidget {
  final String currentPath;
  final List<File> files;
  final List<Directory> folders;

  const SearchDialog({
    Key? key,
    required this.currentPath,
    required this.files,
    required this.folders,
  }) : super(key: key);

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<File> _filteredFiles = [];
  List<Directory> _filteredFolders = [];

  @override
  void initState() {
    super.initState();
    _filteredFiles = widget.files;
    _filteredFolders = widget.folders;

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = widget.files;
        _filteredFolders = widget.folders;
      } else {
        _filteredFiles = widget.files
            .where((file) => file.path.toLowerCase().contains(query))
            .toList();
        _filteredFolders = widget.folders
            .where((folder) => folder.path.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search files and folders',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Search results in: ${widget.currentPath}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredFiles.isEmpty && _filteredFolders.isEmpty) {
      return const Center(
        child: Text('No results found'),
      );
    }

    return ListView(
      children: [
        if (_filteredFolders.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Folders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ..._filteredFolders.map(_buildFolderItem).toList(),
        ],
        if (_filteredFiles.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Files',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ..._filteredFiles.map(_buildFileItem).toList(),
        ],
      ],
    );
  }

  Widget _buildFolderItem(Directory folder) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber),
      title: Text(folder.basename()),
      onTap: () {
        Navigator.pop(context); // Close search dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderListScreen(path: folder.path),
          ),
        );
      },
    );
  }

  Widget _buildFileItem(File file) {
    final extension = file.path.split('.').last.toLowerCase();
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

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(file.path.split('/').last),
      subtitle: Text(file.path.replaceFirst(widget.currentPath, '')),
      onTap: () {
        Navigator.pop(context); // Close search dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FileDetailsScreen(file: file),
          ),
        );
      },
    );
  }
}
