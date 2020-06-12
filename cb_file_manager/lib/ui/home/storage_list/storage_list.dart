
import 'dart:io';

import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StorageListWidget extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final StorageListBloc listBloc = BlocProvider.of<StorageListBloc>(context);

    return FutureBuilder<List<FileSystemEntity>>(
        future: getStorageList(),
        builder: (BuildContext context, AsyncSnapshot<List<FileSystemEntity>> snapshot) {
          switch(snapshot.connectionState) {
            case ConnectionState.none:
              return Text('None');
            case ConnectionState.active:
            case ConnectionState.waiting:
              return Center(
                  child: CircularProgressIndicator(
                  value: 10,
                ));
            case ConnectionState.done:
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              return ListView.builder(
                addAutomaticKeepAlives: true,
                itemCount: snapshot.data.length,
                itemBuilder: (context, int position) {
                  return Card(
                    child: ListTile(
                      title: Text(snapshot.data[position].absolute.path),
                      subtitle: Row(children: [
                        Text("Size: ${snapshot.data[position].statSync().size}")
                      ]),
                      dense: true,
                      onTap: () {
//                        coreNotifier.currentPath =
//                            Directory(snapshot.data[position].absolute.path);
//                        Navigator.push(
//                            context,
//                            MaterialPageRoute(
//                                builder: (context) => FolderListScreen(
//                                    path: snapshot
//                                        .data[position].absolute.path)));
                      },
                    ),
                  );
                },
              );
          }
          return null;
        }
    );
  }

}