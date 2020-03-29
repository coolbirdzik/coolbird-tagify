import 'package:flutter/material.dart';
import 'drawer.dart';

class CBTemplate extends StatefulWidget {
  final Map<String, Object> config;

  CBTemplate(this.config, {Key key}): super(key: key);

  @override
  State<StatefulWidget> createState() => _CBTemplateState();
}

class _CBTemplateState extends State<CBTemplate> {

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.config['appBarTitle'] ?? ''),
        ),
        body: widget.config['body'],
        drawer: new CBDrawer(context)
    );
  }
}
