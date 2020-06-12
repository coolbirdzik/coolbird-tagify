import 'package:cb_file_manager/ui/home/storage_list/storage_list.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/template.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocalHome extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _LocalHome();
  }
}

class _LocalHome extends State<LocalHome> {
  @override
  Widget build(BuildContext context) {
    return CBTemplate({
      'appBarTitle': 'Local file manager',
      'body': Container(
          child: BlocProvider<StorageListBloc>(
            create: (context) => StorageListBloc(),
            child: StorageListWidget(),
          )
      )
    });
  }
}