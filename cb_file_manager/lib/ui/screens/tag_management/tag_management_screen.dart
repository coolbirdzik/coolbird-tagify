import 'dart:io';

// ignore: unused_import
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';
import 'package:cb_file_manager/models/database/database_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/file_details_screen.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as pathlib;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/tab_data.dart';
import 'package:cb_file_manager/config/languages/app_localizations.dart';

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
  // Database manager instance
  final DatabaseManager _database = DatabaseManager.getInstance();
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
    } finally {
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

  // Modified selection method to support tab integration
  Future<void> _selectTag(String tag) async {
    // Check if we have an onTagSelected callback from the parent
    if (widget.onTagSelected != null) {
      // Call the callback to open in a new tab
      widget.onTagSelected!(tag);
    } else {
      // Fall back to the direct search if no callback is provided
      await _directTagSearch(tag);
    }
  }

  // Phương thức tìm kiếm tag trực tiếp - đã được chứng minh hoạt động tốt
  Future<void> _directTagSearch(String tag) async {
    // When in a tab environment, prefer opening a new tab for tag search
    final bool isInTabContext =
        context.findAncestorWidgetOfExactType<BlocProvider<TabManagerBloc>>() !=
            null;

    if (isInTabContext) {
      // Use the tab system for search instead of loading directly in this screen
      _openTagSearchInNewTab(tag);
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedTag = tag;
      _filesBySelectedTag = [];
    });

    try {
      // Hiển thị thông báo đang tìm kiếm
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tìm kiếm trực tiếp các file có tag "$tag"...'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Xóa cache để đảm bảo kết quả mới nhất
      TagManager.clearCache();

      // Kết hợp cả hai nguồn dữ liệu để đảm bảo có kết quả
      final fileInfoList = <Map<String, dynamic>>[];

      // 1. Try TagManager first
      try {
        final results = await TagManager.findFilesByTagGlobally(tag);

        // Process results from TagManager
        for (var entity in results) {
          if (entity is File) {
            try {
              final path = entity.path;
              // Use synchronous check for simplicity and to avoid too many async operations
              if (entity.existsSync()) {
                fileInfoList.add({
                  'path': path,
                  'name': pathlib.basename(path),
                });
              }
            } catch (e) {
              // Just log errors and continue
            }
          }
        }
      } catch (e) {}

      // 2. Try database directly
      try {
        final taggedFiles = await _database.findFilesByTag(tag);

        for (var path in taggedFiles) {
          // Skip if we already have this path from TagManager
          if (fileInfoList.any((item) => item['path'] == path)) {
            continue;
          }

          try {
            final file = File(path);
            // Use synchronous check for consistency
            if (file.existsSync()) {
              fileInfoList.add({
                'path': path,
                'name': pathlib.basename(path),
              });
            }
          } catch (e) {
            // Just log errors and continue
          }
        }
      } catch (e) {}

      // Log detailed file info list for debugging
      // Cập nhật UI
      if (mounted) {
        setState(() {
          _filesBySelectedTag = List.from(
              fileInfoList); // Create a new list to ensure state update
          _isLoading = false;
        });

        // Hiển thị thông báo kết quả
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Tìm thấy ${fileInfoList.length} file với tag "$tag"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tìm kiếm: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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

  // Opens a global search in a new tab via the TabManager
  void _openTagSearchInNewTab(String tag) {
    try {
      // Get the TabManagerBloc
      final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);

      // Create a unique path for this tag search
      final tagSearchPath = '#tag:$tag';

      // Check if a tab with this tag search already exists
      final existingTab = tabManagerBloc.state.tabs.firstWhere(
        (tab) => tab.path == tagSearchPath,
        orElse: () => TabData(id: '', name: '', path: ''),
      );

      if (existingTab.id.isNotEmpty) {
        // If the tab exists, switch to it
        tabManagerBloc.add(SwitchToTab(existingTab.id));
      } else {
        // Otherwise, create a new tab
        tabManagerBloc.add(
          AddTab(
            path: tagSearchPath,
            name: 'Tag: $tag',
            switchToTab: true,
          ),
        );
      }
    } catch (e) {
      // Handle error if the TabManagerBloc is not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening tag in new tab: $e'),
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
        title: Text(localizations.deleteTagConfirmation.replaceAll('%s', tag)),
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
          SnackBar(
              content: Text(localizations.tagDeleted.replaceAll('%s', tag))),
        );
      }

      // Remove tag color
      await _tagColorManager.removeTagColor(tag);

      // Clear the selected tag if it was deleted
      if (_selectedTag == tag) {
        _clearTagSelection();
      }
    } catch (e) {
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
          title: Text(localizations.chooseTagColor.replaceAll('%s', tag)),
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
              child: Text(localizations.cancel),
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
                      content: Text(
                          localizations.tagColorUpdated.replaceAll('%s', tag)),
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

  Future<void> _showAboutDialog(BuildContext context) async {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.aboutTags),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.aboutTagsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(localizations.aboutTagsDescription),
            const SizedBox(height: 16),
            Text(
              localizations.aboutTagsScreenDescription,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(localizations.aboutTagsScreenDescription),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.close.toUpperCase()),
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
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    // Check if we're in a tab environment
    final bool isInTabContext =
        context.findAncestorWidgetOfExactType<BlocProvider<TabManagerBloc>>() !=
            null;

    // Create appropriate title
    String title;
    if (_selectedTag != null) {
      title = localizations.filesWithTag.replaceAll('%s', _selectedTag!);
    } else if (widget.startingDirectory.isNotEmpty) {
      final dirName = pathlib.basename(widget.startingDirectory);
      title = localizations.tagsInDirectory.replaceAll('%s', dirName);
    } else {
      title = localizations.allTags;
    }

    return BaseScreen(
      title: title,
      actions: [
        // Show search icon
        IconButton(
          icon: Icon(_isSearching ? Icons.search_off : Icons.search),
          onPressed: _toggleSearch,
          tooltip: localizations.search,
        ),
        // Show about icon
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showAboutDialog(context),
          tooltip: localizations.aboutTags,
        ),
        // Show sort menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: localizations.sort,
          onSelected: (value) {
            setState(() {
              if (_sortCriteria == value) {
                // Toggle sort direction
                _sortAscending = !_sortAscending;
              } else {
                // Change sort criteria
                _sortCriteria = value;
                _sortAscending = true;
              }
              _sortTags();
              _updatePagination();
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'name',
              child: Row(
                children: [
                  Icon(
                    _sortCriteria == 'name'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.sort_by_alpha,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(localizations.sortByName),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'popularity',
              child: Row(
                children: [
                  Icon(
                    _sortCriteria == 'popularity'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.trending_up,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(localizations.sortByPopularity),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'recent',
              child: Row(
                children: [
                  Icon(
                    _sortCriteria == 'recent'
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.history,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(localizations.sortByRecent),
                ],
              ),
            ),
          ],
        ),
        // Show delete button if a tag is selected
        if (_selectedTag != null)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDeleteTag(_selectedTag!),
            tooltip: localizations.deleteTag,
          ),
      ],
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
                      hintText: 'Tìm kiếm thẻ...',
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

  void _showTagOptions(String tag) {
    // Check if we're in a tab environment
    final bool isInTabContext =
        context.findAncestorWidgetOfExactType<BlocProvider<TabManagerBloc>>() !=
            null;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('Thay đổi màu sắc'),
                onTap: () {
                  Navigator.pop(context);
                  _showColorPickerDialog(tag);
                },
              ),
              // Only show the "Open in New Tab" option if we're in a tab context
              if (isInTabContext && widget.onTagSelected == null)
                ListTile(
                  leading: const Icon(Icons.tab),
                  title: const Text('Mở trong tab mới'),
                  onTap: () {
                    Navigator.pop(context);
                    _openTagSearchInNewTab(tag);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Xóa thẻ', style: TextStyle(color: Colors.red)),
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
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Không tìm thấy thẻ nào',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Các thẻ được thêm vào tệp sẽ xuất hiện ở đây',
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
              'Không có thẻ nào phù hợp với "${_searchController.text}"',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear, size: 20),
              label: const Text('Xóa tìm kiếm', style: TextStyle(fontSize: 16)),
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
                        'Tất cả thẻ (${_filteredTags.length})',
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
                          tooltip: 'Sắp xếp thẻ',
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
                                  'Sắp xếp',
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
                                    'Theo bảng chữ cái',
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
                                    'Theo phổ biến',
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
                                    'Sử dụng gần đây',
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
                    'Nhấn vào thẻ để xem tất cả tệp có gắn thẻ đó. Nhấn giữ để hiện thêm tùy chọn.',
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
                      tooltip: 'Trang trước',
                    ),
                    Text(
                      'Trang ${_currentPage + 1} / $_totalPages',
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
                      tooltip: 'Trang sau',
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
                      tooltip: 'Trang đầu',
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_before),
                      iconSize: 22,
                      onPressed: _currentPage > 0 ? _previousPage : null,
                      tooltip: 'Trang trước',
                    ),
                    ..._buildPageIndicators(),
                    IconButton(
                      icon: const Icon(Icons.navigate_next),
                      iconSize: 22,
                      onPressed:
                          _currentPage < _totalPages - 1 ? _nextPage : null,
                      tooltip: 'Trang sau',
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      iconSize: 22,
                      onPressed: _currentPage < _totalPages - 1
                          ? () => _goToPage(_totalPages - 1)
                          : null,
                      tooltip: 'Trang cuối',
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

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Card(
            elevation: 3,
            shadowColor: isDarkMode ? Colors.black54 : Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: tagColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: GestureDetector(
              onSecondaryTap: () => _showTagOptions(tag),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _directTagSearch(tag),
                onLongPress: () => _showTagOptions(tag),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
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
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
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
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            onPressed: () => _showColorPickerDialog(tag),
                            tooltip: 'Thay đổi màu thẻ',
                            splashRadius: 24,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 22, // Larger icon
                              color: Colors.redAccent
                                  .withOpacity(isDarkMode ? 0.8 : 0.7),
                            ),
                            onPressed: () => _confirmDeleteTag(tag),
                            tooltip: 'Xóa thẻ này khỏi tất cả tệp',
                            splashRadius: 24,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              'Không tìm thấy tệp nào có thẻ này',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'Thông tin gỡ lỗi: đang tìm thẻ "${_selectedTag ?? 'none'}"',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back,
                      size: 22, color: Colors.white),
                  label: const Text('Quay về tất cả thẻ',
                      style: TextStyle(
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
                  label: const Text('Thử lại',
                      style: TextStyle(
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back,
                          size: 22, color: Colors.white),
                      label: const Text('Quay về tất cả thẻ',
                          style: TextStyle(
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
                        label: const Text(
                          'Thay đổi màu',
                          style: TextStyle(
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
                        '${_filesBySelectedTag.length} ${_filesBySelectedTag.length == 1 ? 'tệp' : 'tệp'}',
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
                                    .withOpacity(0.2)
                                : Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1),
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
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Theme.of(context).primaryColor.withOpacity(0.05),
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
                title: const Text('Xem chi tiết'),
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
                title: const Text('Mở thư mục chứa'),
                onTap: () {
                  Navigator.pop(context);
                  final directory = pathlib.dirname(filePath);
                  _openContainingFolder(directory);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Chỉnh sửa thẻ'),
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

  // Mở thư mục chứa tệp tin
  void _openContainingFolder(String folderPath) {
    // Kiểm tra xem thư mục có tồn tại không
    if (Directory(folderPath).existsSync()) {
      try {
        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening folder: $folderPath')),
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
          Navigator.of(context).pop();
        }
      } catch (e) {}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder not found: $folderPath')),
      );
    }
  }
}
