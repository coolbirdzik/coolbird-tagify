import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:flutter/material.dart';

class FolderItem extends StatelessWidget {
  final Directory folder;
  final Function(String)? onTap;

  const FolderItem({
    Key? key,
    required this.folder,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
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
          if (onTap != null) {
            onTap!(folder.path);
          }
        },
      ),
    );
  }
}
