import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/ui/screens/tag_management/tag_management_tab.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tabbed_folder_list_screen.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/network_connection_screen.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/network_browser_screen.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/smb_browser_screen.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/ftp_browser_screen.dart';
import 'package:cb_file_manager/ui/screens/network_browsing/webdav_browser_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/media_gallery/video_gallery_screen.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_bloc.dart';
import 'package:cb_file_manager/services/network_browsing/network_service_registry.dart';
import 'package:cb_file_manager/ui/screens/home/home_screen.dart';
import 'package:cb_file_manager/helpers/core/uri_utils.dart';
import 'package:cb_file_manager/ui/screens/album_management/album_management_screen.dart';
import 'package:cb_file_manager/ui/screens/album_management/auto_rules_screen.dart';
import 'package:cb_file_manager/ui/screens/album_management/album_detail_screen.dart';
import 'package:cb_file_manager/services/album_service.dart';
import 'package:cb_file_manager/models/objectbox/album.dart';
import 'package:cb_file_manager/ui/screens/gallery_hub/gallery_hub_screen.dart';
import 'package:cb_file_manager/ui/screens/video_hub/video_hub_screen.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import '../utils/route.dart';
import 'trash_bin/trash_bin_screen.dart';

/// A router that handles system screens and special paths
class SystemScreenRouter {
  // Static map to cache actual widget instances by path+tabId
  static final Map<String, Widget> _cachedWidgets = {};

  // Track if we've already logged for a specific key
  static final Set<String> _loggedKeys = {};

  // Network service registry
  static final NetworkServiceRegistry _networkRegistry =
      NetworkServiceRegistry();

  /// Routes a special path to the appropriate screen
  /// Returns null if the path is not a system path
  static Widget? routeSystemPath(
      BuildContext context, String path, String tabId) {
    // Check if this is a system path by looking for the # prefix
    if (path.startsWith('#')) {
      // Handle different types of system paths
      return _handleSystemPaths(context, path, tabId);
    }

    // Check if this is a network path
    // Network paths start with protocol:// (smb://, ftp://, webdav://)
    if (_isNetworkPath(path)) {
      return _handleNetworkPath(context, path, tabId);
    }

    // Not a special path
    return null;
  }

  /// Handles system paths that start with #
  static Widget? _handleSystemPaths(
      BuildContext context, String path, String tabId) {
    // Create a cache key from the tab ID and path
    final String cacheKey = '$tabId:$path';

    if (path == '#home') {
      // Route to the home screen
      return HomeScreen(tabId: tabId);
    } else if (path == '#tags') {
      // Route to the tag management screen - no caching needed for this screen
      return TagManagementTab(tabId: tabId);
    } else if (path == '#gallery') {
      // Route to the gallery hub screen as a tab
      return const GalleryHubScreen();
    } else if (path == '#video') {
      // Route to the video hub screen as a tab
      return const VideoHubScreen();
    } else if (path == '#albums') {
      // Route to the album management screen as a tab
      return const AlbumManagementScreen();
    } else if (path == '#auto-rules') {
      // Route to the auto rules screen as a tab
      return const AutoRulesScreen();
    } else if (path == '#trash') {
      // Route to the Trash Bin screen as a tab
      return const TrashBinScreen();
    } else if (path.startsWith('#album/')) {
      // Route to album detail screen - extract album ID from path
      final albumIdStr = path.substring('#album/'.length);
      final albumId = int.tryParse(albumIdStr);
      if (albumId != null) {
        return FutureBuilder<Album?>(
          future: AlbumService.instance.getAlbumById(albumId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data != null) {
              return AlbumDetailScreen(album: snapshot.data!);
            }
            return const Center(child: Text('Album not found'));
          },
        );
      }
      return const Center(child: Text('Invalid album ID'));
    } else if (path == '#network') {
      // Route to the network connections screen
      // Use the existing BlocProvider from TabMainScreen to ensure shared state
      return const NetworkConnectionScreen();
    } else if (path == '#smb') {
      // Route to the SMB browser screen
      // Create with its own bloc to ensure we can scan the network
      return BlocProvider<NetworkBrowsingBloc>(
        create: (_) => NetworkBrowsingBloc(),
        child: SMBBrowserScreen(tabId: tabId),
      );
    } else if (path == '#ftp') {
      // Route to the FTP browser screen
      // Use the existing BlocProvider from TabMainScreen instead of creating a new one
      return FTPBrowserScreen(tabId: tabId);
    } else if (path == '#webdav') {
      // Route to the WebDAV browser screen
      return WebDAVBrowserScreen(tabId: tabId);
    } else if (path == '#gallery:images') {
      // Route to the image gallery screen
      return const ImageGalleryScreen(
        path: '',
        recursive: true,
      );
    } else if (path.startsWith('#gallery:videos')) {
      // Route to the video gallery screen, support optional query params
      // e.g. #gallery:videos?path=<encodedPath>&recursive=false
      String galleryPath = '';
      bool recursive = true;
      final int qIndex = path.indexOf('?');
      if (qIndex != -1 && qIndex < path.length - 1) {
        final String query = path.substring(qIndex + 1);
        try {
          final params = Uri.splitQueryString(query);
          if (params.containsKey('path')) {
            galleryPath = Uri.decodeComponent(params['path'] ?? '');
          }
          if (params.containsKey('recursive')) {
            final v = (params['recursive'] ?? '').toLowerCase();
            if (v == 'false' || v == '0' || v == 'no') {
              recursive = false;
            } else if (v == 'true' || v == '1' || v == 'yes') {
              recursive = true;
            }
          }
        } catch (_) {
          // Fallback to defaults if parsing fails
        }
      }

      return VideoGalleryScreen(
        path: galleryPath,
        recursive: recursive,
      );
    } else if (path.startsWith('#tag:')) {
      // Check if we already have a cached widget for this tab+path
      if (_cachedWidgets.containsKey(cacheKey)) {
        // Only log once to avoid spamming
        if (!_loggedKeys.contains(cacheKey)) {
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
        tabBloc.add(UpdateTabName(tabId, '${context.tr.tagPrefix}: $tag'));

        // Clear TagManager cache once (not on every rebuild)
        TagManager.clearCache();

        // Log once for initialization
        _loggedKeys.add(cacheKey);

        // Create a unique bloc for this search with timeout protection
        return BlocProvider(
          // Use create with lazy=false to ensure the bloc is created only once
          create: (_) {
            final bloc = FolderListBloc();
            // Add timeout protection to prevent infinite loops
            Future.delayed(const Duration(milliseconds: 500), () {
              if (bloc.isClosed == false) {
                bloc.add(SearchByTagGlobally(tag));
              }
            });
            return bloc;
          },
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
    } else if (path.startsWith('#search?tag=')) {
      // Support hash-based tag search path: #search?tag=...
      if (_cachedWidgets.containsKey(cacheKey)) {
        if (!_loggedKeys.contains(cacheKey)) {
          _loggedKeys.add(cacheKey);
        }
        return _cachedWidgets[cacheKey]!;
      }

      // Avoid recursion: don't pass a '#' path into TabbedFolderListScreen
      // or it will call SystemScreenRouter again. Instead, parse the tag
      // and drive the screen via searchTag + globalTagSearch.
      final String raw = path.substring('#search?tag='.length);
      final String tag = UriUtils.safeDecodeComponent(raw);

      final widgetToCache = TabbedFolderListScreen(
        key: ValueKey('tag_search_$cacheKey'),
        path: '',
        tabId: tabId,
        searchTag: tag,
        globalTagSearch: true,
      );

      _cachedWidgets[cacheKey] = widgetToCache;
      _loggedKeys.add(cacheKey);
      return widgetToCache;
    }

    // Handle network paths that might follow special format #network/TYPE/HOST/...
    if (path.startsWith('#network/')) {
      _loggedKeys.add(cacheKey);
      return _handleNetworkPath(context, path, tabId);
    }

    // Fallback for unknown system paths
    return _buildErrorWidget(context, '${context.tr.unknownSystemPath}: $path',
        cacheKey: cacheKey);
  }

  /// Handles network paths (smb://, ftp://, etc.)
  static Widget _handleNetworkPath(
      BuildContext context, String path, String tabId) {
    // Create a cache key from the tab ID and path
    final String cacheKey = '$tabId:$path';
    try {
      // Check if we already have a cached widget for this network path
      if (_cachedWidgets.containsKey(cacheKey)) {
        // Only log once to avoid spamming
        if (!_loggedKeys.contains(cacheKey)) {
          _loggedKeys.add(cacheKey);
        }
        return _cachedWidgets[cacheKey]!;
      }

      // Extract display name for tab title
      final String displayName = _getNetworkDisplayName(path);

      // Update tab name to show the current connection
      final tabBloc = BlocProvider.of<TabManagerBloc>(context);
      tabBloc.add(UpdateTabName(tabId, displayName));

      // Kiểm tra loại dịch vụ
      String serviceType = "Unknown";
      if (path.startsWith('#network/')) {
        final parts = path.substring('#network/'.length).split('/');
        if (parts.isNotEmpty) {
          serviceType = parts[0];

          // Add special handling for FTP paths without connection
          if (serviceType.toUpperCase() == "FTP" &&
              !_networkRegistry.isNetworkPath(path)) {
            // Build a helper widget for FTP that shows connection options
            Widget ftpHelper = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    remix.Remix.upload_cloud_2_line,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr.ftpConnectionRequired,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr.ftpConnectionDescription,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Open FTP browser screen in this tab
                      tabBloc.add(UpdateTabPath(tabId, '#ftp'));
                      tabBloc
                          .add(UpdateTabName(tabId, context.tr.ftpConnections));
                    },
                    child: Text(context.tr.goToFtpConnections),
                  ),
                ],
              ),
            );

            // Cache the helper widget
            _cachedWidgets[cacheKey] = ftpHelper;
            return ftpHelper;
          }
        }
      } else if (path.contains('://')) {
        serviceType = path.split('://')[0].toUpperCase();
      }

      // Create a TabbedFolderListScreen with network folder browsing capability
      // This will make it look and behave like a regular folder, but with network paths

      Widget networkBrowserWidget = NetworkBrowserScreen(
        key: ValueKey(cacheKey), // Use cache key as widget key for stability
        path: path,
        tabId: tabId,
        showAppBar: true, // Explicitly set to true
      );

      // Cache the network browser widget
      _cachedWidgets[cacheKey] = networkBrowserWidget;

      return networkBrowserWidget;
    } catch (e) {
      _loggedKeys.add(cacheKey);
      // Fallback for navigation errors
      return _buildErrorWidget(
          context, '${context.tr.cannotOpenNetworkPath}: $path',
          cacheKey: cacheKey);
    }
  }

  /// Get a nice display name for network paths
  static String _getNetworkDisplayName(String path) {
    // Extract a display name from the path
    final parts = path.split('://');
    if (parts.length < 2) {
      return path;
    }

    final protocol = parts[0].toUpperCase();
    final address = parts[1].split('/').first;

    return '$address ($protocol)';
  }

  /// Builds an error widget for unknown paths
  static Widget _buildErrorWidget(BuildContext context, String message,
      {String? cacheKey}) {
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
            message,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Kiểm tra xem Navigator có thể pop() không
              if (Navigator.of(context).canPop()) {
                RouteUtils.safePopDialog(context);
              } else {
                // Nếu không thể pop, hãy thử chuyển về tab mặc định
                try {
                  final tabBloc = BlocProvider.of<TabManagerBloc>(context);
                  // Kiểm tra xem có tab nào không
                  if (tabBloc.state.tabs.isNotEmpty) {
                    // Chuyển đến tab đầu tiên
                    tabBloc.add(SwitchToTab(tabBloc.state.tabs.first.id));
                  }
                } catch (e) {
                  if (cacheKey != null) {
                    _loggedKeys.add(cacheKey);
                  }
                }
              }
            },
            child: Text(context.tr.goBack),
          ),
        ],
      ),
    );
  }

  /// Checks if a path is a system path
  static bool isSystemPath(String path) {
    return path.startsWith('#');
  }

  /// Checks if a path is a network path
  static bool _isNetworkPath(String path) {
    // Basic check for network protocols
    return path.startsWith('smb://') ||
        path.startsWith('ftp://') ||
        path.startsWith('webdav://') ||
        // Also check if this path matches an active connection in the registry
        _networkRegistry.isNetworkPath(path);
  }

  /// Clears the widget cache and logs when a specific tab should be rebuilt
  /// Call this when you need to force refresh a tab
  static void clearWidgetCache([String? specificTabId]) {
    if (specificTabId != null) {
      // Remove only entries for this tab
      _cachedWidgets.removeWhere((key, _) => key.startsWith('$specificTabId:'));
      _loggedKeys.removeWhere((key) => key.startsWith('$specificTabId:'));
    } else {
      _cachedWidgets.clear();
      _loggedKeys.clear();
    }
  }

  /// Refreshes a specific system path or all system paths
  /// Useful when the app needs to refresh tag-related screens
  static void refreshSystemPath(String? path, String? tabId) {
    if (path != null && tabId != null) {
      // Create the cache key
      final String cacheKey = '$tabId:$path';

      // Remove this specific path from cache
      _cachedWidgets.remove(cacheKey);
      _loggedKeys.remove(cacheKey);
    } else if (tabId != null) {
      // Clear all paths for this tab
      clearWidgetCache(tabId);
    } else {
      // Clear all caches
      clearWidgetCache();
    }
  }
}
