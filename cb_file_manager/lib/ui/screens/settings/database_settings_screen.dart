import 'package:flutter/material.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/config/translation_helper.dart';

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
  bool _isToggling = false;
  bool _isUpdating = false; // Add this line

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
      print('Error loading database settings: $e');
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
      print('Error loading database statistics: $e');
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
      print('Error toggling ObjectBox: $e');

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
      print('Error toggling cloud sync: $e');

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
        SnackBar(content: Text('Cloud sync is not enabled')),
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
          SnackBar(content: Text('Data synced to cloud successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing to cloud')),
        );
      }

      setState(() {
        _isSyncing = false;
      });
    } catch (e) {
      print('Error syncing to cloud: $e');

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
        SnackBar(content: Text('Cloud sync is not enabled')),
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
          SnackBar(content: Text('Data synced from cloud successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing from cloud')),
        );
      }

      setState(() {
        _isSyncing = false;
      });
    } catch (e) {
      print('Error syncing from cloud: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _updateUseObjectBox(bool value) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await _preferences.setUseObjectBox(value);
      setState(() {
        _isUsingObjectBox = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Database setting updated. Using ${value ? 'ObjectBox' : 'JSON files'}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating database setting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Database Settings',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildDatabaseTypeSection(),
                const Divider(),
                _buildCloudSyncSection(),
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
                  'Database Storage',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Use ObjectBox Database'),
            subtitle:
                const Text('Store tags and preferences in a local database'),
            value: _isUsingObjectBox,
            onChanged: _toggleObjectBoxEnabled,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _isUsingObjectBox
                  ? 'Using ObjectBox for efficient local database storage'
                  : 'Using JSON file for basic storage',
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
                  'Cloud Sync',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Cloud Sync'),
            subtitle: const Text('Sync tags and preferences to the cloud'),
            value: _isCloudSyncEnabled,
            onChanged: _isUsingObjectBox ? _toggleCloudSyncEnabled : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _isUsingObjectBox
                  ? (_isCloudSyncEnabled
                      ? 'Tags and preferences will be synced to the cloud'
                      : 'Cloud sync is disabled')
                  : 'Enable ObjectBox database to use cloud sync',
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
                  label: const Text('Sync to Cloud'),
                  onPressed:
                      _isCloudSyncEnabled && !_isSyncing ? _syncToCloud : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Sync from Cloud'),
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
                  'Database Statistics',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Total unique tags'),
            trailing: Text(
              '$_totalTagCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('Tagged files'),
            trailing: Text(
              '$_totalFileCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Most Popular Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _popularTags.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No tags found')),
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
                label: const Text('Refresh Statistics'),
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
