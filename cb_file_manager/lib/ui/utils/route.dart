import 'package:flutter/material.dart';
import 'package:cb_file_manager/main.dart' show goHome;

class RouteUtils {
  // Remove redundant methods and keep only the most robust navigation method

  // Add a safe navigation method that ensures we never get an empty stack
  static void safeNavigate(BuildContext context, Widget screen) {
    try {
      // First check if we can navigate at all
      if (!context.mounted) {
        return;
      }

      // Create a fresh route
      final route = MaterialPageRoute(builder: (_) => screen);

      // If we can pop, replace this route, otherwise push a new one
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).push(route);
      }
    } catch (e) {
      // Last resort fallback
      if (context.mounted) {
        goHome(context);
      }
    }
  }
}
