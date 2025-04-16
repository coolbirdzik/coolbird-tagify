import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';

/// Thanh tìm kiếm nằm trực tiếp trên thanh công cụ
class SearchBar extends StatefulWidget {
  final String currentPath;
  final VoidCallback onCloseSearch;

  const SearchBar({
    Key? key,
    required this.currentPath,
    required this.onCloseSearch,
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchingTags = false;
  List<String> _suggestedTags = [];
  bool _isGlobalSearch = false;

  // Overlay entry for tag suggestions
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // Tự động focus vào trường tìm kiếm khi hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        _removeOverlay();
      }
    });

    // Tải các tag phổ biến
    _loadPopularTags();
  }

  Future<void> _loadPopularTags() async {
    try {
      final popularTags = await TagManager.instance.getPopularTags(limit: 10);
      setState(() {
        _suggestedTags = popularTags.keys.toList();
      });
    } catch (e) {
      print('Error loading popular tags: $e');
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    // Kiểm tra xem có đang tìm kiếm theo tag không
    if (query.contains('#')) {
      final int hashPosition = query.lastIndexOf('#');
      final String tagQuery = query.substring(hashPosition + 1).trim();

      if (_searchFocusNode.hasFocus) {
        // Hiển thị gợi ý tag nếu đang sau ký tự #
        _updateTagSuggestions(tagQuery);
      }

      setState(() {
        _isSearchingTags = true;
      });
    } else {
      // Đóng overlay gợi ý tag nếu không tìm kiếm theo tag
      _removeOverlay();
      setState(() {
        _isSearchingTags = false;
      });
    }
  }

  Future<void> _updateTagSuggestions(String tagQuery) async {
    if (tagQuery.isEmpty) {
      // Hiển thị các tag phổ biến
      _showOverlay(_suggestedTags);
    } else {
      // Tìm kiếm tag phù hợp với query
      final matchingTags = await TagManager.instance.searchTags(tagQuery);
      _showOverlay(matchingTags);
    }
  }

  void _showOverlay(List<String> tags) {
    if (tags.isEmpty) {
      _removeOverlay();
      return;
    }

    _removeOverlay();

    // Lấy vị trí của trường tìm kiếm để định vị overlay
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tạo và chèn overlay
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + size.height - 8,
        left: position.dx + 8,
        width: size.width - 16,
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Tags gợi ý',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Flexible(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Chèn tag vào truy vấn tìm kiếm
                            final text = _searchController.text;
                            final hashIndex = text.lastIndexOf('#');
                            final newText =
                                text.substring(0, hashIndex + 1) + tags[index];
                            _searchController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                  offset: newText.length),
                            );
                            _removeOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Icon(
                                Icons.local_offer,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                tags[index],
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              trailing: Icon(
                                Icons.add_circle_outline,
                                size: 16,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (tags.length > 5) ...[
                  const Divider(height: 1, thickness: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      '${tags.length} kết quả',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    final folderListBloc = BlocProvider.of<FolderListBloc>(context);
    print('Performing search with query: "$query"');

    // Kiểm tra xem có đang tìm kiếm theo tag không
    if (query.contains('#')) {
      final int hashPosition = query.lastIndexOf('#');
      String tagQuery = query.substring(hashPosition + 1).trim();

      print('Detected tag search. Tag query: "$tagQuery"');

      // Xóa cache để đảm bảo dữ liệu mới nhất
      TagManager.clearCache();

      if (tagQuery.isNotEmpty) {
        // Thông báo trạng thái tìm kiếm
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGlobalSearch
                ? 'Đang tìm kiếm tag "$tagQuery" trên toàn hệ thống...'
                : 'Đang tìm kiếm tag "$tagQuery" trong thư mục hiện tại...'),
            duration: const Duration(seconds: 1),
          ),
        );

        if (_isGlobalSearch) {
          print('Searching for tag globally: "$tagQuery"');
          folderListBloc.add(SearchByTagGlobally(tagQuery));
        } else {
          print('Searching for tag in current directory: "$tagQuery"');
          folderListBloc.add(SearchByTag(tagQuery));
        }
      }
    } else {
      // Tìm kiếm theo tên file
      print('Searching by filename: "$query"');
      folderListBloc.add(SearchByFileName(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isSearchingTags
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Animated icon that changes between search and tag
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _isSearchingTags
                ? Icon(
                    Icons.local_offer,
                    key: const ValueKey('tagIcon'),
                    color: theme.colorScheme.primary,
                  )
                : Icon(
                    Icons.search,
                    key: const ValueKey('searchIcon'),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: _isSearchingTags
                    ? 'Tìm theo tag... (ví dụ: #important)'
                    : 'Tìm kiếm tệp hoặc dùng # để tìm theo tag',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          // Global search toggle button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _isGlobalSearch = !_isGlobalSearch;
                });
                // Hiển thị snackbar ngắn khi chuyển chế độ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isGlobalSearch
                        ? 'Đã chuyển sang tìm kiếm toàn cục'
                        : 'Đã chuyển sang tìm kiếm thư mục hiện tại'),
                    duration: const Duration(milliseconds: 1000),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(8),
                  ),
                );
              },
              child: Tooltip(
                message: _isGlobalSearch
                    ? 'Đang tìm kiếm toàn cục (nhấn để chuyển)'
                    : 'Đang tìm kiếm thư mục hiện tại (nhấn để chuyển)',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isGlobalSearch
                        ? Icon(
                            Icons.public,
                            key: const ValueKey('globalIcon'),
                            color: theme.colorScheme.primary,
                            size: 20,
                          )
                        : Icon(
                            Icons.folder,
                            key: const ValueKey('folderIcon'),
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
            ),
          ),
          // Search button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _performSearch,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.search,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          // Close button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onCloseSearch,
              child: Tooltip(
                message: 'Đóng',
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
