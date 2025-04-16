import 'dart:io';

import 'package:cb_file_manager/helpers/io_extensions.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';
import 'package:flutter/material.dart';

class FolderGridItem extends StatelessWidget {
  final Directory folder;
  final Function(String)? onTap;

  const FolderGridItem({
    Key? key,
    required this.folder,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!(folder.path);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize
              .min, // Ensure the column only takes the minimum vertical space needed
          children: [
            // Icon section
            Expanded(
              flex: 3,
              child: Center(
                child: Icon(
                  Icons.folder,
                  size: 40,
                  color: Colors.amber,
                ),
              ),
            ),
            // Text section - improved to prevent overflow
            Container(
              constraints: BoxConstraints(
                  minHeight: 36,
                  maxHeight: 40), // Increased max height and added min height
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              width: double.infinity,
              child: LayoutBuilder(builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.basename(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Flexible(
                      child: FutureBuilder<FileStat>(
                        future: folder.stat(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              '${snapshot.data!.modified.toString().split('.')[0]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 8),
                            );
                          }
                          return const Text('Loading...',
                              style: TextStyle(fontSize: 8));
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
