import 'package:flutter/material.dart';
import './main_ui.dart';
import './utils/route.dart';
import './home.dart';

class CBDrawer extends StatelessWidget {
  CBDrawer(BuildContext context);

  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          height: 90,
          child: DrawerHeader(
            child: Text('CoolBird File Manager'),
            decoration: BoxDecoration(
              color: Colors.green,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.home),
          title: Text('Homepage'),
          onTap: () {
            RouteUtils.toNewScreen(context, new MyHomePage());
          },
        ),
        ExpansionTile(
          title: Row(children: <Widget>[
            Container(
              margin: EdgeInsets.only(right: 20),
              child: Icon(Icons.phone_android),
            ),
            Text('Local')
          ]),
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.only(left: 30),
              leading: Icon(Icons.home),
              title: Text('Homepage'),
              onTap: () {
                RouteUtils.toNewScreen(context, new LocalHome());
              },
            )
          ],
        ),
        ListTile(
          leading: Icon(Icons.network_wifi),
          title: Text('Networks'),
          onTap: () {
            // Update the state of the app.
            // ...
          },
        ),
      ],
    ));
  }
}
