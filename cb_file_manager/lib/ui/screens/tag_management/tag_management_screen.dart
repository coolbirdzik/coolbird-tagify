import 'dart:io';

import 'package:cb_file_manager/helpers/tags/tag_manager.dart';
import 'package:cb_file_manager/helpers/tags/tag_color_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as pathlib;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/core/tab_data.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/core/uri_utils.dart';
import '../../utils/route.dart';
import '../../widgets/debug_tags_widget.dart';

class TagManagementScreen extends StatefulWidget {
  final String startingDirectory;

  /// Callback when a tag is selected, used for opening in a new tab
  final Function(String)? onTagSelected;

  const TagManagementScreen({
    Key? key,
    this.startingDirectory = '',
    this.onTagSelected,
  }) : super(key: key);

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  // Tag manager instance
  // User preferences singleton instance
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
  int _tagsPerPage = 60; // Increased from 40 to 60 as default
  int _totalPages = 0;
  List<String> _currentPageTags = [];

  // Sorting options
  String _sortCriteria = 'name'; // 'name', 'popularity', 'recent'
  bool _sortAscending = true;

  // View mode options
  bool _isGridView = false; // false = list view, true = grid view

  @override
  void initState() {
    super.initState();
    // Initialize database and preferences
    _initializeDatabase();

    // Initialize tag color manager
    _tagColorManager = TagColorManager.instance;
    _initTagColorManager();

    // Set default view mode based on device type after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultViewMode();
    });

    // Add listener to search controller
    _searchController.addListener(_filterTags);
  }

  // Set default view mode based on device type
  void _setDefaultViewMode() {
    if (!mounted) return;

    // Check if device is tablet/desktop (screen width > 600)
    final screenWidth = MediaQuery.of(context).size.width;
    _isGridView = screenWidth > 600; // Desktop/tablet = grid, mobile = list
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
      // Initialize TagManager to ensure it's using the correct storage
      await TagManager.initialize();

      // Get all unique tags using TagManager (which handles both ObjectBox and JSON)
      final Set<String> tags = await TagManager.getAllUniqueTags("");
      debugPrint(
          'TagManagementScreen: Found ${tags.length} unique tags: $tags');

      if (mounted) {
        setState(() {
          _allTags = tags.toList();
          // Sort tags alphabetically by default
          _allTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _filterTags();
        });
      }
    } catch (e) {
      debugPrint('TagManagementScreen: Error loading tags: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.errorLoadingTags}$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Only clear tags on error
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
    debugPrint('TagManagementScreen: Filtering tags with query: "$query"');
    debugPrint('TagManagementScreen: _allTags count: ${_allTags.length}');

    setState(() {
      if (query.isEmpty) {
        _filteredTags = List.from(_allTags);
      } else {
        _filteredTags =
            _allTags.where((tag) => tag.toLowerCase().contains(query)).toList();
      }

      debugPrint(
          'TagManagementScreen: _filteredTags count: ${_filteredTags.length}');

      // Apply sorting
      _sortTags();

      // Update pagination
      _updatePagination();

      debugPrint(
          'TagManagementScreen: _currentPageTags count: ${_currentPageTags.length}');
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
    // Dynamically calculate tags per page based on screen height
    final screenHeight = MediaQuery.of(context).size.height;
    // Calculate how many tags can fit (assuming approximately 40 pixels per tag instead of 70)
    _tagsPerPage = (screenHeight ~/ 40).clamp(40, 200);

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

    debugPrint(
        'TagManagementScreen: Pagination - _filteredTags: ${_filteredTags.length}, _tagsPerPage: $_tagsPerPage, _totalPages: $_totalPages, _currentPage: $_currentPage, _currentPageTags: ${_currentPageTags.length}');
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

  Future<void> _handleTagTap(String tag) async {
    final onTagSelected = widget.onTagSelected;
    if (onTagSelected != null) {
      onTagSelected(tag);
      return;
    }

    await _directTagSearch(tag);
  }

  // Phương thức tìm kiếm tag trực tiếp - mở giao diện duyệt file với filter
  Future<void> _directTagSearch(String tag) async {
    try {
      // Get the TabManagerBloc
      final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);

      final tagSearchPath = UriUtils.buildTagSearchPath(tag);

      // Check if a tab with this tag search already exists
      final existingTab = tabManagerBloc.state.tabs.firstWhere(
        (tab) => tab.path == tagSearchPath,
        orElse: () => TabData(id: '', name: '', path: ''),
      );

      if (existingTab.id.isNotEmpty) {
        // If the tab exists, switch to it
        tabManagerBloc.add(SwitchToTab(existingTab.id));

        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển đến tab tìm kiếm tag "$tag"'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Otherwise, create a new tab with timeout protection
        tabManagerBloc.add(
          AddTab(
            path: tagSearchPath,
            name: 'Tag: $tag',
            switchToTab: true,
          ),
        );

        // Show loading message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đang mở giao diện duyệt file với tag "$tag"...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle error if the TabManagerBloc is not found
      debugPrint('Error opening tag in new tab: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi mở tab tìm kiếm: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Clear tag selection and return to tag list
  void _clearTagSelection() {
    setState(() {
      _selectedTag = null;
      _filesBySelectedTag = [];
    });
  }

  // Show confirm dialog before deleting a tag
  Future<void> _confirmDeleteTag(String tag) async {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final bool result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteTagConfirmation(tag)),
        content: Text(
          localizations.tagDeleteConfirmationText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.delete.toUpperCase(),
                style: const TextStyle(color: Colors.red)),
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
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });

    try {
      // Use TagManager to delete the tag from all files
      await TagManager.deleteTagGlobally(tag);

      await _loadAllTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.tagDeleted(tag))),
        );
      }

      // Remove tag color
      await _tagColorManager.removeTagColor(tag);

      // Clear the selected tag if it was deleted
      if (_selectedTag == tag) {
        _clearTagSelection();
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
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    // Màu hiện tại của tag hoặc màu mặc định
    Color currentColor = _tagColorManager.getTagColor(tag);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.chooseTagColor(tag)),
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
                RouteUtils.safePopDialog(context);
              },
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                // Lưu màu mới
                await _tagColorManager.setTagColor(tag, currentColor);
                if (mounted) {
                  // Rebuild UI
                  setState(() {});
                  RouteUtils.safePopDialog(context);

                  // Thông báo thành công
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.tagColorUpdated(tag)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tagManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugTagsWidget(),
                ),
              );
            },
            tooltip: AppLocalizations.of(context)!.debugTags,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
            tooltip: AppLocalizations.of(context)!.searchTags,
          ),
        ],
      ),
      body: _isSearching
          ? Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchTagsHint,
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
            )
          : _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : _selectedTag == null
                  ? _buildTagsList()
                  : _buildFilesByTagList(),
      floatingActionButton: _selectedTag == null
          ? FloatingActionButton(
              heroTag: null, // Disable hero animation to avoid conflicts
              onPressed: _showCreateTagDialog,
              backgroundColor: Theme.of(context).primaryColor,
              tooltip: AppLocalizations.of(context)!.newTagTooltip,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
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
                title: Text(AppLocalizations.of(context)!.changeTagColor),
                onTap: () {
                  Navigator.pop(context);
                  _showColorPickerDialog(tag);
                },
              ),
              // Only show the "Open in New Tab" option if we're in a tab context
              if (widget.onTagSelected == null)
                ListTile(
                  leading: const Icon(Icons.tab),
                  title: Text(AppLocalizations.of(context)!.openInNewTab),
                  onTap: () {
                    Navigator.pop(context);
                    _directTagSearch(tag);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(AppLocalizations.of(context)!.deleteTag,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteTag(tag);
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
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTagsFoundMessage,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noTagsFoundDescription,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateTagDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.createNewTagButton),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
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
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!
                  .noMatchingTagsMessage(_searchController.text),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear, size: 20),
              label: Text(AppLocalizations.of(context)!.clearSearch,
                  style: const TextStyle(fontSize: 16)),
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
            // Top section with stats and sorting options - Modern design without border
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.sell_outlined,
                          size: 24,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.tagManagementHeader,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_filteredTags.length} ${AppLocalizations.of(context)!.tagsCreated}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Only show sort and view mode buttons on desktop/tablet
                      if (MediaQuery.of(context).size.width > 600) ...[
                        const SizedBox(width: 12),
                        // Sort dropdown - Modern style
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[800]?.withValues(alpha: 0.6)
                                : Colors.grey[100]?.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: AppLocalizations.of(context)!.sortTags,
                            onSelected: _changeSortCriteria,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sort_rounded,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context)!.sortTags,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
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
                                    Text(
                                      AppLocalizations.of(context)!
                                          .sortByAlphabet,
                                      style: const TextStyle(fontSize: 16),
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
                                    Text(
                                      AppLocalizations.of(context)!
                                          .sortByPopular,
                                      style: const TextStyle(fontSize: 16),
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
                                    Text(
                                      AppLocalizations.of(context)!
                                          .sortByRecent,
                                      style: const TextStyle(fontSize: 16),
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
                        const SizedBox(width: 12),
                        // View mode toggle button
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[800]?.withValues(alpha: 0.6)
                                : Colors.grey[100]?.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _isGridView = !_isGridView;
                              });
                            },
                            icon: Icon(
                              _isGridView
                                  ? Icons.view_list_rounded
                                  : Icons.grid_view_rounded,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                              size: 20,
                            ),
                            tooltip: _isGridView
                                ? AppLocalizations.of(context)!.listViewMode
                                : AppLocalizations.of(context)!.gridViewMode,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.tagManagementDescription,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
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
                      tooltip: AppLocalizations.of(context)!.previousPage,
                    ),
                    Text(
                      '${AppLocalizations.of(context)!.page} ${_currentPage + 1} / $_totalPages',
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
                      tooltip: AppLocalizations.of(context)!.nextPage,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Tags list or grid
            Expanded(
              child: _isGridView ? _buildTagsGridView() : _buildTagsListView(),
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
                      color: Colors.black.withValues(alpha: 0.05),
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
                      tooltip: AppLocalizations.of(context)!.firstPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_before),
                      iconSize: 22,
                      onPressed: _currentPage > 0 ? _previousPage : null,
                      tooltip: AppLocalizations.of(context)!.previousPage,
                    ),
                    ..._buildPageIndicators(),
                    IconButton(
                      icon: const Icon(Icons.navigate_next),
                      iconSize: 22,
                      onPressed:
                          _currentPage < _totalPages - 1 ? _nextPage : null,
                      tooltip: AppLocalizations.of(context)!.nextPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      iconSize: 22,
                      onPressed: _currentPage < _totalPages - 1
                          ? () => _goToPage(_totalPages - 1)
                          : null,
                      tooltip: AppLocalizations.of(context)!.lastPage,
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

  Widget _buildTagsListView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    debugPrint(
        'TagManagementScreen: _buildTagsListView - _currentPageTags.length: ${_currentPageTags.length}');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _currentPageTags.length,
      itemBuilder: (context, index) {
        final tag = _currentPageTags[index];
        // Get current tag color
        final tagColor = TagColorManager.instance.getTagColor(tag);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleTagTap(tag),
              onLongPress: () => _showTagOptions(tag),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]?.withValues(alpha: 0.6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tagColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Color indicator
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tagColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tagColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Tag info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.clickToViewFiles,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
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
                            size: 24,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                          onPressed: () => _showColorPickerDialog(tag),
                          tooltip: AppLocalizations.of(context)!.changeTagColor,
                          splashRadius: 24,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 24,
                            color: Colors.redAccent
                                .withValues(alpha: isDarkMode ? 0.8 : 0.7),
                          ),
                          onPressed: () => _confirmDeleteTag(tag),
                          tooltip: AppLocalizations.of(context)!
                              .deleteTagFromAllFiles,
                          splashRadius: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagsGridView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    debugPrint(
        'TagManagementScreen: _buildTagsGridView - _currentPageTags.length: ${_currentPageTags.length}');

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth > 1200
            ? 8
            : screenWidth > 900
                ? 6
                : screenWidth > 600
                    ? 5
                    : 3,
        childAspectRatio: 1.8, // Tăng tỷ lệ để làm item thấp hơn, nhỏ gọn hơn
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _currentPageTags.length,
      itemBuilder: (context, index) {
        final tag = _currentPageTags[index];
        final tagColor = TagColorManager.instance.getTagColor(tag);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleTagTap(tag),
            onLongPress: () => _showTagOptions(tag),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[800]?.withValues(alpha: 0.6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tagColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Color indicator
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tagColor.withValues(alpha: 0.5),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Tag name
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.color_lens_outlined,
                          size: 16,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => _showColorPickerDialog(tag),
                        tooltip: AppLocalizations.of(context)!.changeColor,
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.redAccent
                              .withValues(alpha: isDarkMode ? 0.8 : 0.7),
                        ),
                        onPressed: () => _confirmDeleteTag(tag),
                        tooltip: AppLocalizations.of(context)!.deleteTag,
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
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
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noFilesWithTag,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.debugInfo(_selectedTag ?? 'none'),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back,
                      size: 22, color: Colors.white),
                  label: Text(AppLocalizations.of(context)!.backToAllTags,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _clearTagSelection,
                ),
                const SizedBox(width: 16),
                // Thêm nút tìm kiếm trực tiếp
                ElevatedButton.icon(
                  icon:
                      const Icon(Icons.refresh, size: 22, color: Colors.white),
                  label: Text(AppLocalizations.of(context)!.tryAgain,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _selectedTag != null
                      ? () => _directTagSearch(_selectedTag!)
                      : null,
                ),
              ],
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
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back,
                          size: 22, color: Colors.white),
                      label: Text(AppLocalizations.of(context)!.backToAllTags,
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _clearTagSelection,
                    ),
                    const Spacer(),
                    // Add button to change color for selected tag
                    if (_selectedTag != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.color_lens,
                            size: 20, color: Colors.white),
                        label: Text(
                          AppLocalizations.of(context)!.changeColor,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
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
                        '${_filesBySelectedTag.length} ${AppLocalizations.of(context)!.filesWithTagCount}',
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

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onSecondaryTap: () => _showFileOptions(path),
                    child: Card(
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Hiển thị menu tùy chọn khi nhấp chuột phải vào tệp
  void _showFileOptions(String filePath) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final File file = File(filePath);
    final String fileName = pathlib.basename(filePath);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: isDarkMode
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.05),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filePath,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(AppLocalizations.of(context)!.viewDetails),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsScreen(
                        file: file,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(AppLocalizations.of(context)!.openContainingFolder),
                onTap: () {
                  Navigator.pop(context);
                  final directory = pathlib.dirname(filePath);
                  _openContainingFolder(directory);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(AppLocalizations.of(context)!.editTags),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileDetailsScreen(
                        file: file,
                        initialTab: 1, // Giả sử tab 1 là tab Tags
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Thêm thẻ mới
  Future<void> _showCreateTagDialog() async {
    final TextEditingController tagController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.newTagTitle),
          content: TextField(
            controller: tagController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterTagName,
              prefixIcon: const Icon(Icons.tag),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _createNewTag(value.trim());
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.create),
              onPressed: () {
                final tagName = tagController.text.trim();
                if (tagName.isNotEmpty) {
                  Navigator.of(context).pop();
                  _createNewTag(tagName);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Tạo thẻ mới trong database
  Future<void> _createNewTag(String tagName) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Kiểm tra xem thẻ đã tồn tại chưa
      if (_allTags.contains(tagName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.tagAlreadyExists(tagName)),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Tạo một file tạm để thêm thẻ vào database
      // (vì database cần có file để liên kết với thẻ)
      final tempFilePath =
          '/temp/tag_creation_placeholder_${DateTime.now().millisecondsSinceEpoch}';

      // Thêm thẻ vào database với file tạm sử dụng TagManager
      await TagManager.addTag(tempFilePath, tagName);

      // Xóa file tạm khỏi database (chỉ giữ lại thẻ)
      // Điều này sẽ để lại thẻ trong database mà không liên kết với file nào
      await TagManager.removeTag(tempFilePath, tagName);

      // Load lại danh sách thẻ
      await _loadAllTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.tagCreatedSuccessfully(tagName)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating tag: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.errorCreatingTag}$e'),
            backgroundColor: Colors.red,
          ),
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

  // Mở thư mục chứa tệp tin
  void _openContainingFolder(String folderPath) {
    // Kiểm tra xem thư mục có tồn tại không
    if (Directory(folderPath).existsSync()) {
      try {
        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.openingFolder}$folderPath')),
        );

        // Nếu trong môi trường tab, thêm tab mới hoặc chuyển đến tab đã mở
        final bool isInTabContext = context.findAncestorWidgetOfExactType<
                BlocProvider<TabManagerBloc>>() !=
            null;

        if (isInTabContext) {
          try {
            // Lấy TabManagerBloc
            final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);

            // Kiểm tra xem đã có tab này chưa
            final existingTab = tabManagerBloc.state.tabs.firstWhere(
              (tab) => tab.path == folderPath,
              orElse: () => TabData(id: '', name: '', path: ''),
            );

            if (existingTab.id.isNotEmpty) {
              // Nếu tab đã tồn tại, chuyển đến tab đó
              tabManagerBloc.add(SwitchToTab(existingTab.id));
            } else {
              // Nếu chưa có, tạo tab mới
              final folderName = pathlib.basename(folderPath);
              tabManagerBloc.add(
                AddTab(
                  path: folderPath,
                  name: folderName,
                  switchToTab: true,
                ),
              );
            }
          } catch (e) {}
        } else {
          // Xử lý khi không trong môi trường tab
          // Điều này phụ thuộc vào cách ứng dụng của bạn điều hướng
          // Ví dụ: bạn có thể pop màn hình hiện tại và mở thư mục
          RouteUtils.safePopDialog(context);
        }
      } catch (e) {}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${AppLocalizations.of(context)!.folderNotFound}$folderPath')),
      );
    }
  }
}
