import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_tab.dart';
import 'package:cb_file_manager/ui/tab_manager/tabbed_folder_list_screen.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';

/// A router that handles system screens and special paths
class SystemScreenRouter {
  // Static map to cache actual widget instances by path+tabId
  static final Map<String, Widget> _cachedWidgets = {};

  // Track if we've already logged for a specific key
  static final Set<String> _loggedKeys = {};

  /// Routes a special path to the appropriate screen
  /// Returns null if the path is not a system path
  static Widget? routeSystemPath(
      BuildContext context, String path, String tabId) {
    // Check if this is a system path by looking for the # prefix
    if (!path.startsWith('#')) {
      return null;
    }

    // Create a cache key from the tab ID and path
    final String cacheKey = '$tabId:$path';

    // Handle different types of system paths
    if (path == '#tags') {
      // Route to the tag management screen - no caching needed for this screen
      return TagManagementTab(tabId: tabId);
    } else if (path.startsWith('#tag:')) {
      // Check if we already have a cached widget for this tab+path
      if (_cachedWidgets.containsKey(cacheKey)) {
        // Only log once to avoid spamming
        if (!_loggedKeys.contains(cacheKey)) {
          debugPrint(
              'Using cached tag search widget for path: $path in tab: $tabId');
          _loggedKeys.add(cacheKey);
        }
        return _cachedWidgets[cacheKey]!;
      }

      // This is a tag search, extract the tag name
      final tag = path.substring(5); // Remove "#tag:" prefix

      // Create the widget
      Widget tagSearchWidget = Builder(builder: (context) {
        // Update the tab name to show the tag being searched
        final tabBloc = BlocProvider.of<TabManagerBloc>(context);
        tabBloc.add(UpdateTabName(tabId, 'Tag: $tag'));

        // Clear TagManager cache once (not on every rebuild)
        TagManager.clearCache();

        // Log once for initialization
        debugPrint(
            'SystemScreenRouter: Initializing global tag search for: "$tag"');

        // Create a unique bloc for this search
        return BlocProvider(
          // Use create with lazy=false to ensure the bloc is created only once
          create: (_) => FolderListBloc()..add(SearchByTagGlobally(tag)),
          lazy: false,
          child: TabbedFolderListScreen(
            key: ValueKey('tag_search_$cacheKey'), // Add a stable key
            path: '', // Empty path for global search
            tabId: tabId,
            searchTag: tag, // Pass the tag name
            globalTagSearch: true, // Enable global search
          ),
        );
      });

      // Cache the widget to prevent rebuilding
      _cachedWidgets[cacheKey] = tagSearchWidget;

      return tagSearchWidget;
    }

    // Fallback for unknown system paths
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Unknown system path: $path',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  /// Checks if a path is a system path
  static bool isSystemPath(String path) {
    return path.startsWith('#');
  }

  /// Clears the widget cache and logs when a specific tab should be rebuilt
  /// Call this when you need to force refresh a tab
  static void clearWidgetCache([String? specificTabId]) {
    if (specificTabId != null) {
      // Remove only entries for this tab
      _cachedWidgets.removeWhere((key, _) => key.startsWith('$specificTabId:'));
      _loggedKeys.removeWhere((key) => key.startsWith('$specificTabId:'));
      debugPrint('Cleared widget cache for tab: $specificTabId');
    } else {
      _cachedWidgets.clear();
      _loggedKeys.clear();
      debugPrint('Cleared all widget caches');
    }
  }
}
