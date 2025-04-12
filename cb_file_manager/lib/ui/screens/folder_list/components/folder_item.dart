import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';
import 'package:flutter/material.dart';

class FolderItem extends StatelessWidget {
  final Directory folder;

  const FolderItem({
    Key? key,
    required this.folder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber),
        title: Text(folder.basename()),
        subtitle: FutureBuilder<FileStat>(
          future: folder.stat(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(
                '${snapshot.data!.modified.toString().split('.')[0]}',
              );
            }
            return const Text('Loading...');
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderListScreen(path: folder.path),
            ),
          );
        },
      ),
    );
  }
}
