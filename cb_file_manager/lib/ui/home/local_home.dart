import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/template.dart';

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
          child: Text('Local Home')
      )
    });
  }
}