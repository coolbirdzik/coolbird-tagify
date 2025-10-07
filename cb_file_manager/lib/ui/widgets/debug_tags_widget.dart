import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/helpers/core/user_preferences.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';

class DebugTagsWidget extends StatefulWidget {
  const DebugTagsWidget({Key? key}) : super(key: key);

  @override
  State<DebugTagsWidget> createState() => _DebugTagsWidgetState();
}

class _DebugTagsWidgetState extends State<DebugTagsWidget> {
  bool _isLoading = true;
  String _debugInfo = '';
  Set<String> _allTags = {};
  Map<String, int> _popularTags = {};
  bool _useObjectBox = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize preferences
      final preferences = UserPreferences.instance;
      await preferences.init();
      _useObjectBox = preferences.isUsingObjectBox();

      // Initialize TagManager
      await TagManager.initialize();

      // Get all unique tags
      final allTags = await TagManager.getAllUniqueTags("");
      _allTags = allTags;

      // Get popular tags
      final popularTags = await TagManager.instance.getPopularTags(limit: 10);
      _popularTags = popularTags;

      // Check database manager
      final dbManager = DatabaseManager.getInstance();
      await dbManager.initialize();
      final dbTags = await dbManager.getAllUniqueTags();

      setState(() {
        _debugInfo = '''
=== DEBUG TAGS SYSTEM ===
ObjectBox enabled: $_useObjectBox
Total unique tags found: ${allTags.length}
Database tags: ${dbTags.length}
Popular tags: ${popularTags.length}

All Tags: $allTags
Database Tags: $dbTags
Popular Tags: $popularTags
''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e\nStack trace: ${StackTrace.current}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Information',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _debugInfo,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Tags (${_allTags.length})',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          if (_allTags.isEmpty)
                            const Text('No tags found')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allTags
                                  .map((tag) => Chip(
                                        label: Text(tag),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popular Tags (${_popularTags.length})',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          if (_popularTags.isEmpty)
                            const Text('No popular tags found')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _popularTags.entries
                                  .map((entry) => Chip(
                                        label: Text(
                                            '${entry.key} (${entry.value})'),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.2),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}



