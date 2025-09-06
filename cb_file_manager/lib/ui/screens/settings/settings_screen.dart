import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/language_controller.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:cb_file_manager/helpers/media/video_thumbnail_helper.dart'; // Add import for VideoThumbnailHelper
import 'package:cb_file_manager/helpers/network/network_thumbnail_helper.dart'; // Add import for NetworkThumbnailHelper
import 'package:cb_file_manager/helpers/network/win32_smb_helper.dart'; // Add import for Win32SmbHelper
import 'package:cb_file_manager/ui/screens/settings/database_settings_screen.dart'; // Import for database settings screen
import 'package:file_picker/file_picker.dart'; // Import for FilePicker
import 'package:intl/intl.dart'; // Import for DateFormat

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

  // Video thumbnail timestamp value

  // Video thumbnail percentage value (new setting)
  late int _videoThumbnailPercentage;

  // Show file tags setting
  late bool _showFileTags;

  // Cache clearing states
  bool _isClearingVideoCache = false;
  bool _isClearingNetworkCache = false;
  bool _isClearingTempFiles = false;

  // Add a loading indicator state for cache clearing operation
  bool _isClearingCache = false;

  // Cache directory information
  String? _networkCachePath;
  String? _videoCachePath;
  String? _tempFilesPath;
  Map<String, dynamic>? _networkCacheStats;

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
            content: Text('Error loading preferences: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        content: Text('${context.tr.language} ${context.tr.save}'),
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

    // Refresh the percentage in VideoThumbnailHelper
    await VideoThumbnailHelper.refreshThumbnailPercentage();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Đã đặt vị trí hình thu nhỏ video tại $percentage% thời lượng video'),
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
            ? 'Đã bật hiển thị tag của file'
            : 'Đã tắt hiển thị tag của file'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
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

      // Không tự động tạo lại thumbnail sau khi xoá cache.

      // Force refresh of the UI without closing the screen
      if (mounted) {
        // Notify the ImageCache to clear Flutter's internal image cache
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // VideoThumbnailHelper already notifies all listeners via onCacheChanged stream
        // No need to manually refresh this screen since we're already showing proper state
        VideoThumbnailHelper.setVerboseLogging(true);

        // Show success message
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xoá tất cả thumbnail video'),
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

  Future<void> _loadCacheInfo() async {
    try {
      // Get network thumbnail cache path
      final networkHelper = NetworkThumbnailHelper();
      _networkCachePath = await networkHelper.getCacheDirectoryPath();
      _networkCacheStats = await networkHelper.getCacheStats();

      // Get video thumbnail cache path
      _videoCachePath = await VideoThumbnailHelper.getCacheDirectoryPath();

      // Get temp files path
      final win32Helper = Win32SmbHelper();
      _tempFilesPath = win32Helper.tempDirectoryPath;

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
                const Divider(),
                _buildFileTagsSection(context),
                const Divider(),
                _buildCacheManagementSection(
                    context), // Add cache management section
                const Divider(),
                _buildDatabaseSection(context),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              context.tr.selectLanguage,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildLanguageOption(
            title: context.tr.vietnameseLanguage,
            value: LanguageController.vietnamese,
            icon: Icons.language,
            flagEmoji: '🇻🇳',
          ),
          _buildLanguageOption(
            title: context.tr.englishLanguage,
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
            context.tr.selectTheme,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        _buildThemeOption(
          title: context.tr.systemMode,
          subtitle: context.tr.systemThemeDescription,
          value: ThemePreference.system,
          icon: Icons.brightness_auto,
        ),
        _buildThemeOption(
          title: context.tr.lightMode,
          subtitle: context.tr.lightThemeDescription,
          value: ThemePreference.light,
          icon: Icons.light_mode,
        ),
        _buildThemeOption(
          title: context.tr.darkMode,
          subtitle: context.tr.darkThemeDescription,
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
                  context.tr.videoThumbnails,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              context.tr.selectThumbnailPosition,
              style: const TextStyle(
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
                    Text(context.tr.thumbnailPosition),
                    Text(
                      '$_videoThumbnailPercentage% ${context.tr.percentOfVideo}',
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
                  context.tr.thumbnailDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                // Add button to regenerate all thumbnails with new percentage
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isClearingCache
                        ? null
                        : () async {
                            setState(() {
                              _isClearingCache = true;
                            });

                            try {
                              // Clear existing cache and regenerate with new percentage
                              await VideoThumbnailHelper.clearCache();
                              await VideoThumbnailHelper
                                  .refreshThumbnailPercentage();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Đã xóa cache và sẽ tạo lại thumbnail với vị trí $_videoThumbnailPercentage%'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: $e'),
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
                          },
                    icon: _isClearingCache
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(_isClearingCache
                        ? 'Đang xử lý...'
                        : 'Tạo lại thumbnail với vị trí mới'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
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
                Text(
                  context.tr.thumbnailCache,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.thumbnailCacheDescription,
                  style: const TextStyle(
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
                        ? const SizedBox(
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
                        ? context.tr.clearing
                        : context.tr.clearThumbnailCache),
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

  Widget _buildFileTagsSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.label_outline, size: 24),
                const SizedBox(width: 16),
                Text(
                  'Hiển thị tag của file',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              'Hiển thị các tag của file bên ngoài danh sách file trong tất cả các chế độ xem',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Hiển thị tag của file'),
            subtitle:
                const Text('Bật/tắt hiển thị tag bên ngoài danh sách file'),
            value: _showFileTags,
            onChanged: (value) {
              _updateShowFileTags(value);
            },
            secondary: const Icon(Icons.label),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCacheManagementSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.cleaning_services, size: 24),
                const SizedBox(width: 16),
                Text(
                  'Quản lý bộ nhớ cache',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              'Xóa dữ liệu cache để giải phóng bộ nhớ',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cache location information section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_special,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Thư mục cache:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Network cache info
                    if (_networkCacheStats != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.image, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thumbnail mạng:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _networkCachePath ?? 'Chưa khởi tạo',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_networkCacheStats?['fileCount'] != null)
                                  Text(
                                    '${_networkCacheStats!['fileCount']} files (${_networkCacheStats!['totalSizeMB']} MB)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                    ],

                    // Video cache info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.video_file, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thumbnail video:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _videoCachePath ?? 'Chưa khởi tạo',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),

                    // Temp files info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.folder_zip, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File tạm:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tempFilesPath ?? 'Chưa khởi tạo',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _loadCacheInfo();
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã cập nhật thông tin cache'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Làm mới',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Video thumbnails cache
          ListTile(
            title: const Text('Xóa cache video thumbnails'),
            subtitle: const Text('Xóa các thumbnail video đã tạo'),
            leading: const Icon(Icons.video_library),
            trailing: _isClearingVideoCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            onTap: _isClearingVideoCache
                ? null
                : () async {
                    setState(() {
                      _isClearingVideoCache = true;
                    });

                    try {
                      await VideoThumbnailHelper.clearCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa cache thumbnails video'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        // Refresh cache info after clearing
                        _loadCacheInfo();
                      }
                    } catch (e) {
                      debugPrint('Error clearing video cache: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $e'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isClearingVideoCache = false;
                        });
                      }
                    }
                  },
          ),

          // Network thumbnails cache
          ListTile(
            title: const Text('Xóa cache SMB/network thumbnails'),
            subtitle: const Text('Xóa các thumbnail mạng đã tạo'),
            leading: const Icon(Icons.cloud),
            trailing: _isClearingNetworkCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            onTap: _isClearingNetworkCache
                ? null
                : () async {
                    setState(() {
                      _isClearingNetworkCache = true;
                    });

                    try {
                      final networkHelper = NetworkThumbnailHelper();
                      await networkHelper.clearCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa cache thumbnails mạng'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        // Refresh cache info after clearing
                        _loadCacheInfo();
                      }
                    } catch (e) {
                      debugPrint('Error clearing network cache: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $e'),
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
                  },
          ),

          // Temporary files
          ListTile(
            title: const Text('Xóa các file tạm'),
            subtitle: const Text('Xóa file tạm từ chia sẻ mạng'),
            leading: const Icon(Icons.folder_delete),
            trailing: _isClearingTempFiles
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            onTap: _isClearingTempFiles
                ? null
                : () async {
                    setState(() {
                      _isClearingTempFiles = true;
                    });

                    try {
                      final win32Helper = Win32SmbHelper();
                      await win32Helper.clearTempFileCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa các file tạm'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        // Refresh cache info after clearing
                        _loadCacheInfo();
                      }
                    } catch (e) {
                      debugPrint('Error clearing temp files: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $e'),
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
                  },
          ),

          // Clear all cache
          ListTile(
            title: const Text('Xóa tất cả cache'),
            subtitle: const Text('Xóa tất cả dữ liệu cache'),
            leading: const Icon(Icons.cleaning_services),
            trailing: _isClearingVideoCache ||
                    _isClearingNetworkCache ||
                    _isClearingTempFiles ||
                    _isClearingCache
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep),
            onTap: _isClearingVideoCache ||
                    _isClearingNetworkCache ||
                    _isClearingTempFiles ||
                    _isClearingCache
                ? null
                : () async {
                    setState(() {
                      _isClearingCache = true;
                    });

                    try {
                      // Clear all caches
                      await VideoThumbnailHelper.clearCache();
                      final networkHelper = NetworkThumbnailHelper();
                      await networkHelper.clearCache();
                      final win32Helper = Win32SmbHelper();
                      await win32Helper.clearTempFileCache();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa tất cả dữ liệu cache'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        // Refresh cache info after clearing
                        _loadCacheInfo();
                      }
                    } catch (e) {
                      debugPrint('Error clearing all caches: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: $e'),
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
                  },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDatabaseSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.storage, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.databaseSettings,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              context.tr.databaseDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(context.tr.databaseSettings),
            subtitle: Text(context.tr.databaseDescription),
            leading: const Icon(Icons.settings_applications),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DatabaseSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildImportExportSection(context),
          const SizedBox(height: 8),
          ListTile(
            title: Text(context.tr.settingsData),
            subtitle: Text(context.tr.viewManageSettings),
            leading: const Icon(Icons.data_usage),
            onTap: () {
              final settingsData = _preferences.getAllSettings();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr.settingsData),
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
                            subtitle: Text(value), // Convert Object to String
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr.close),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImportExportSection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(context.tr.exportSettings),
          subtitle: Text(context.tr.exportDescription),
          leading: const Icon(Icons.upload_file),
          onTap: () async {
            try {
              // Ask the user to select where to save the file
              String? saveLocation = await FilePicker.platform.saveFile(
                dialogTitle: context.tr.saveSettingsExport,
                fileName:
                    'coolbird_preferences_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
                type: FileType.custom,
                allowedExtensions: ['json'],
              );

              if (saveLocation != null) {
                final filePath = await _preferences.exportPreferences(
                    customPath: saveLocation);
                if (filePath != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr.exportSuccess + filePath),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr.exportFailed),
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
                    content: Text(context.tr.errorExporting + e.toString()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        ListTile(
          title: Text(context.tr.importSettings),
          subtitle: Text(context.tr.importDescription),
          leading: const Icon(Icons.file_download),
          onTap: () async {
            try {
              final success = await _preferences.importPreferences();
              if (success) {
                // Reload preferences after import
                await _loadPreferences();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.importSuccess),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.importFailed),
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
                    content: Text(context.tr.errorImporting + e.toString()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          title: Text(context.tr.completeBackup),
          subtitle: Text(context.tr.exportAllData),
          leading: const Icon(Icons.backup),
          onTap: () async {
            try {
              final dirPath = await _preferences.exportAllData();
              if (dirPath != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.exportSuccess + dirPath),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.exportFailed),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr.errorExporting + e.toString()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        ListTile(
          title: Text(context.tr.completeRestore),
          subtitle: Text(context.tr.importAllData),
          leading: const Icon(Icons.restore),
          onTap: () async {
            try {
              final success = await _preferences.importAllData();
              if (success) {
                // Reload preferences after import
                await _loadPreferences();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.importSuccess),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr.importFailed),
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
                    content: Text(context.tr.errorImporting + e.toString()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ],
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
