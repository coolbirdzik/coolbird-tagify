import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/widgets/tag_chip.dart';
import 'package:cb_file_manager/widgets/chips_input.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';
import 'dart:ui' as ui;
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

/// A reusable tag management section that can be used in different places
/// like the file details screen and tag dialogs
class TagManagementSection extends StatefulWidget {
  /// The file path for which to manage tags
  final String filePath;

  /// Callback when tags have been updated
  final VoidCallback? onTagsUpdated;

  /// Whether to show recent tags section
  final bool showRecentTags;

  /// Whether to show popular tags section
  final bool showPopularTags;

  /// Whether to show the header for the file tags section
  final bool showFileTagsHeader;

  /// Initial set of tags
  final List<String>? initialTags;

  const TagManagementSection({
    Key? key,
    required this.filePath,
    this.onTagsUpdated,
    this.showRecentTags = true,
    this.showPopularTags = true,
    this.showFileTagsHeader = true,
    this.initialTags,
  }) : super(key: key);

  @override
  State<TagManagementSection> createState() => _TagManagementSectionState();
}

class _TagManagementSectionState extends State<TagManagementSection> {
  late Future<List<String>> _tagsFuture;
  late Future<Map<String, int>> _popularTagsFuture;
  late Future<List<String>> _recentTagsFuture;
  List<String> _tagSuggestions = [];
  List<String> _selectedTags = [];
  final FocusNode _tagFocusNode = FocusNode();
  late final TagColorManager _colorManager = TagColorManager.instance;

  // Thêm key để xác định vị trí của input
  final GlobalKey _inputKey = GlobalKey();

  // Vị trí và kích thước của input field
  double _inputHeight = 0;
  double _inputYPosition = 0;

  @override
  void initState() {
    super.initState();
    _loadTagData();
    // Đăng ký listener để cập nhật khi có thay đổi màu sắc
    _colorManager.addListener(_handleColorChanged);

    // Thêm post-frame callback để đo kích thước input sau khi render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateInputPosition();
    });
  }

  // Cập nhật vị trí của input field
  void _updateInputPosition() {
    if (!mounted) return;

    final RenderBox? renderBox =
        _inputKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final RenderBox? stackBox = context.findRenderObject() as RenderBox?;

      if (stackBox != null) {
        final stackPosition = stackBox.localToGlobal(Offset.zero);
        setState(() {
          _inputHeight = renderBox.size.height;
          // Tính toán vị trí tương đối so với Stack
          _inputYPosition =
              position.dy - stackPosition.dy + renderBox.size.height;
        });
      }
    }
  }

  @override
  void dispose() {
    _colorManager.removeListener(_handleColorChanged);
    super.dispose();
  }

  // Xử lý khi màu tag thay đổi
  void _handleColorChanged() {
    if (mounted) {
      setState(() {
        // Chỉ cần rebuild UI
      });
    }
  }

  void _loadTagData() {
    _tagsFuture = TagManager.getTags(widget.filePath).then((tags) {
      setState(() {
        _selectedTags = widget.initialTags ?? tags;
      });
      return tags;
    });
    _popularTagsFuture = TagManager.instance.getPopularTags(limit: 10);
    _recentTagsFuture = TagManager.getRecentTags(limit: 10);
  }

  Future<void> _refreshTags() async {
    setState(() {
      _tagsFuture = TagManager.getTags(widget.filePath).then((tags) {
        setState(() {
          _selectedTags = tags;
        });
        return tags;
      });
      _popularTagsFuture = TagManager.instance.getPopularTags(limit: 10);
      _recentTagsFuture = TagManager.getRecentTags(limit: 10);
      _tagSuggestions = [];
    });

    if (widget.onTagsUpdated != null) {
      widget.onTagsUpdated!();
    }
  }

  Future<void> _addTag(String tag) async {
    if (tag.trim().isEmpty) return;

    try {
      await TagManager.addTag(widget.filePath, tag.trim());
      _refreshTags();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding tag: $e')),
        );
      }
    }
  }

  Future<void> _removeTag(String tag) async {
    try {
      await TagManager.removeTag(widget.filePath, tag);
      _refreshTags();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing tag: $e')),
        );
      }
    }
  }

  Future<void> _updateTagSuggestions(String text) async {
    if (text.isEmpty) {
      setState(() {
        _tagSuggestions = [];
      });
      return;
    }

    // Get tag suggestions based on current input
    final suggestions = await TagManager.instance.searchTags(text);
    if (mounted) {
      setState(() {
        _tagSuggestions =
            suggestions.where((tag) => !_selectedTags.contains(tag)).toList();
      });

      // Cập nhật vị trí của input khi có suggestions
      _updateInputPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Stack(
      clipBehavior:
          Clip.none, // Cho phép các phần tử con vượt ra ngoài phạm vi của Stack
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current file tags
            if (widget.showFileTagsHeader)
              Text(
                'File Tags',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            if (widget.showFileTagsHeader) const SizedBox(height: 8),

            FutureBuilder<List<String>>(
              future: _tagsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final tags = snapshot.data ?? [];
                if (widget.initialTags == null) {
                  _selectedTags = tags;
                }

                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'No tags added to this file yet',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: tags.map((tag) {
                    return TagChip(
                      tag: tag,
                      onDeleted: () => _removeTag(tag),
                      onTap: () {},
                    );
                  }).toList(),
                );
              },
            ),

            // Add tag input with ChipsInput
            const SizedBox(height: 16),
            Container(
              key: _inputKey, // Thêm key để xác định vị trí
              child: Focus(
                focusNode: _tagFocusNode,
                child: ChipsInput<String>(
                  values: _selectedTags,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        width: 0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        width: 0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    labelText: 'Tag Name',
                    labelStyle: TextStyle(
                      fontSize: 18,
                    ),
                    hintText: 'Enter tag name',
                    hintStyle: TextStyle(
                      fontSize: 18,
                    ),
                    prefixIcon: const Icon(Icons.local_offer, size: 24),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.7)
                        : Colors.grey[100]!.withOpacity(0.7),
                  ),
                  style: TextStyle(fontSize: 18),
                  onChanged: (updatedTags) async {
                    // Handle tag removals
                    List<String> removedTags = _selectedTags
                        .where((tag) => !updatedTags.contains(tag))
                        .toList();

                    for (String tag in removedTags) {
                      await _removeTag(tag);
                    }

                    // Handle new tags
                    List<String> newTags = updatedTags
                        .where((tag) => !_selectedTags.contains(tag))
                        .toList();

                    for (String tag in newTags) {
                      await _addTag(tag);
                    }

                    setState(() {
                      _selectedTags = updatedTags;
                    });
                  },
                  onTextChanged: (value) {
                    _updateTagSuggestions(value);
                  },
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _addTag(value.trim());
                    }
                  },
                  chipBuilder: (context, tag) {
                    return TagInputChip(
                      tag: tag,
                      onDeleted: (removedTag) {
                        _removeTag(removedTag);
                      },
                      onSelected: (selectedTag) {},
                    );
                  },
                ),
              ),
            ),

            // Popular tags section
            if (widget.showPopularTags) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    EvaIcons.trendingUpOutline,
                    color: textColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Popular Tags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, int>>(
                future: _popularTagsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final popularTags = snapshot.data ?? {};

                  if (popularTags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No popular tags available',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: popularTags.entries.map((entry) {
                      return TagChip(
                        tag: "${entry.key} (${entry.value})",
                        isCompact: true,
                        onTap: () {
                          if (!_selectedTags.contains(entry.key)) {
                            _addTag(entry.key);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            // Recent tags section
            if (widget.showRecentTags) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    EvaIcons.clockOutline,
                    color: textColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Tags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                future: _recentTagsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final recentTags = snapshot.data ?? [];

                  if (recentTags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No recent tags available',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: recentTags.map((tag) {
                      return TagChip(
                        tag: tag,
                        isCompact: true,
                        onTap: () {
                          if (!_selectedTags.contains(tag)) {
                            _addTag(tag);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),

        // Tag suggestions - hiển thị dưới dạng overlay đè lên các phần tử khác
        if (_tagSuggestions.isNotEmpty)
          Positioned(
            top: _inputYPosition > 0
                ? _inputYPosition
                : 95, // Vị trí ngay bên dưới input
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              elevation: 24,
              shadowColor: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tag Suggestions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              // Thêm nút đóng
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _tagSuggestions = [];
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.withOpacity(0.2)),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _tagSuggestions.length > 6
                              ? 6
                              : _tagSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _tagSuggestions[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (!_selectedTags.contains(suggestion)) {
                                    _addTag(suggestion);
                                  }
                                },
                                child: ListTile(
                                  dense: true,
                                  leading:
                                      const Icon(Icons.local_offer, size: 20),
                                  title: Text(
                                    suggestion,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
