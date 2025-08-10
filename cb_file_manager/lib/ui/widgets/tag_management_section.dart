import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/widgets/chips_input.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';
import 'package:cb_file_manager/ui/tab_manager/components/tag_dialogs.dart';

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

  /// Save current tag changes to the file
  void saveChanges() {
    // Find the current state and save changes
    final state = _TagManagementSectionState.of(this);
    if (state != null) {
      state.saveChanges();
    }
  }

  /// Discard current tag changes
  void discardChanges() {
    // Find the current state and discard changes
    final state = _TagManagementSectionState.of(this);
    if (state != null) {
      state.discardChanges();
    }
  }
}

class _TagManagementSectionState extends State<TagManagementSection> {
  // A map of states for accessing from static methods
  static final Map<TagManagementSection, _TagManagementSectionState> _states =
      {};

  // Get the state for a given TagManagementSection
  static _TagManagementSectionState? of(TagManagementSection widget) {
    return _states[widget];
  }

  List<String> _tagSuggestions = [];
  List<String> _selectedTags = [];
  List<String> _originalTags = []; // Store original tags to detect changes
  final FocusNode _tagFocusNode = FocusNode();
  late final TagColorManager _colorManager = TagColorManager.instance;

  // Thêm key để xác định vị trí của input
  final GlobalKey _inputKey = GlobalKey();

  // Vị trí và kích thước của input field
  double _inputYPosition = 0;

  @override
  void initState() {
    super.initState();
    // Register this state
    _states[widget] = this;

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
          // Tính toán vị trí tương đối so với Stack
          _inputYPosition =
              position.dy - stackPosition.dy + renderBox.size.height;
        });
      }
    }
  }

  @override
  void dispose() {
    // Unregister this state
    _states.remove(widget);

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

  void _loadTagData() async {
    // Use initialTags if provided, otherwise fetch from TagManager
    List<String> currentTags = [];

    if (widget.initialTags != null) {
      currentTags = List.from(widget.initialTags!);
    } else {
      try {
        currentTags = await TagManager.getTags(widget.filePath);
      } catch (e) {
        currentTags = [];
      }
    }

    if (mounted) {
      setState(() {
        _selectedTags = List.from(currentTags);
        _originalTags = List.from(currentTags); // Store original state
      });
    }
  }

  // Save all changes to file
  Future<void> saveChanges() async {
    if (!mounted) return;

    try {
      // Get tags to add (those in _selectedTags but not in _originalTags)
      List<String> tagsToAdd =
          _selectedTags.where((tag) => !_originalTags.contains(tag)).toList();

      // Get tags to remove (those in _originalTags but not in _selectedTags)
      List<String> tagsToRemove =
          _originalTags.where((tag) => !_selectedTags.contains(tag)).toList();

      // Process removals
      for (String tag in tagsToRemove) {
        await TagManager.removeTag(widget.filePath, tag);
      }

      // Process additions
      for (String tag in tagsToAdd) {
        await TagManager.addTag(widget.filePath, tag.trim());
      }

      // Force update to original tags to reflect current state
      _originalTags = List.from(_selectedTags);

      // Make sure we trigger notifications manually
      TagManager.clearCache();
      TagManager.instance.notifyTagChanged(widget.filePath);
      TagManager.instance.notifyTagChanged("global:tag_updated");

      // Refresh tags if needed
      _refreshTags();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving tags: $e')),
        );
      }
    }
  }

  // Discard changes and restore original tags
  void discardChanges() {
    setState(() {
      _selectedTags = List.from(_originalTags);
    });
  }

  Future<void> _refreshTags() async {
    setState(() {
      _tagSuggestions = [];
    });

    if (widget.onTagsUpdated != null) {
      widget.onTagsUpdated!();
    }
  }

  // Keep these methods for manual operations if needed, but not called from UI directly

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

    return Stack(
      clipBehavior:
          Clip.none, // Cho phép các phần tử con vượt ra ngoài phạm vi của Stack
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                        width: 0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
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
                    labelStyle: const TextStyle(
                      fontSize: 18,
                    ),
                    hintText: 'Enter tag name',
                    hintStyle: const TextStyle(
                      fontSize: 18,
                    ),
                    prefixIcon: const Icon(Icons.local_offer, size: 24),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.7)
                        : Colors.grey[100]!.withOpacity(0.7),
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (updatedTags) async {
                    // Only update the local state, don't modify file yet
                    setState(() {
                      _selectedTags = List.from(updatedTags);
                    });
                  },
                  onTextChanged: (value) {
                    _updateTagSuggestions(value);
                  },
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      // Just add to selected tags, don't save to file yet
                      setState(() {
                        if (!_selectedTags.contains(value.trim())) {
                          _selectedTags.add(value.trim());
                        }
                      });
                    }
                  },
                  chipBuilder: (context, tag) {
                    return TagInputChip(
                      tag: tag,
                      onDeleted: (removedTag) {
                        // Just update the local state, don't modify file
                        setState(() {
                          _selectedTags.remove(removedTag);
                        });
                      },
                      onSelected: (selectedTag) {},
                    );
                  },
                ),
              ),
            ),

            // Popular tags section
            _buildPopularTagsSection(),

            // Recent tags section
            _buildRecentTagsSection(),
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
                        Expanded(
                          // Wrap ListView.builder with Expanded
                          child: ListView.builder(
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
                                      // Only add to selected tags instead of immediately applying
                                      setState(() {
                                        _selectedTags.add(suggestion);
                                        _tagSuggestions =
                                            []; // Clear suggestions after selection
                                      });
                                    }
                                  },
                                  child: ListTile(
                                    dense: true,
                                    leading:
                                        const Icon(Icons.local_offer, size: 20),
                                    title: Text(
                                      suggestion,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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

  Widget _buildPopularTagsSection() {
    if (!widget.showPopularTags) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: PopularTagsWidget(
        onTagSelected: (tag) {
          setState(() {
            if (!_selectedTags.contains(tag)) {
              _selectedTags.add(tag);
            }
          });
        },
      ),
    );
  }

  Widget _buildRecentTagsSection() {
    if (!widget.showRecentTags) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: RecentTagsWidget(
        onTagSelected: (tag) {
          setState(() {
            if (!_selectedTags.contains(tag)) {
              _selectedTags.add(tag);
            }
          });
        },
      ),
    );
  }
}
