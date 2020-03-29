import 'package:flutter/material.dart';
import 'ui/home.dart';
import 'ui/main_ui.dart';

void main() => runApp(CBFileApp());

class CBFileApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoolBird - File manager',
      initialRoute: '/',
      routes: {
        '/local/home': (context) => LocalHome()
      },
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'CoolBird - File Manager')
    );
  }
}
