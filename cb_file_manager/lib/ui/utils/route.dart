
import 'package:flutter/cupertino.dart';

class RouteUtils {
  static void toNewScreen(BuildContext context, Object screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
        new PageRouteBuilder(
            pageBuilder: (BuildContext context, _, __) {
              return screen;
            },
            transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
              return new FadeTransition(
                  opacity: animation,
                  child: child
              );
            }
        )
    );
  }
}