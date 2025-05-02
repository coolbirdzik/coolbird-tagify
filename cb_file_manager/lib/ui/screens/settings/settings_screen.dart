import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/language_controller.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/helpers/video_thumbnail_helper.dart'; // Add import for VideoThumbnailHelper

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserPreferences _preferences = UserPreferences();
  final LanguageController _languageController = LanguageController();
  late ThemePreference _themePreference;
  late String _currentLanguageCode;
  late bool _isLoading = true;

  // Video thumbnail timestamp value
  late int _videoThumbnailTimestamp;

  // Video thumbnail percentage value (new setting)
  late int _videoThumbnailPercentage;

  // Add a loading indicator state for cache clearing operation
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    await _preferences.init();
    setState(() {
      _themePreference = _preferences.getThemePreference();
      _currentLanguageCode = _languageController.currentLocale.languageCode;
      _videoThumbnailTimestamp = _preferences.getVideoThumbnailTimestamp();
      _videoThumbnailPercentage = _preferences.getVideoThumbnailPercentage();
      _isLoading = false;
    });
  }

  Future<void> _updateThemePreference(ThemePreference preference) async {
    await _preferences.setThemePreference(preference);
    setState(() {
      _themePreference = preference;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.save),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 160,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateLanguage(String languageCode) async {
    await _languageController.changeLanguage(languageCode);
    setState(() {
      _currentLanguageCode = languageCode;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.language + ' ' + context.tr.save),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateVideoThumbnailTimestamp(int seconds) async {
    await _preferences.setVideoThumbnailTimestamp(seconds);
    setState(() {
      _videoThumbnailTimestamp = seconds;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video thumbnail timestamp set to $seconds seconds'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 280,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateVideoThumbnailPercentage(int percentage) async {
    await _preferences.setVideoThumbnailPercentage(percentage);
    setState(() {
      _videoThumbnailPercentage = percentage;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Video thumbnail position set to $percentage% of video duration'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 320,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Add method to clear the video thumbnail cache
  Future<void> _clearVideoThumbnailCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      // Call the clearCache method from VideoThumbnailHelper
      await VideoThumbnailHelper.clearCache();

      // Get the current directory path from context or last opened folder
      String currentDirectory = _preferences.getLastAccessedFolder() ?? '';

      // Only attempt to regenerate thumbnails if we're still mounted
      // This prevents crashes when users navigate back immediately
      if (mounted && currentDirectory.isNotEmpty) {
        try {
          // Regenerate thumbnails for the current directory automatically
          // Add timeout to prevent hanging if the process takes too long
          await VideoThumbnailHelper.regenerateThumbnailsForDirectory(
                  currentDirectory)
              .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              // Just log timeout but don't throw an exception
              debugPrint(
                  'Thumbnail regeneration timed out, user may have navigated away');
            },
          );
        } catch (e) {
          // Catch and log errors but don't fail the entire operation
          debugPrint('Error during thumbnail regeneration: $e');
        }
      }

      // Force refresh of the UI by rebuilding the widget tree
      if (mounted) {
        // Notify the ImageCache to clear Flutter's internal image cache
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // Send a notification to folder screens that thumbnails have been cleared
        // This will trigger a rebuild of any folder screens that are visible
        VideoThumbnailHelper.setVerboseLogging(true);

        // Force the application to rebuild screens that might be showing thumbnails
        try {
          // Wait a short time for the cache clearing operation to complete
          await Future.delayed(const Duration(milliseconds: 100));

          // Use this special method to notify the app's state needs to refresh
          final navigatorState = Navigator.of(context);
          if (navigatorState.canPop()) {
            // Briefly pop and push the same screen to force a refresh
            navigatorState.pop();
            await Future.delayed(const Duration(milliseconds: 50));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
          }
        } catch (e) {
          debugPrint('Error refreshing UI after cache clear: $e');
        }
      }

      // Show success message only if we're still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xoá tất cả thumbnail video'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 320,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xoá thumbnail: $e'),
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
      // Make sure to reset loading state even if there's an error
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: context.tr.settings,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildLanguageSection(context),
                const Divider(),
                _buildThemeSection(context),
                const Divider(),
                _buildVideoThumbnailSection(context),
              ],
            ),
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.language, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.language,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              'Choose your preferred language',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildLanguageOption(
            title: 'Tiếng Việt',
            value: LanguageController.vietnamese,
            icon: Icons.language,
            flagEmoji: '🇻🇳',
          ),
          _buildLanguageOption(
            title: 'English',
            value: LanguageController.english,
            icon: Icons.language,
            flagEmoji: '🇬🇧',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.tr.theme,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Choose how the app looks',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        _buildThemeOption(
          title: context.tr.systemMode,
          subtitle: 'Follow system theme settings',
          value: ThemePreference.system,
          icon: Icons.brightness_auto,
        ),
        _buildThemeOption(
          title: context.tr.lightMode,
          subtitle: 'Light theme for all screens',
          value: ThemePreference.light,
          icon: Icons.light_mode,
        ),
        _buildThemeOption(
          title: context.tr.darkMode,
          subtitle: 'Dark theme for all screens',
          value: ThemePreference.dark,
          icon: Icons.dark_mode,
        ),
      ],
    );
  }

  Widget _buildVideoThumbnailSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.videocam_outlined, size: 24),
                const SizedBox(width: 16),
                Text(
                  'Video Thumbnails',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              'Choose where to extract video thumbnails from',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Thumbnail position:'),
                    Text(
                      '$_videoThumbnailPercentage% of video',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _videoThumbnailPercentage.toDouble(),
                  min: UserPreferences.minVideoThumbnailPercentage.toDouble(),
                  max: UserPreferences.maxVideoThumbnailPercentage.toDouble(),
                  divisions: 20,
                  label: '$_videoThumbnailPercentage%',
                  onChanged: (value) {
                    setState(() {
                      _videoThumbnailPercentage = value.round();
                    });
                  },
                  onChangeEnd: (value) {
                    _updateVideoThumbnailPercentage(value.round());
                  },
                ),
                Text(
                  'Set the position in the video (as a percentage of total duration) where thumbnails will be extracted. Lower values (near the beginning) load faster but may show intros or blank screens. Higher values may show more representative content.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thumbnail Cache',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Video thumbnails are cached to improve performance. If thumbnails appear outdated or you want to free up space, you can clear the cache.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isClearingCache ? null : _clearVideoThumbnailCache,
                    icon: _isClearingCache
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.cleaning_services_outlined),
                    label: Text(_isClearingCache
                        ? 'Clearing...'
                        : 'Clear Thumbnail Cache'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildLanguageOption({
    required String title,
    required String value,
    required IconData icon,
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
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () => _updateLanguage(value),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required ThemePreference value,
    required IconData icon,
  }) {
    final isSelected = _themePreference == value;

    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () => _updateThemePreference(value),
      selected: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
