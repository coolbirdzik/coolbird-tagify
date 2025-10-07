import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/ui/screens/media_gallery/image_gallery_screen.dart';
import 'package:cb_file_manager/ui/screens/album_management/album_management_screen.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/platform_paths.dart';
import 'package:cb_file_manager/services/featured_albums_service.dart';
import 'package:cb_file_manager/models/objectbox/album.dart';
import 'package:cb_file_manager/ui/screens/settings/featured_albums_settings_screen.dart';

import 'dart:io';
import 'dart:math' as math;

class GalleryHubScreen extends StatefulWidget {
  const GalleryHubScreen({Key? key}) : super(key: key);

  @override
  State<GalleryHubScreen> createState() => _GalleryHubScreenState();
}

class _GalleryHubScreenState extends State<GalleryHubScreen>
    with TickerProviderStateMixin {
  int _totalImages = 0;
  bool _isLoading = true;
  List<Album> _featuredAlbums = [];
  bool _loadingFeaturedAlbums = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
    _loadImageCount();
    _loadFeaturedAlbums();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadImageCount() async {
    try {
      final count = await _countAllImages();
      if (mounted) {
        setState(() {
          _totalImages = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFeaturedAlbums() async {
    try {
      final albums = await FeaturedAlbumsService.instance.getFeaturedAlbums();
      if (mounted) {
        setState(() {
          _featuredAlbums = albums;
          _loadingFeaturedAlbums = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFeaturedAlbums = false;
        });
      }
    }
  }

  Future<int> _countAllImages() async {
    int count = 0;
    final commonPaths = [
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Download',
    ];

    for (final path in commonPaths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File && _isImageFile(entity.path)) {
              count++;
            }
          }
        }
      } catch (e) {
        // Ignore errors for individual directories
      }
    }
    return count;
  }

  bool _isImageFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.8),
              theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 800 ? 48 : 20,
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section
                      _buildWelcomeSection(theme),
                      const SizedBox(height: 40),

                      // Gallery actions
                      _buildGalleryActions(theme, localizations),
                      const SizedBox(height: 40),

                      // Featured albums
                      if (_featuredAlbums.isNotEmpty || _loadingFeaturedAlbums)
                        _buildFeaturedAlbums(theme),
                      if (_featuredAlbums.isNotEmpty || _loadingFeaturedAlbums)
                        const SizedBox(height: 40),

                      // Stats overview
                      _buildStatsOverview(theme),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            cs.primaryContainer.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  remix.Remix.gallery_line,
                  color: cs.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery Hub',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your photos and albums',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_totalImages',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        'Images',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryActions(ThemeData theme, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Gallery Actions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Quick Access',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxis = 2;
            if (constraints.maxWidth > 1200) {
              crossAxis = 4;
            } else if (constraints.maxWidth > 900) {
              crossAxis = 3;
            }

            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxis,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.2,
              ),
              children: [
                _buildActionCard(
                  theme,
                  PlatformPaths.getAllImagesDisplayName(),
                  PlatformPaths.isDesktop
                      ? 'Browse all your pictures'
                      : 'Browse all your photos',
                  remix.Remix.image_line,
                  [Colors.indigo, Colors.indigo.shade300],
                  () => _navigateToAllImages(),
                ),
                _buildActionCard(
                  theme,
                  'Albums',
                  'Organize in albums',
                  remix.Remix.album_line,
                  [Colors.purple, Colors.purple.shade300],
                  () => _navigateToAlbums(),
                ),
                _buildActionCard(
                  theme,
                  PlatformPaths.getCameraDisplayName(),
                  PlatformPaths.isDesktop
                      ? 'Pictures folder'
                      : 'Photos from camera',
                  remix.Remix.camera_line,
                  [Colors.green, Colors.green.shade300],
                  () => _navigateToCamera(),
                ),
                _buildActionCard(
                  theme,
                  PlatformPaths.getDownloadsDisplayName(),
                  PlatformPaths.isDesktop
                      ? 'Downloaded files'
                      : 'Downloaded images',
                  remix.Remix.download_line,
                  [Colors.orange, Colors.orange.shade300],
                  () => _navigateToDownloads(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    ThemeData theme,
    String title,
    String description,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedAlbums(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.secondary,
                    theme.colorScheme.secondary.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Featured Albums',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Personalized',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _openFeaturedAlbumsSettings(),
              tooltip: 'Configure Featured Albums',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_loadingFeaturedAlbums)
          const Center(child: CircularProgressIndicator())
        else if (_featuredAlbums.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  remix.Remix.album_line,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Featured Albums',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create some albums to see them featured here',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxis = 2;
              if (constraints.maxWidth > 1200) {
                crossAxis = 4;
              } else if (constraints.maxWidth > 900) {
                crossAxis = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.1,
                ),
                itemCount: _featuredAlbums.length,
                itemBuilder: (context, index) {
                  final album = _featuredAlbums[index];
                  return _buildFeaturedAlbumCard(theme, album);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildFeaturedAlbumCard(ThemeData theme, Album album) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _navigateToAlbum(album),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.secondary,
                          theme.colorScheme.secondary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      remix.Remix.album_fill,
                      size: 20,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(
                      remix.Remix.more_line,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onSelected: (value) {
                      if (value == 'remove') {
                        _removeFromFeatured(album);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(remix.Remix.star_line, size: 16),
                            const SizedBox(width: 8),
                            const Text('Remove from Featured'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        album.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                remix.Remix.bar_chart_line,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Gallery Statistics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'Total Images',
                    '$_totalImages',
                    remix.Remix.image_line,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'Albums',
                    '0', // TODO: Get actual album count
                    remix.Remix.album_line,
                    Colors.purple,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickActions(ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildCompactActionCard(
          theme,
          'All Images',
          remix.Remix.image_line,
          Colors.indigo,
          () => _navigateToAllImages(),
        ),
        _buildCompactActionCard(
          theme,
          'Albums',
          remix.Remix.album_line,
          Colors.purple,
          () => _navigateToAlbums(),
        ),
        _buildCompactActionCard(
          theme,
          'Camera',
          remix.Remix.camera_line,
          Colors.green,
          () => _navigateToCamera(),
        ),
        _buildCompactActionCard(
          theme,
          'Downloads',
          remix.Remix.download_line,
          Colors.orange,
          () => _navigateToDownloads(),
        ),
        _buildCompactActionCard(
          theme,
          'Recent',
          remix.Remix.time_line,
          Colors.red,
          () => _navigateToRecent(),
        ),
        _buildCompactActionCard(
          theme,
          'Folders',
          remix.Remix.folder_image_line,
          Colors.blue,
          () => _navigateToFolders(),
        ),
      ],
    );
  }

  Widget _buildCompactActionCard(
    ThemeData theme,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAllImages() async {
    // Navigate to a general image gallery showing all images using tab system
    final path = await PlatformPaths.getAllImagesPath();
    final displayName = PlatformPaths.getAllImagesDisplayName();
    if (!mounted) return;
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(AddTab(
      path: path,
      name: displayName,
      switchToTab: true,
    ));
  }

  void _navigateToAlbums() {
    // Navigate within current tab to Albums (#albums)
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    final activeTab = tabBloc.state.activeTab;
    if (activeTab != null) {
      TabNavigator.updateTabPath(context, activeTab.id, '#albums');
      tabBloc.add(UpdateTabName(activeTab.id, 'Albums'));
    } else {
      // Fallback: if no active tab exists, create one
      tabBloc.add(AddTab(
        path: '#albums',
        name: 'Albums',
        switchToTab: true,
      ));
    }
  }

  void _navigateToCamera() async {
    // Navigate to camera photos using tab system
    final path = await PlatformPaths.getCameraPath();
    final displayName = PlatformPaths.getCameraDisplayName();
    if (!mounted) return;
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(AddTab(
      path: path,
      name: displayName,
      switchToTab: true,
    ));
  }

  void _navigateToDownloads() async {
    // Navigate to downloads using tab system
    final path = await PlatformPaths.getDownloadsPath();
    final displayName = PlatformPaths.getDownloadsDisplayName();
    if (!mounted) return;
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    tabBloc.add(AddTab(
      path: path,
      name: displayName,
      switchToTab: true,
    ));
  }

  void _navigateToRecent() {
    // TODO: Implement recent images logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recent images feature coming soon!')),
    );
  }

  void _navigateToFolders() {
    // Navigate back to file manager with image filter
    Navigator.pop(context);
  }

  void _navigateToAlbum(Album album) {
    // Navigate to album detail within the same tab using system path router
    final tabBloc = BlocProvider.of<TabManagerBloc>(context);
    final activeTab = tabBloc.state.activeTab;
    final path = '#album/${album.id}';
    if (activeTab != null) {
      TabNavigator.updateTabPath(context, activeTab.id, path);
      tabBloc.add(UpdateTabName(activeTab.id, album.name));
    } else {
      // Fallback: no active tab, open as new tab
      tabBloc.add(AddTab(
        path: path,
        name: album.name,
        switchToTab: true,
      ));
    }
  }

  void _removeFromFeatured(Album album) async {
    final success =
        await FeaturedAlbumsService.instance.removeFromFeatured(album.id);
    if (success && mounted) {
      // Reload featured albums
      _loadFeaturedAlbums();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${album.name} removed from featured albums'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await FeaturedAlbumsService.instance.addToFeatured(album.id);
              _loadFeaturedAlbums();
            },
          ),
        ),
      );
    }
  }

  void _openFeaturedAlbumsSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeaturedAlbumsSettingsScreen(),
      ),
    );
    // Reload featured albums when returning from settings
    _loadFeaturedAlbums();
  }
}
