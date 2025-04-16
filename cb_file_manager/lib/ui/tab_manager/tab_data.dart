import 'package:flutter/material.dart';

/// A class that represents tab data in the file manager
class TabData {
  /// The unique identifier for this tab
  final String id;

  /// The display name of the tab (usually the folder name)
  final String name;

  /// The current path being displayed in the tab
  final String path;

  /// Icon to display in the tab
  final IconData? icon;

  /// Whether the tab is pinned
  final bool isPinned;

  /// Navigation history for this tab
  final List<String> navigationHistory;

  /// Forward navigation history for this tab
  final List<String> forwardHistory;

  /// Navigator key for this tab to maintain separate navigation state
  final GlobalKey<NavigatorState> navigatorKey;

  TabData({
    required this.id,
    required this.name,
    required this.path,
    this.icon,
    this.isPinned = false,
    List<String>? navigationHistory,
    List<String>? forwardHistory,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : navigationHistory = navigationHistory ?? [path],
        forwardHistory = forwardHistory ?? <String>[],
        navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  /// Create a copy of this tab with some properties changed
  TabData copyWith({
    String? name,
    String? path,
    IconData? icon,
    bool? isPinned,
    List<String>? navigationHistory,
    List<String>? forwardHistory,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return TabData(
      id: this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      icon: icon ?? this.icon,
      isPinned: isPinned ?? this.isPinned,
      navigationHistory: navigationHistory ?? this.navigationHistory,
      forwardHistory: forwardHistory ?? this.forwardHistory,
      navigatorKey: navigatorKey ?? this.navigatorKey,
    );
  }

  /// Update the path of this tab
  void updatePath(String newPath) {
    if (newPath != path) {
      // Check if we're navigating to a path we've already been to
      final existingIndex = navigationHistory.indexOf(newPath);
      if (existingIndex != -1 &&
          existingIndex != navigationHistory.length - 1) {
        // If we're going back to a previous path, add current path to forwardHistory
        forwardHistory.add(path);

        // Remove all paths after the one we're navigating to from backward history
        navigationHistory.removeRange(
            existingIndex + 1, navigationHistory.length);
      } else {
        // Otherwise add the new path to history
        navigationHistory.add(newPath);

        // Clear forward history since we're navigating to a new path
        forwardHistory.clear();

        // Trim history if it gets too long (optional)
        if (navigationHistory.length > 30) {
          navigationHistory.removeAt(0);
        }
      }
    }
  }

  /// Check if navigation back is possible
  bool canNavigateBack() {
    return navigationHistory.length > 1;
  }

  /// Get the previous path in the navigation history
  String? getPreviousPath() {
    if (navigationHistory.length > 1) {
      return navigationHistory[navigationHistory.length - 2];
    }
    return null;
  }

  /// Navigate back in the navigation history
  /// Returns the previous path if successful, null otherwise
  String? navigateBack() {
    if (canNavigateBack()) {
      // Add current path to forward history before going back
      forwardHistory.add(path);

      // Remove current path
      navigationHistory.removeLast();

      // Return the new current path (which was the previous one)
      return navigationHistory.last;
    }
    return null;
  }

  /// Check if navigation forward is possible
  bool canNavigateForward() {
    return forwardHistory.isNotEmpty;
  }

  /// Get the next path in the forward navigation history
  String? getNextPath() {
    if (forwardHistory.isNotEmpty) {
      return forwardHistory.last;
    }
    return null;
  }

  /// Navigate forward in the navigation history
  /// Returns the next path if successful, null otherwise
  String? navigateForward() {
    if (canNavigateForward()) {
      // Get the next path
      final nextPath = forwardHistory.last;

      // Remove it from forward history
      forwardHistory.removeLast();

      // Add it to navigation history
      navigationHistory.add(nextPath);

      return nextPath;
    }
    return null;
  }
}
