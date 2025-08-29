import 'package:flutter/material.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/translation_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

/// A screen for managing database settings
class DatabaseSettingsScreen extends StatefulWidget {
  const DatabaseSettingsScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseSettingsScreen> createState() => _DatabaseSettingsScreenState();
}

class _DatabaseSettingsScreenState extends State<DatabaseSettingsScreen> {
  final UserPreferences _preferences = UserPreferences.instance;
  final DatabaseManager _databaseManager = DatabaseManager.getInstance();

  bool _isUsingObjectBox = false;
  bool _isCloudSyncEnabled = false;
  bool _isLoading = true;
  bool _isSyncing = false;
// Add this line

  Set<String> _uniqueTags = {};
  Map<String, int> _popularTags = {};
  int _totalTagCount = 0;
  int _totalFileCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadPreferences();
      await _databaseManager.initialize();

      // Load settings
      _isCloudSyncEnabled = _databaseManager.isCloudSyncEnabled();

      // Load statistics
      await _loadStatistics();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading database settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    try {
      await _preferences.init();
      final useObjectBox = _preferences.isUsingObjectBox();

      if (mounted) {
        setState(() {
          _isUsingObjectBox = useObjectBox;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading database preferences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading database preferences: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Get all unique tags
      final allTags = await _databaseManager.getAllUniqueTags();
      _uniqueTags = Set.from(allTags);
      _totalTagCount = _uniqueTags.length;

      // Get popular tags (top 10)
      _popularTags = await TagManager.instance.getPopularTags(limit: 10);

      // Count total number of tagged files
      final List<Future<List<String>>> fileFutures = [];
      for (final tag in _uniqueTags.take(5)) {
        // Limit to first 5 tags to avoid too many queries
        fileFutures.add(_databaseManager.findFilesByTag(tag));
      }

      final results = await Future.wait(fileFutures);
      final Set<String> allFiles = {};
      for (final files in results) {
        allFiles.addAll(files);
      }

      _totalFileCount = allFiles.length;
    } catch (e) {
      debugPrint('Error loading database statistics: $e');
    }
  }

  Future<void> _toggleObjectBoxEnabled(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _preferences.setUsingObjectBox(value);

      if (value && !_isUsingObjectBox) {
        // Switch from JSON to ObjectBox - migrate the data
        final migratedCount = await TagManager.migrateFromJsonToObjectBox();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Migrated $migratedCount files to ObjectBox database')),
        );
      }

      _isUsingObjectBox = value;

      // Reload statistics
      await _loadStatistics();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error toggling ObjectBox: $e');

      // Revert the change
      await _preferences.setUsingObjectBox(!value);
      _isUsingObjectBox = !value;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCloudSyncEnabled(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      _databaseManager.setCloudSyncEnabled(value);
      await _preferences.setCloudSyncEnabled(value);
      _isCloudSyncEnabled = value;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error toggling cloud sync: $e');

      // Revert the change
      _databaseManager.setCloudSyncEnabled(!value);
      await _preferences.setCloudSyncEnabled(!value);
      _isCloudSyncEnabled = !value;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncToCloud() async {
    if (!_isCloudSyncEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud sync is not enabled')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final success = await _databaseManager.syncToCloud();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced to cloud successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error syncing to cloud')),
        );
      }

      setState(() {
        _isSyncing = false;
      });
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncFromCloud() async {
    if (!_isCloudSyncEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud sync is not enabled')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final success = await _databaseManager.syncFromCloud();

      if (success) {
        // Reload statistics
        await _loadStatistics();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced from cloud successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error syncing from cloud')),
        );
      }

      setState(() {
        _isSyncing = false;
      });
    } catch (e) {
      debugPrint('Error syncing from cloud: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: context.tr.databaseSettings,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildDatabaseTypeSection(),
                const Divider(),
                _buildCloudSyncSection(),
                const Divider(),
                _buildImportExportSection(),
                const Divider(),
                _buildStatisticsSection(),
              ],
            ),
    );
  }

  Widget _buildDatabaseTypeSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.storage, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.databaseStorage,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(context.tr.useObjectBox),
            subtitle: Text(context.tr.databaseDescription),
            value: _isUsingObjectBox,
            onChanged: _toggleObjectBoxEnabled,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _isUsingObjectBox
                  ? context.tr.objectBoxStorage
                  : context.tr.jsonStorage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCloudSyncSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.cloudSync,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(context.tr.enableCloudSync),
            subtitle: Text(context.tr.cloudSyncDescription),
            value: _isCloudSyncEnabled,
            onChanged: _isUsingObjectBox ? _toggleCloudSyncEnabled : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _isUsingObjectBox
                  ? (_isCloudSyncEnabled
                      ? context.tr.cloudSyncEnabled
                      : context.tr.cloudSyncDisabled)
                  : context.tr.enableObjectBoxForCloud,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(context.tr.syncToCloud),
                  onPressed:
                      _isCloudSyncEnabled && !_isSyncing ? _syncToCloud : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: Text(context.tr.syncFromCloud),
                  onPressed: _isCloudSyncEnabled && !_isSyncing
                      ? _syncFromCloud
                      : null,
                ),
              ],
            ),
          ),
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildImportExportSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.import_export, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.importExportDatabase,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.tr.backupRestoreDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: Text(context.tr.exportDatabase),
            subtitle: Text(context.tr.exportDescription),
            leading: const Icon(Icons.upload_file),
            onTap: () async {
              try {
                // Ask the user to choose where to save the file
                String? saveLocation = await FilePicker.platform.saveFile(
                  dialogTitle: context.tr.saveDatabaseExport,
                  fileName:
                      'coolbird_db_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );

                if (saveLocation != null) {
                  final filePath = await _databaseManager.exportDatabase(
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
            title: Text(context.tr.importDatabase),
            subtitle: Text(context.tr.importDescription),
            leading: const Icon(Icons.file_download),
            onTap: () async {
              try {
                // Open file picker to select the database export file
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );

                if (result != null && result.files.single.path != null) {
                  final filePath = result.files.single.path!;
                  final success =
                      await _databaseManager.importDatabase(filePath);

                  if (success) {
                    // Reload statistics after import
                    await _loadStatistics();
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
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr.importCancelled),
                        behavior: SnackBarBehavior.floating,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, size: 24),
                const SizedBox(width: 16),
                Text(
                  context.tr.databaseStatistics,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(context.tr.totalUniqueTags),
            trailing: Text(
              '$_totalTagCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: Text(context.tr.taggedFiles),
            trailing: Text(
              '$_totalFileCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.tr.popularTags,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _popularTags.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text(context.tr.noTagsFound)),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularTags.entries.map((entry) {
                      return Chip(
                        label: Text(entry.key),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        avatar: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(context.tr.refreshStatistics),
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                  });
                  await _loadStatistics();
                  setState(() {
                    _isLoading = false;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
