import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cb_file_manager/services/album_service.dart';
import 'package:cb_file_manager/models/objectbox/album.dart';

class FeaturedAlbumsService {
  static const String _configFileName = 'featured_albums_config.json';
  static FeaturedAlbumsService? _instance;

  static FeaturedAlbumsService get instance {
    _instance ??= FeaturedAlbumsService._();
    return _instance!;
  }

  FeaturedAlbumsService._();

  /// Get the config file path
  Future<String> _getConfigFilePath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/$_configFileName';
  }

  /// Load featured albums configuration
  Future<FeaturedAlbumsConfig> loadConfig() async {
    try {
      final configPath = await _getConfigFilePath();
      final file = File(configPath);

      if (!await file.exists()) {
        // Return default config if file doesn't exist
        return FeaturedAlbumsConfig.defaultConfig();
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return FeaturedAlbumsConfig.fromJson(json);
    } catch (e) {
      print('Error loading featured albums config: $e');
      return FeaturedAlbumsConfig.defaultConfig();
    }
  }

  /// Save featured albums configuration
  Future<bool> saveConfig(FeaturedAlbumsConfig config) async {
    try {
      final configPath = await _getConfigFilePath();
      final file = File(configPath);

      final json = config.toJson();
      await file.writeAsString(jsonEncode(json));
      return true;
    } catch (e) {
      print('Error saving featured albums config: $e');
      return false;
    }
  }

  /// Get featured albums based on current configuration
  Future<List<Album>> getFeaturedAlbums() async {
    try {
      final config = await loadConfig();
      final allAlbums = await AlbumService.instance.getAllAlbums();

      List<Album> featuredAlbums = [];

      // Add albums by IDs if they exist
      for (final albumId in config.featuredAlbumIds) {
        final album = allAlbums.firstWhere(
          (a) => a.id == albumId,
          orElse: () => Album(name: '', description: ''),
        );
        if (album.name.isNotEmpty) {
          featuredAlbums.add(album);
        }
      }

      // If auto-select is enabled and we have fewer than max albums
      if (config.autoSelectRecent &&
          featuredAlbums.length < config.maxFeaturedAlbums) {
        final recentAlbums = allAlbums
            .where((album) => !config.featuredAlbumIds.contains(album.id))
            .take(config.maxFeaturedAlbums - featuredAlbums.length)
            .toList();
        featuredAlbums.addAll(recentAlbums);
      }

      return featuredAlbums.take(config.maxFeaturedAlbums).toList();
    } catch (e) {
      print('Error getting featured albums: $e');
      return [];
    }
  }

  /// Add an album to featured list
  Future<bool> addToFeatured(int albumId) async {
    try {
      final config = await loadConfig();
      if (!config.featuredAlbumIds.contains(albumId)) {
        config.featuredAlbumIds.add(albumId);
        return await saveConfig(config);
      }
      return true;
    } catch (e) {
      print('Error adding album to featured: $e');
      return false;
    }
  }

  /// Remove an album from featured list
  Future<bool> removeFromFeatured(int albumId) async {
    try {
      final config = await loadConfig();
      config.featuredAlbumIds.remove(albumId);
      return await saveConfig(config);
    } catch (e) {
      print('Error removing album from featured: $e');
      return false;
    }
  }

  /// Toggle featured status of an album
  Future<bool> toggleFeatured(int albumId) async {
    final config = await loadConfig();
    if (config.featuredAlbumIds.contains(albumId)) {
      return await removeFromFeatured(albumId);
    } else {
      return await addToFeatured(albumId);
    }
  }
}

class FeaturedAlbumsConfig {
  List<int> featuredAlbumIds;
  int maxFeaturedAlbums;
  bool autoSelectRecent;
  bool showInGalleryHub;

  FeaturedAlbumsConfig({
    required this.featuredAlbumIds,
    this.maxFeaturedAlbums = 4,
    this.autoSelectRecent = true,
    this.showInGalleryHub = true,
  });

  factory FeaturedAlbumsConfig.defaultConfig() {
    return FeaturedAlbumsConfig(
      featuredAlbumIds: [],
      maxFeaturedAlbums: 4,
      autoSelectRecent: true,
      showInGalleryHub: true,
    );
  }

  factory FeaturedAlbumsConfig.fromJson(Map<String, dynamic> json) {
    return FeaturedAlbumsConfig(
      featuredAlbumIds: List<int>.from(json['featuredAlbumIds'] ?? []),
      maxFeaturedAlbums: json['maxFeaturedAlbums'] ?? 4,
      autoSelectRecent: json['autoSelectRecent'] ?? true,
      showInGalleryHub: json['showInGalleryHub'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featuredAlbumIds': featuredAlbumIds,
      'maxFeaturedAlbums': maxFeaturedAlbums,
      'autoSelectRecent': autoSelectRecent,
      'showInGalleryHub': showInGalleryHub,
    };
  }
}
