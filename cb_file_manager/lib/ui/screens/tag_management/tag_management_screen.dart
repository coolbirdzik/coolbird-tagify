import 'dart:io';

// ignore: unused_import
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as pathlib;

class TagManagementScreen extends StatefulWidget {
  final String startingDirectory;

  const TagManagementScreen({
    Key? key,
    this.startingDirectory = '',
  }) : super(key: key);

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  // Database manager instance
  final DatabaseManager _database = DatabaseManager.getInstance();
  // Tag manager instance
  final TagManager _tagManager = TagManager.instance;
  // User preferences singleton instance
  final UserPreferences _preferences = UserPreferences.instance;
  // Tag color manager
  late TagColorManager _tagColorManager;

  bool _isInitializing = true;
  bool _isLoading = false;
  List<String> _allTags = [];
  List<String> _filteredTags = [];
  String? _selectedTag;
  List<Map<String, dynamic>> _filesBySelectedTag = [];

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Pagination variables
  int _currentPage = 0;
  final int _tagsPerPage = 20;
  int _totalPages = 0;
  List<String> _currentPageTags = [];

  // Sorting options
  String _sortCriteria = 'name'; // 'name', 'popularity', 'recent'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    // Initialize database and preferences
    _initializeDatabase();

    // Initialize tag color manager
    _tagColorManager = TagColorManager.instance;
    _initTagColorManager();

    // Add listener to search controller
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTags);
    _searchController.dispose();
    super.dispose();
  }

  // Initialize tag color manager
  Future<void> _initTagColorManager() async {
    await _tagColorManager.initialize();
    // Rebuild UI to reflect tag colors
    if (mounted) setState(() {});
  }

  // Initialize the database and load tags
  Future<void> _initializeDatabase() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // Load all tags
      await _loadAllTags();
    } catch (e) {
      // Handle initialization error
      debugPrint('Error initializing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // Load all tags from the database
  Future<void> _loadAllTags() async {
    try {
      // Get all unique tags from the database
      final Set<String> tags = await _database.getAllUniqueTags();
      if (mounted) {
        setState(() {
          _allTags = tags.toList();
          // Sort tags alphabetically by default
          _allTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _filterTags();
        });
      }
    } catch (e) {
      debugPrint('Error loading tags: $e');
      if (mounted) {
        setState(() {
          _allTags = [];
          _filterTags();
        });
      }
    }
  }

  // Filter tags based on search query
  void _filterTags() {
    if (!mounted) return;

    final String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTags = List.from(_allTags);
      } else {
        _filteredTags =
            _allTags.where((tag) => tag.toLowerCase().contains(query)).toList();
      }

      // Apply sorting
      _sortTags();

      // Update pagination
      _updatePagination();
    });
  }

  // Sort tags based on criteria
  void _sortTags() {
    switch (_sortCriteria) {
      case 'name':
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
      case 'popularity':
        // This would need actual popularity data from database
        // For now just sort by name
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
      case 'recent':
        // This would need recent usage data from database
        // For now just sort by name
        _filteredTags.sort((a, b) {
          final result = a.toLowerCase().compareTo(b.toLowerCase());
          return _sortAscending ? result : -result;
        });
        break;
    }
  }

  // Update pagination calculation and current page content
  void _updatePagination() {
    _totalPages = (_filteredTags.length / _tagsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;

    // Make sure current page is valid
    if (_currentPage >= _totalPages) {
      _currentPage = _totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }

    // Get tags for current page
    final startIndex = _currentPage * _tagsPerPage;
    final endIndex = startIndex + _tagsPerPage;

    if (startIndex < _filteredTags.length) {
      _currentPageTags = _filteredTags.sublist(startIndex,
          endIndex > _filteredTags.length ? _filteredTags.length : endIndex);
    } else {
      _currentPageTags = [];
    }
  }

  // Change page
  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
        _updatePagination();
      });
    }
  }

  // Go to next page
  void _nextPage() {
    _goToPage(_currentPage + 1);
  }

  // Go to previous page
  void _previousPage() {
    _goToPage(_currentPage - 1);
  }

  // Change sort criteria
  void _changeSortCriteria(String criteria) {
    setState(() {
      if (_sortCriteria == criteria) {
        // Toggle sort direction if same criteria selected
        _sortAscending = !_sortAscending;
      } else {
        _sortCriteria = criteria;
        _sortAscending = true;
      }

      _sortTags();
      _updatePagination();
    });
  }

  // Select a tag to show files with that tag
  Future<void> _selectTag(String tag) async {
    setState(() {
      _isLoading = true;
      _selectedTag = tag;
      _filesBySelectedTag = [];
    });

    try {
      // Get all files with the selected tag
      final List<String> files = await _database.findFilesByTag(tag);
      List<Map<String, dynamic>> fileInfoList = [];

      // Lọc files theo startingDirectory nếu có
      List<String> filteredFiles = files;
      if (widget.startingDirectory.isNotEmpty) {
        filteredFiles = files
            .where((path) => path.startsWith(widget.startingDirectory))
            .toList();
      }

      // Convert list of paths to a list of file info maps
      for (String path in filteredFiles) {
        fileInfoList.add({
          'path': path,
          'name': pathlib.basename(path),
        });
      }

      if (mounted) {
        setState(() {
          _filesBySelectedTag = fileInfoList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  // Clear tag selection and return to tag list
  void _clearTagSelection() {
    setState(() {
      _selectedTag = null;
      _filesBySelectedTag = [];
    });
  }

  // Show confirmation dialog for deleting a tag
  Future<void> _showDeleteTagConfirmation(
      BuildContext context, String tag) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete tag "$tag"?'),
        content: const Text(
          'This will remove the tag from all files. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteTag(tag);
    }
  }

  // Delete a tag from all files
  Future<void> _deleteTag(String tag) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the tag manager to delete the tag from all files
      final files = await _database.findFilesByTag(tag);
      for (String filePath in files) {
        await TagManager.removeTag(filePath, tag);
      }

      await _loadAllTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tag "$tag" deleted successfully')),
        );
      }

      // Remove tag color
      await _tagColorManager.removeTagColor(tag);

      // Clear the selected tag if it was deleted
      if (_selectedTag == tag) {
        _clearTagSelection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting tag: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Hiển thị color picker để chọn màu cho tag
  void _showColorPickerDialog(String tag) {
    // Màu hiện tại của tag hoặc màu mặc định
    Color currentColor = _tagColorManager.getTagColor(tag);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose Color for "$tag"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hiển thị tag với màu hiện tại
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: TagChip(
                    tag: tag,
                    customColor: currentColor,
                  ),
                ),
                // Color picker
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (color) {
                    currentColor = color;
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
                  pickerAreaBorderRadius:
                      const BorderRadius.all(Radius.circular(10)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Lưu màu mới
                await _tagColorManager.setTagColor(tag, currentColor);
                if (mounted) {
                  // Rebuild UI
                  setState(() {});
                  Navigator.of(context).pop();

                  // Thông báo thành công
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Color for tag "$tag" updated'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag Management'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Tag Management:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Tags help you organize your files by adding custom labels. '
              'You can add or remove tags from files, and find all files with a specific tag.',
            ),
            SizedBox(height: 16),
            Text(
              'This screen shows:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All tags in your library\n'
                '• Files tagged with a selected tag\n'
                '• Options to delete tags'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  // Toggle search mode
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tạo tiêu đề phù hợp
    String title;
    if (_selectedTag != null) {
      title = 'Files with tag "$_selectedTag"';
    } else if (widget.startingDirectory.isNotEmpty) {
      final dirName = pathlib.basename(widget.startingDirectory);
      title = 'Tags in "$dirName"';
    } else {
      title = 'All Tags';
    }

    // Create custom actions list based on search state
    List<Widget> actionWidgets = [];

    // Add search button
    if (!_isSearching) {
      actionWidgets.add(
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
          tooltip: 'Search tags',
        ),
      );
    }

    // Add other action buttons when not searching
    if (_selectedTag != null && !_isSearching) {
      actionWidgets.add(
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _showDeleteTagConfirmation(context, _selectedTag!),
          tooltip: 'Delete this tag from all files',
        ),
      );

      actionWidgets.add(
        IconButton(
          icon: const Icon(Icons.color_lens),
          onPressed: () => _showColorPickerDialog(_selectedTag!),
          tooltip: 'Change tag color',
        ),
      );
    }

    if (!_isSearching) {
      actionWidgets.add(
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await _loadAllTags();
            if (_selectedTag != null) {
              await _selectTag(_selectedTag!);
            }
          },
          tooltip: 'Refresh',
        ),
      );

      actionWidgets.add(
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showAboutDialog(context),
          tooltip: 'About tag management',
        ),
      );
    }

    return BaseScreen(
      title: _isSearching ? 'Search Tags' : title,
      automaticallyImplyLeading: !_isSearching,
      actions: actionWidgets,
      body: Builder(
        builder: (context) {
          if (_isSearching) {
            // Show search input at the top of the body
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tags...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _toggleSearch,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).canvasColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                Expanded(
                  child: _isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : _selectedTag == null
                          ? _buildTagsList()
                          : _buildFilesByTagList(),
                ),
              ],
            );
          } else {
            return _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : _selectedTag == null
                    ? _buildTagsList()
                    : _buildFilesByTagList();
          }
        },
      ),
    );
  }

  Widget _buildTagItem(String tag) {
    return InkWell(
      onTap: () => _selectTag(tag),
      onLongPress: () => _showTagOptions(tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TagChip(
              tag: tag,
              onTap: () => _selectTag(tag),
              onDeleted: () => _showDeleteTagConfirmation(context, tag),
            ),
            IconButton(
              icon: const Icon(Icons.color_lens, size: 16),
              onPressed: () => _showColorPickerDialog(tag),
              tooltip: 'Change tag color',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagOptions(String tag) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('Change Color'),
                onTap: () {
                  Navigator.pop(context);
                  _showColorPickerDialog(tag);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Tag',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteTagConfirmation(context, tag);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];

    if (_allTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_off,
              size: 80, // Larger icon
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tags found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tags added to files will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_filteredTags.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80, // Larger icon
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No tags matching "${_searchController.text}"',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear, size: 20),
              label: const Text('Clear search', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section with stats and sorting options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Theme.of(context).primaryColor.withOpacity(0.15)
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'All Tags (${_filteredTags.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Sort dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black26
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: 'Sort tags',
                          onSelected: _changeSortCriteria,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sort',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'name',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sort_by_alpha,
                                    color: _sortCriteria == 'name'
                                        ? Theme.of(context).primaryColor
                                        : null,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Alphabetical',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  if (_sortCriteria == 'name')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        _sortAscending
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'popularity',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    color: _sortCriteria == 'popularity'
                                        ? Theme.of(context).primaryColor
                                        : null,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Popularity',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  if (_sortCriteria == 'popularity')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        _sortAscending
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'recent',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    color: _sortCriteria == 'recent'
                                        ? Theme.of(context).primaryColor
                                        : null,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Recently Used',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  if (_sortCriteria == 'recent')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        _sortAscending
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap on a tag to see all files with that tag. Long press for more options.',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),

            // Pagination info and controls
            if (_totalPages > 1)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black12 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.navigate_before),
                      iconSize: 24,
                      onPressed: _currentPage > 0 ? _previousPage : null,
                      tooltip: 'Previous page',
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_next),
                      iconSize: 24,
                      onPressed:
                          _currentPage < _totalPages - 1 ? _nextPage : null,
                      tooltip: 'Next page',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Tags grid
            Expanded(
              child: _buildTagsGrid(),
            ),

            // Bottom pagination controls
            if (_totalPages > 1)
              Container(
                margin: const EdgeInsets.only(top: 16.0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black12 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      iconSize: 22,
                      onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                      tooltip: 'First page',
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_before),
                      iconSize: 22,
                      onPressed: _currentPage > 0 ? _previousPage : null,
                      tooltip: 'Previous page',
                    ),
                    ..._buildPageIndicators(),
                    IconButton(
                      icon: const Icon(Icons.navigate_next),
                      iconSize: 22,
                      onPressed:
                          _currentPage < _totalPages - 1 ? _nextPage : null,
                      tooltip: 'Next page',
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      iconSize: 22,
                      onPressed: _currentPage < _totalPages - 1
                          ? () => _goToPage(_totalPages - 1)
                          : null,
                      tooltip: 'Last page',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build page number indicators for pagination
  List<Widget> _buildPageIndicators() {
    List<Widget> indicators = [];

    // Limit the number of page indicators shown
    int startPage = _currentPage - 2;
    int endPage = _currentPage + 2;

    if (startPage < 0) {
      endPage -= startPage; // Add more pages at the end
      startPage = 0;
    }

    if (endPage >= _totalPages) {
      startPage =
          (startPage - (endPage - _totalPages + 1)).clamp(0, _totalPages - 1);
      endPage = _totalPages - 1;
    }

    // Add ellipsis at the start if needed
    if (startPage > 0) {
      indicators.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('...', style: TextStyle(fontSize: 16)),
      ));
    }

    // Add page number buttons
    for (int i = startPage; i <= endPage; i++) {
      indicators.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => _goToPage(i),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: i == _currentPage
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      i == _currentPage ? FontWeight.bold : FontWeight.normal,
                  color: i == _currentPage ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Add ellipsis at the end if needed
    if (endPage < _totalPages - 1) {
      indicators.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('...', style: TextStyle(fontSize: 16)),
      ));
    }

    return indicators;
  }

  Widget _buildTagsGrid() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[850] : Colors.grey[100];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300, // Larger cards
        childAspectRatio: 3.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _currentPageTags.length,
      itemBuilder: (context, index) {
        final tag = _currentPageTags[index];
        // Get current tag color
        final tagColor = TagColorManager.instance.getTagColor(tag);

        return Card(
          elevation: 3,
          shadowColor: isDarkMode ? Colors.black54 : Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: tagColor.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectTag(tag),
            onLongPress: () => _showTagOptions(tag),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Color indicator dot
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: tagColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tagColor.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tag text
                        Expanded(
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 16, // Larger text
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.color_lens_outlined,
                          size: 22, // Larger icon
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => _showColorPickerDialog(tag),
                        tooltip: 'Change tag color',
                        splashRadius: 24,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 22, // Larger icon
                          color: Colors.redAccent
                              .withOpacity(isDarkMode ? 0.8 : 0.7),
                        ),
                        onPressed: () =>
                            _showDeleteTagConfirmation(context, tag),
                        tooltip: 'Delete tag',
                        splashRadius: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesByTagList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filesBySelectedTag.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.find_in_page,
              size: 80, // Larger icon
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No files found with this tag',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back, size: 22),
              label: const Text('Back to all tags',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _clearTagSelection,
            ),
          ],
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Action buttons and header
          Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Theme.of(context).primaryColor.withOpacity(0.15)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.white10 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Back to all tags',
                          style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onPressed: _clearTagSelection,
                    ),
                    const Spacer(),
                    // Add button to change color for selected tag
                    if (_selectedTag != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.color_lens, size: 20),
                        label: const Text('Change Color',
                            style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: () => _showColorPickerDialog(_selectedTag!),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Tag header with custom color
                if (_selectedTag != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: TagColorManager.instance
                              .getTagColor(_selectedTag!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _selectedTag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_filesBySelectedTag.length} ${_filesBySelectedTag.length == 1 ? 'file' : 'files'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Files list
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              itemCount: _filesBySelectedTag.length,
              itemBuilder: (context, index) {
                final file = _filesBySelectedTag[index];
                final String path = file['path'] as String;
                final String fileName = pathlib.basename(path);
                final String dirName = pathlib.dirname(path);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dirName,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FileDetailsScreen(
                            file: File(path),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
