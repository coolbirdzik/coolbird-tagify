import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/config/translation_helper.dart';

/// Simple home screen that doesn't scan file system to avoid performance issues
class HomeScreen extends StatefulWidget {
  final String tabId;

  const HomeScreen({
    Key? key,
    required this.tabId,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

                      // Quick actions
                      _buildQuickActions(theme, localizations),
                      const SizedBox(height: 40),

                      // Features overview
                      _buildFeaturesOverview(theme, localizations),
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
                  remix.Remix.home_3_line,
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
                      context.tr.welcomeTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr.welcomeSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  remix.Remix.lightbulb_line,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr.quickActionsTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
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
              context.tr.quickActionsHome,
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
                context.tr.startHere,
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
                  context.tr.newTabAction,
                  context.tr.newTabActionDesc,
                  remix.Remix.add_circle_line,
                  [Colors.indigo, Colors.indigo.shade300],
                  () => _openNewTab(),
                ),
                _buildActionCard(
                  theme,
                  localizations.browseFiles,
                  localizations.browseFilesDescription,
                  remix.Remix.folder_3_line,
                  [Colors.blue, Colors.blue.shade300],
                  () => _navigateToPath(''),
                ),
                _buildActionCard(
                  theme,
                  localizations.imageGallery,
                  localizations.manageMediaDescription,
                  remix.Remix.image_line,
                  [Colors.purple, Colors.purple.shade300],
                  () => _openImageGallery(),
                ),
                _buildActionCard(
                  theme,
                  localizations.videoGallery,
                  localizations.manageMediaDescription,
                  remix.Remix.video_line,
                  [Colors.orange, Colors.orange.shade300],
                  () => _openVideoGallery(),
                ),
                _buildActionCard(
                  theme,
                  context.tr.tagsAction,
                  context.tr.tagsActionDesc,
                  remix.Remix.price_tag_3_line,
                  [Colors.green, Colors.green.shade300],
                  () => _openTagsTab(),
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

  Widget _buildFeaturesOverview(
      ThemeData theme, AppLocalizations localizations) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  remix.Remix.star_line,
                  color: cs.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                localizations.keyFeatures,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFeatureItem(
            theme,
            remix.Remix.folder_3_line,
            localizations.fileManagement,
            localizations.fileManagementDescription,
            Colors.blue,
          ),
          _buildFeatureItem(
            theme,
            remix.Remix.price_tag_3_line,
            localizations.smartTagging,
            localizations.smartTaggingDescription,
            Colors.green,
          ),
          _buildFeatureItem(
            theme,
            remix.Remix.image_line,
            localizations.mediaGallery,
            localizations.mediaGalleryDescription,
            Colors.purple,
          ),
          _buildFeatureItem(
            theme,
            remix.Remix.wifi_line,
            localizations.networkSupport,
            localizations.networkSupportDescription,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    IconData icon,
    String title,
    String description,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openImageGallery() {
    // Open Gallery Hub as a new tab instead of a separate screen
    context.read<TabManagerBloc>().add(AddTab(
          path: '#gallery',
          name: 'Gallery Hub',
        ));
  }

  void _openVideoGallery() {
    final tabManager = context.read<TabManagerBloc>();
    final activeTab = tabManager.state.activeTab;
    if (activeTab != null) {
      TabNavigator.updateTabPath(context, activeTab.id, '#video');
      tabManager.add(UpdateTabName(activeTab.id, 'Video Hub'));
    } else {
      tabManager.add(AddTab(
        path: '#video',
        name: 'Video Hub',
      ));
    }
  }

  void _openNewTab() async {
    if (!mounted) return;

    try {
      final tabBloc = context.read<TabManagerBloc>();

      // Check platform and create appropriate new tab
      if (Platform.isWindows) {
        // For Windows, create tab with empty path to show drive picker
        tabBloc.add(AddTab(path: '', name: context.tr.drivesTab));
      } else if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, try to get storage locations
        try {
          final storageLocations = await getAllStorageLocations();
          if (!mounted) return;

          if (storageLocations.isNotEmpty) {
            final firstStorage = storageLocations.first;
            final tabBloc = context.read<TabManagerBloc>();
            tabBloc.add(AddTab(
              path: firstStorage.path,
              name: _getStorageDisplayName(firstStorage.path),
            ));
          } else {
            // Fallback for mobile
            final tabBloc = context.read<TabManagerBloc>();
            tabBloc.add(AddTab(path: '', name: context.tr.browseTab));
          }
        } catch (e) {
          if (!mounted) return;
          final tabBloc = context.read<TabManagerBloc>();
          tabBloc.add(AddTab(path: '', name: context.tr.browseTab));
        }
      } else {
        // For other platforms (Linux, macOS), use documents directory
        try {
          final directory = await getApplicationDocumentsDirectory();
          if (!mounted) return;

          final tabBloc = context.read<TabManagerBloc>();
          tabBloc
              .add(AddTab(path: directory.path, name: context.tr.documentsTab));
        } catch (e) {
          if (!mounted) return;
          final tabBloc = context.read<TabManagerBloc>();
          tabBloc.add(
              AddTab(path: Directory.current.path, name: context.tr.homeTab));
        }
      }
    } catch (e) {
      // Last resort fallback
      if (!mounted) return;
      final tabBloc = context.read<TabManagerBloc>();
      tabBloc.add(AddTab(path: '', name: context.tr.browseTab));
    }
  }

  String _getStorageDisplayName(String path) {
    if (path.isEmpty) return context.tr.drivesTab;

    // For Android, try to extract meaningful name
    if (Platform.isAndroid) {
      if (path.contains('/storage/emulated/0')) {
        return context.tr.internalStorage;
      } else if (path.contains('/storage/')) {
        final parts = path.split('/');
        if (parts.length >= 3) {
          final storageId = parts[2];
          if (storageId.isNotEmpty && storageId != 'emulated') {
            return '${context.tr.storagePrefix} $storageId';
          }
        }
      }
    }

    // For iOS or other cases, use the last part of the path
    final parts = path.split('/');
    final lastPart =
        parts.lastWhere((part) => part.isNotEmpty, orElse: () => '');
    return lastPart.isEmpty ? context.tr.rootFolder : lastPart;
  }

  void _navigateToPath(String path) {
    final tabBloc = context.read<TabManagerBloc>();
    tabBloc.add(UpdateTabPath(widget.tabId, path));
  }

  void _openTagsTab() {
    final tabBloc = context.read<TabManagerBloc>();

    // Check if a tags tab already exists
    final existingTab = tabBloc.state.tabs.firstWhere(
      (tab) => tab.path == '#tags',
      orElse: () => TabData(id: '', name: '', path: ''),
    );

    if (existingTab.id.isNotEmpty) {
      // If tab exists, switch to it
      tabBloc.add(SwitchToTab(existingTab.id));
    } else {
      // Otherwise, create a new tab
      tabBloc.add(
        AddTab(
          path: '#tags',
          name: 'Tags',
          switchToTab: true,
        ),
      );
    }
  }
}
