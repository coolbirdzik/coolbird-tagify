import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/language_controller.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/network/network_thumbnail_helper.dart';
import 'package:cb_file_manager/helpers/network/win32_smb_helper.dart';
import 'package:cb_file_manager/ui/screens/settings/database_settings_screen.dart';
import 'package:cb_file_manager/ui/screens/settings/theme_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart' as remix;
import 'package:cb_file_manager/config/languages/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserPreferences _preferences = UserPreferences.instance;
  final LanguageController _languageController = LanguageController();
  late ThemePreference _themePreference;
  late String _currentLanguageCode;
  late bool _isLoading = true;

  // Video thumbnail percentage value
  late int _videoThumbnailPercentage;

  // Show file tags setting
  late bool _showFileTags;

  // Cache clearing states
  bool _isClearingVideoCache = false;
  bool _isClearingNetworkCache = false;
  bool _isClearingTempFiles = false;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadCacheInfo();
  }

  Future<void> _loadPreferences() async {
    try {
      await _preferences.init();
      final theme = await _preferences.getThemePreference();
      final percentage = await _preferences.getVideoThumbnailPercentage();
      final showFileTags = await _preferences.getShowFileTags();
      _preferences.isUsingObjectBox();

      if (mounted) {
        setState(() {
          _themePreference = theme;
          _currentLanguageCode = _languageController.currentLocale.languageCode;
          _videoThumbnailPercentage = percentage;
          _showFileTags = showFileTags;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorLoadingTags + '$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateLanguage(String languageCode) async {
    await _languageController.changeLanguage(languageCode);
    setState(() {
      _currentLanguageCode = languageCode;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${AppLocalizations.of(context)!.language} ${AppLocalizations.of(context)!.save}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateVideoThumbnailPercentage(int percentage) async {
    await _preferences.setVideoThumbnailPercentage(percentage);
    setState(() {
      _videoThumbnailPercentage = percentage;
    });

    await VideoThumbnailHelper.refreshThumbnailPercentage();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.thumbnailPositionUpdated +
            '$percentage%'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 320,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateShowFileTags(bool showTags) async {
    await _preferences.setShowFileTags(showTags);
    setState(() {
      _showFileTags = showTags;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(showTags
            ? AppLocalizations.of(context)!.fileTagsEnabled
            : AppLocalizations.of(context)!.fileTagsDisabled),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearVideoThumbnailCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      await VideoThumbnailHelper.clearCache();

      if (mounted) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        VideoThumbnailHelper.setVerboseLogging(true);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.thumbnailCleared),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 320,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.errorClearingThumbnail + '$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 320,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      debugPrint('Error clearing video thumbnail cache: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _loadCacheInfo() async {
    try {
      // Cache info loading is now handled in individual cache operations
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading cache info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: AppLocalizations.of(context)!.settings,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickSettingsSection(),
                  const SizedBox(height: 24),
                  _buildMediaSettingsSection(),
                  const SizedBox(height: 24),
                  _buildCacheManagementSection(),
                  const SizedBox(height: 24),
                  _buildDatabaseSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickSettingsSection() {
    return _buildSectionCard(
      title: AppLocalizations.of(context)!.interface,
      icon: remix.Remix.settings_3_line,
      children: [
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.language,
          subtitle: _currentLanguageCode == 'vi'
              ? AppLocalizations.of(context)!.vietnameseLanguage
              : AppLocalizations.of(context)!.englishLanguage,
          icon: remix.Remix.global_line,
          onTap: () => _showLanguageDialog(),
        ),
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.theme,
          subtitle: _getThemeDisplayName(),
          icon: remix.Remix.palette_line,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ThemeSettingsScreen(),
              ),
            );
          },
        ),
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.showFileTags,
          subtitle: AppLocalizations.of(context)!.showFileTagsToggleDescription,
          icon: remix.Remix.price_tag_3_line,
          trailing: Switch(
            value: _showFileTags,
            onChanged: _updateShowFileTags,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSettingsSection() {
    return _buildSectionCard(
      title: AppLocalizations.of(context)!.videoThumbnails,
      icon: remix.Remix.video_line,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.thumbnailPosition,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_videoThumbnailPercentage%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _videoThumbnailPercentage.toDouble(),
                min: UserPreferences.minVideoThumbnailPercentage.toDouble(),
                max: UserPreferences.maxVideoThumbnailPercentage.toDouble(),
                divisions: 20,
                onChanged: (value) {
                  setState(() {
                    _videoThumbnailPercentage = value.round();
                  });
                },
                onChangeEnd: (value) {
                  _updateVideoThumbnailPercentage(value.round());
                },
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.thumbnailDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCacheManagementSection() {
    return _buildSectionCard(
      title: AppLocalizations.of(context)!.cacheManagement,
      icon: remix.Remix.brush_line,
      children: [
        // Cache info summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                remix.Remix.information_line,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.cacheManagementDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Quick clear buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCacheButton(
                label: AppLocalizations.of(context)!.clearVideoThumbnailsCache,
                icon: remix.Remix.video_line,
                isLoading: _isClearingVideoCache,
                onTap: _clearVideoThumbnailCache,
              ),
              _buildCacheButton(
                label:
                    AppLocalizations.of(context)!.clearNetworkThumbnailsCache,
                icon: remix.Remix.cloud_line,
                isLoading: _isClearingNetworkCache,
                onTap: _clearNetworkCache,
              ),
              _buildCacheButton(
                label: AppLocalizations.of(context)!.clearTempFilesCache,
                icon: remix.Remix.folder_reduce_line,
                isLoading: _isClearingTempFiles,
                onTap: _clearTempFiles,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Clear all button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAnyCacheClearing ? null : _clearAllCache,
            icon: _isAnyCacheClearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(remix.Remix.delete_bin_2_line),
            label: Text(AppLocalizations.of(context)!.clearAllCache),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseSection() {
    return _buildSectionCard(
      title: AppLocalizations.of(context)!.databaseSettings,
      icon: remix.Remix.database_2_line,
      children: [
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.databaseSettings,
          subtitle: AppLocalizations.of(context)!.databaseDescription,
          icon: remix.Remix.settings_3_line,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DatabaseSettingsScreen(),
              ),
            );
          },
        ),
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.exportSettings,
          subtitle: AppLocalizations.of(context)!.exportDescription,
          icon: remix.Remix.upload_line,
          onTap: _exportSettings,
        ),
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.importSettings,
          subtitle: AppLocalizations.of(context)!.importDescription,
          icon: remix.Remix.download_line,
          onTap: _importSettings,
        ),
        _buildCompactSettingTile(
          title: AppLocalizations.of(context)!.settingsData,
          subtitle: AppLocalizations.of(context)!.viewManageSettings,
          icon: remix.Remix.pie_chart_line,
          onTap: _showSettingsData,
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompactSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, size: 20),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(remix.Remix.arrow_right_s_line, size: 16)
              : null),
      onTap: onTap,
    );
  }

  Widget _buildCacheButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _getThemeDisplayName() {
    switch (_themePreference) {
      case ThemePreference.system:
        return AppLocalizations.of(context)!.systemMode;
      case ThemePreference.light:
        return AppLocalizations.of(context)!.lightMode;
      case ThemePreference.dark:
        return AppLocalizations.of(context)!.darkMode;
    }
  }

  bool get _isAnyCacheClearing =>
      _isClearingVideoCache ||
      _isClearingNetworkCache ||
      _isClearingTempFiles ||
      _isClearingCache;

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              title: AppLocalizations.of(context)!.vietnameseLanguage,
              value: LanguageController.vietnamese,
              flagEmoji: '🇻🇳',
            ),
            _buildLanguageOption(
              title: AppLocalizations.of(context)!.englishLanguage,
              value: LanguageController.english,
              flagEmoji: '🇬🇧',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String value,
    required String flagEmoji,
  }) {
    final isSelected = _currentLanguageCode == value;

    return ListTile(
      title: Row(
        children: [
          Text(flagEmoji),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      trailing: isSelected
          ? Icon(remix.Remix.checkbox_circle_line,
              color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        _updateLanguage(value);
        Navigator.pop(context);
      },
      selected: isSelected,
    );
  }

  Future<void> _clearNetworkCache() async {
    setState(() {
      _isClearingNetworkCache = true;
    });

    try {
      final networkHelper = NetworkThumbnailHelper();
      await networkHelper.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.networkCacheCleared),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCacheInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorClearingCache + '$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingNetworkCache = false;
        });
      }
    }
  }

  Future<void> _clearTempFiles() async {
    setState(() {
      _isClearingTempFiles = true;
    });

    try {
      final win32Helper = Win32SmbHelper();
      await win32Helper.clearTempFileCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.tempFilesCleared),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCacheInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorClearingCache + '$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingTempFiles = false;
        });
      }
    }
  }

  Future<void> _clearAllCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      await VideoThumbnailHelper.clearCache();
      final networkHelper = NetworkThumbnailHelper();
      await networkHelper.clearCache();
      final win32Helper = Win32SmbHelper();
      await win32Helper.clearTempFileCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.allCacheCleared),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCacheInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorClearingCache + '$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _exportSettings() async {
    try {
      String? saveLocation = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.of(context)!.saveSettingsExport,
        fileName:
            'coolbird_preferences_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (saveLocation != null) {
        final filePath =
            await _preferences.exportPreferences(customPath: saveLocation);
        if (filePath != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.exportSuccess + filePath),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.exportFailed),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.errorExporting + e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importSettings() async {
    try {
      final success = await _preferences.importPreferences();
      if (success) {
        await _loadPreferences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.importSuccess),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.importFailed),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.errorImporting + e.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsData() {
    final settingsData = _preferences.getAllSettings();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsData),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: settingsData.keys.map((setting) {
                final String value = settingsData[setting].toString();
                return ListTile(
                  title: Text(setting),
                  subtitle: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }
}
