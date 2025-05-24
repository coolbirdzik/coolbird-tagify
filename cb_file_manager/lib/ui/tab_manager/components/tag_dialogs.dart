import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/ui/widgets/chips_input.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'dart:ui' as ui; // Import for ImageFilter
import 'package:cb_file_manager/ui/widgets/tag_management_section.dart';
import 'package:cb_file_manager/helpers/tag_color_manager.dart';

/// Dialog for adding a tag to a file
void showAddTagToFileDialog(BuildContext context, String filePath) {
  // Get screen size for responsive dialog sizing
  final Size screenSize = MediaQuery.of(context).size;
  final double dialogWidth = screenSize.width * 0.5; // 50% of screen width
  final double dialogHeight = screenSize.height * 0.6; // 60% of screen height

  // Function to directly refresh the UI in parent components
  void refreshParentUI(BuildContext dialogContext, String filePath,
      {bool preserveScroll = true}) {
    // Clear tag cache immediately
    TagManager.clearCache();

    debugPrint("Sending tag notification for path: $filePath");

    // Notify the application about tag changes so any listening components can update
    // Add a special prefix if we need to preserve scroll position
    if (preserveScroll) {
      TagManager.instance.notifyTagChanged("preserve_scroll:$filePath");
    } else {
      TagManager.instance.notifyTagChanged(filePath);
    }

    // Also send a direct notification without prefix to ensure it's caught
    TagManager.instance.notifyTagChanged(filePath);

    // Add a global notification to ensure all listeners are triggered
    TagManager.instance.notifyTagChanged("global:tag_updated");
  }

  showDialog(
    context: context,
    builder: (context) {
      // Create a reference to the TagManagementSection widget
      late TagManagementSection tagManagementSection;

      return StatefulBuilder(
        builder: (context, setState) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              title: const Text(
                'Add Tag',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: dialogHeight,
                  minHeight: dialogHeight * 0.7,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      tagManagementSection = TagManagementSection(
                        filePath: filePath,
                        onTagsUpdated: () {
                          refreshParentUI(context, filePath);
                        },
                      );
                      return tagManagementSection;
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Discard changes
                    tagManagementSection.discardChanges();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save changes
                    tagManagementSection.saveChanges();

                    // Make sure to notify the parent UI of changes
                    refreshParentUI(context, filePath);

                    // Show success notification
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tags saved successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('SAVE'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Dialog for deleting a tag from a file
void showDeleteTagDialog(
  BuildContext context,
  String filePath,
  List<String> tags,
) {
  String? selectedTag = tags.isNotEmpty ? tags.first : null;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              title: const Text('Remove Tag'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(
                  maxWidth: 450,
                  minWidth: 350,
                  minHeight: 100,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a tag to remove:'),
                    const SizedBox(height: 16),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTag,
                      items: tags.map((tag) {
                        return DropdownMenuItem<String>(
                          value: tag,
                          child: Text(tag),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTag = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedTag != null) {
                      try {
                        // First remove the tag directly for immediate effect
                        await TagManager.removeTag(filePath, selectedTag!);

                        // Clear tag cache to ensure fresh data
                        TagManager.clearCache();

                        if (context.mounted) {
                          try {
                            // Try to notify bloc to update UI if available
                            final bloc = BlocProvider.of<FolderListBloc>(
                                context,
                                listen: false);

                            // Only notify about the specific tag removal
                            // Do NOT refresh the entire list
                            bloc.add(RemoveTagFromFile(filePath, selectedTag!));
                          } catch (e) {
                            // Bloc not available in this context - it's okay, just continue
                            debugPrint(
                                'FolderListBloc not available in this context: $e');
                          }

                          // Directly notify with a special prefix to indicate
                          // this is just a tag change and shouldn't trigger a full reload
                          TagManager.instance
                              .notifyTagChanged("tag_only:$filePath");

                          // Show confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tag "$selectedTag" removed'),
                              duration: const Duration(seconds: 1),
                            ),
                          );

                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error removing tag: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('REMOVE'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Dialog for batch adding tags
void showBatchAddTagDialog(BuildContext context, List<String> selectedFiles) {
  final focusNode = FocusNode();
  final TextEditingController textController = TextEditingController();
  List<String> tagSuggestions = [];
  List<String> selectedTags = [];

  // Get screen size for responsive dialog sizing - match single tag dialog
  final Size screenSize = MediaQuery.of(context).size;
  final double dialogWidth = screenSize.width * 0.5; // 50% of screen width
  final double dialogHeight = screenSize.height * 0.6; // 60% of screen height

  void updateTagSuggestions(String text) async {
    if (text.isEmpty) {
      tagSuggestions = [];
      return;
    }

    // Get tag suggestions based on current input
    final suggestions = await TagManager.instance.searchTags(text);
    tagSuggestions =
        suggestions.where((tag) => !selectedTags.contains(tag)).toList();
  }

  // Function to add a tag directly
  void addTag(String tag) {
    if (tag.trim().isEmpty) return;

    if (!selectedTags.contains(tag.trim())) {
      selectedTags.add(tag.trim());
      textController.clear();
    }
  }

  // Function to directly refresh the UI in parent components
  void refreshParentUIBatch() {
    // Clear tag cache immediately
    TagManager.clearCache();

    try {
      if (context.mounted && selectedFiles.isNotEmpty) {
        // Notify tag changes for each file with preserve_scroll prefix
        for (final file in selectedFiles) {
          TagManager.instance.notifyTagChanged("preserve_scroll:$file");
        }
      }
    } catch (e) {
      debugPrint('Error refreshing parent UI: $e');
    }
  }

  // Create BatchTagManager instance and find common tags
  final batchTagManager = BatchTagManager.getInstance();
  batchTagManager.findCommonTags(selectedFiles).then((commonTags) {
    selectedTags = commonTags;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void handleTextChange(String value) {
              updateTagSuggestions(value);
              setState(() {});
            }

            void handleTagSubmit(String value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  addTag(value);
                  tagSuggestions = [];
                });
              }
            }

            void handleTagSelected(String tag) {
              setState(() {
                addTag(tag);
              });
            }

            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AlertDialog(
                title: Text(
                  'Thêm thẻ cho ${selectedFiles.length} tệp',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                content: Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: dialogHeight,
                    minHeight: dialogHeight * 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input field for tags
                        Focus(
                          focusNode: focusNode,
                          child: ChipsInput<String>(
                            values: selectedTags,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelText: 'Tên thẻ',
                              hintText: 'Nhập tên thẻ...',
                              prefixIcon: const Icon(Icons.local_offer),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                            ),
                            onChanged: (updatedTags) {
                              setState(() {
                                selectedTags.clear();
                                selectedTags.addAll(updatedTags);
                              });
                            },
                            onTextChanged: handleTextChange,
                            onSubmitted: handleTagSubmit,
                            chipBuilder: (context, tag) {
                              return TagInputChip(
                                tag: tag,
                                onDeleted: (removedTag) {
                                  setState(() {
                                    selectedTags.remove(removedTag);
                                  });
                                },
                                onSelected: (selectedTag) {},
                              );
                            },
                          ),
                        ),

                        // Tag suggestions
                        if (tagSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemCount: tagSuggestions.length > 5
                                  ? 5
                                  : tagSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = tagSuggestions[index];
                                return ListTile(
                                  dense: true,
                                  leading:
                                      const Icon(Icons.local_offer, size: 18),
                                  title: Text(suggestion),
                                  onTap: () {
                                    setState(() {
                                      addTag(suggestion);
                                      tagSuggestions = [];
                                    });
                                  },
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Display selected tags
                        if (selectedTags.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thẻ đã chọn:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: selectedTags.map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    onDeleted: () {
                                      setState(() {
                                        selectedTags.remove(tag);
                                      });
                                    },
                                    deleteIcon:
                                        const Icon(Icons.close, size: 16),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Popular tags section using the reusable widget
                        PopularTagsWidget(onTagSelected: handleTagSelected),

                        const SizedBox(height: 24),

                        // Recent tags section using the reusable widget
                        RecentTagsWidget(onTagSelected: handleTagSelected),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: const Text('HỦY'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (context.mounted) {
                        try {
                          // Hiển thị thông báo đang xử lý
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đang áp dụng thay đổi...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Clear tag cache first
                          TagManager.clearCache();

                          // First get common tags among all files
                          final commonTags = await batchTagManager
                              .findCommonTags(selectedFiles);

                          // Keeping track of changes for summary report
                          int tagsAdded = 0;
                          int tagsRemoved = 0;

                          // For each file, we need to check existing tags and handle differences
                          for (final filePath in selectedFiles) {
                            // Get original tags for this file with fresh data
                            final existingTags =
                                await TagManager.getTags(filePath);

                            // Calculate the final tag set
                            final Set<String> originalTagsSet =
                                Set.from(existingTags);
                            final Set<String> currentTagsSet =
                                Set.from(selectedTags);
                            final Set<String> commonTagsSet =
                                Set.from(commonTags);

                            // Create updated tags set - keep non-common tags and add selected tags
                            final updatedTags =
                                Set<String>.from(originalTagsSet);

                            // Remove common tags that are no longer selected
                            final commonTagsToRemove =
                                commonTagsSet.difference(currentTagsSet);
                            updatedTags.removeAll(commonTagsToRemove);
                            tagsRemoved += commonTagsToRemove.length;

                            // Add newly selected tags
                            final tagsToAdd =
                                currentTagsSet.difference(originalTagsSet);
                            updatedTags.addAll(tagsToAdd);
                            tagsAdded += tagsToAdd.length;

                            // Set all tags at once - most reliable approach
                            await TagManager.setTags(
                                filePath, updatedTags.toList());

                            // Try to notify the bloc about changes, with proper error handling
                            try {
                              if (context.mounted) {
                                final bloc = BlocProvider.of<FolderListBloc>(
                                    context,
                                    listen: false);
                                for (String tag in commonTagsToRemove) {
                                  bloc.add(RemoveTagFromFile(filePath, tag));
                                }
                                for (String tag in tagsToAdd) {
                                  bloc.add(AddTagToFile(filePath, tag));
                                }
                              }
                            } catch (e) {
                              // Bloc not available in this context - it's okay, just continue
                              debugPrint(
                                  'FolderListBloc not available in batch tag dialog: $e');
                            }
                          }

                          // Make sure to notify the parent UI of changes
                          refreshParentUIBatch();

                          // Hiển thị thông báo tổng kết
                          if (context.mounted) {
                            String message =
                                'Đã cập nhật tags cho ${selectedFiles.length} tệp';
                            if (tagsAdded > 0 || tagsRemoved > 0) {
                              message += ' (';
                              if (tagsAdded > 0) {
                                message += 'thêm $tagsAdded';
                              }
                              if (tagsAdded > 0 && tagsRemoved > 0) {
                                message += ', ';
                              }
                              if (tagsRemoved > 0) {
                                message += 'xóa $tagsRemoved';
                              }
                              message += ')';
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }

                          // Close the dialog
                          Navigator.of(context).pop();
                        } catch (e) {
                          debugPrint('Error processing batch tags: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error processing tags: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('LƯU'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  });
}

/// Widget to display a list of popular tags with animation and hover effects
class PopularTagsWidget extends StatelessWidget {
  final Function(String) onTagSelected;
  final int limit;

  const PopularTagsWidget({
    Key? key,
    required this.onTagSelected,
    this.limit = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: TagManager.instance.getPopularTags(limit: limit),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final popularTags = snapshot.data ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: 18,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.amber[300]
                      : Colors.amber,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Thẻ phổ biến:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedTagList(
              tags: popularTags.keys.toList(),
              counts: popularTags,
              onTagSelected: onTagSelected,
            ),
          ],
        );
      },
    );
  }
}

/// Widget to display a list of recently used tags with animation and hover effects
class RecentTagsWidget extends StatelessWidget {
  final Function(String) onTagSelected;
  final int limit;

  const RecentTagsWidget({
    Key? key,
    required this.onTagSelected,
    this.limit = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: TagManager.getRecentTags(limit: limit),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentTags = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 18,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                const Text(
                  'Thẻ gần đây:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedTagList(
              tags: recentTags,
              onTagSelected: onTagSelected,
            ),
          ],
        );
      },
    );
  }
}

/// An animated tag list that shows tags with hover effects and animations
class AnimatedTagList extends StatelessWidget {
  final List<String> tags;
  final Map<String, int>? counts;
  final Function(String) onTagSelected;

  const AnimatedTagList({
    Key? key,
    required this.tags,
    required this.onTagSelected,
    this.counts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: tags.map((tag) {
        final count = counts != null ? counts![tag] : null;
        final displayText = count != null ? '$tag ($count)' : tag;

        return AnimatedTagChip(
          tag: tag,
          displayText: displayText,
          onTap: () => onTagSelected(tag),
        );
      }).toList(),
    );
  }
}

/// An animated tag chip with hover effects
class AnimatedTagChip extends StatefulWidget {
  final String tag;
  final String displayText;
  final VoidCallback onTap;

  const AnimatedTagChip({
    Key? key,
    required this.tag,
    required this.onTap,
    required this.displayText,
  }) : super(key: key);

  @override
  State<AnimatedTagChip> createState() => _AnimatedTagChipState();
}

class _AnimatedTagChipState extends State<AnimatedTagChip>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late final TagColorManager _colorManager = TagColorManager.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _elevationAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get tag color from TagColorManager
    final tagColor = _colorManager.getTagColor(widget.tag);

    // If tag has a custom color, use it; otherwise use theme colors
    // ignore: unnecessary_null_comparison
    final bool hasCustomColor = tagColor != null;

    // Dynamic colors based on hover state and tag color
    final Color backgroundColor = hasCustomColor
        ? (tagColor.withOpacity(_isHovered ? 0.3 : 0.2))
        : (_isHovered
            ? (isDark
                ? Colors.blue.withOpacity(0.3)
                : theme.colorScheme.primary.withOpacity(0.15))
            : (isDark ? Colors.grey[700]! : Colors.grey[200]!));

    final Color textColor = hasCustomColor
        ? (tagColor)
        : (_isHovered
            ? (isDark ? Colors.white : theme.colorScheme.primary)
            : (isDark ? Colors.grey[200]! : Colors.grey[800]!));

    final Color iconColor = hasCustomColor
        ? (tagColor)
        : (_isHovered
            ? (isDark ? Colors.white : theme.colorScheme.primary)
            : (isDark ? Colors.grey[400]! : Colors.grey[600]!));

    final Color borderColor = hasCustomColor
        ? (tagColor.withOpacity(_isHovered ? 0.8 : 0.3))
        : (_isHovered
            ? theme.colorScheme.primary.withOpacity(0.5)
            : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click, // Use hand cursor on hover
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: () {
          // Play a quick "press" animation
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                elevation: _elevationAnimation.value,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer,
                        size: 14,
                        color: iconColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.displayText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight:
                              _isHovered ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (_isHovered) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: iconColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Helper function to add a tag to multiple files

// Helper function to add a tag to multiple files without notifications

/// Dialog for managing all tags
void showManageTagsDialog(
    BuildContext context, List<String> allTags, String currentPath,
    {List<String>? selectedFiles}) {
  // If there are selected files, just show the remove tags dialog
  if (selectedFiles != null && selectedFiles.isNotEmpty) {
    showRemoveTagsDialog(context, selectedFiles);
    return;
  }

  // If no files are selected, show a notification
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Vui lòng chọn các file để xóa thẻ'),
      duration: Duration(seconds: 2),
    ),
  );
}

/// Shows dialog to remove tags from multiple files
void showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
  // Function to directly refresh the UI in parent components
  void refreshParentUIRemoveTags() {
    // Clear tag cache immediately
    TagManager.clearCache();

    try {
      if (context.mounted && filePaths.isNotEmpty) {
        // Notify tag changes for each file with preserve_scroll prefix
        for (final file in filePaths) {
          TagManager.instance.notifyTagChanged("preserve_scroll:$file");
        }
      }
    } catch (e) {
      debugPrint('Error refreshing parent UI: $e');
    }
  }

  showDialog(
    context: context,
    builder: (context) => RemoveTagsChipDialog(
      filePaths: filePaths,
      onTagsRemoved: () {
        refreshParentUIRemoveTags();
      },
    ),
  );
}

/// A stateful dialog for removing tags from multiple files at once
class RemoveTagsChipDialog extends StatefulWidget {
  final List<String> filePaths;
  final VoidCallback onTagsRemoved;

  const RemoveTagsChipDialog(
      {Key? key, required this.filePaths, required this.onTagsRemoved})
      : super(key: key);

  @override
  State<RemoveTagsChipDialog> createState() => _RemoveTagsChipDialogState();
}

class _RemoveTagsChipDialogState extends State<RemoveTagsChipDialog> {
  final Map<String, Set<String>> _fileTagMap = {};
  final Set<String> _commonTags = {};
  final Set<String> _selectedTagsToRemove = {};
  bool _isLoading = true;
  bool _isRemoving = false; // Added to track removal process

  @override
  void initState() {
    super.initState();
    _loadTagsForFiles();
  }

  /// Loads tags for all selected files and finds the common tags
  Future<void> _loadTagsForFiles() async {
    setState(() => _isLoading = true);

    try {
      // For each file, get its tags
      for (final filePath in widget.filePaths) {
        final tags = await TagManager.getTags(filePath);
        _fileTagMap[filePath] = tags.toSet();

        if (_fileTagMap.keys.length == 1) {
          // First file
          _commonTags.addAll(tags);
        } else {
          _commonTags.retainAll(tags.toSet());
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading tags for multiple files: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Toggles a tag selection for removal
  void _toggleTagSelection(String tag) {
    setState(() {
      if (_selectedTagsToRemove.contains(tag)) {
        _selectedTagsToRemove.remove(tag);
      } else {
        _selectedTagsToRemove.add(tag);
      }
    });
  }

  /// Removes the selected tags from all files
  Future<void> _removeSelectedTags() async {
    if (_selectedTagsToRemove.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isRemoving = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang xóa thẻ...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Loop through each tag to remove and call BatchTagManager for each.
      for (final tagToRemove in _selectedTagsToRemove) {
        await BatchTagManager.removeTagFromFilesStatic(
            widget.filePaths, tagToRemove);

        // Try to notify the bloc about tag removal, with proper error handling
        if (mounted) {
          try {
            // Check if BlocProvider is available before trying to access it
            final bloc =
                BlocProvider.of<FolderListBloc>(context, listen: false);
            for (final filePath in widget.filePaths) {
              bloc.add(RemoveTagFromFile(filePath, tagToRemove));
            }
          } catch (e) {
            // Bloc not available in this context - it's okay, just continue
            debugPrint(
                'FolderListBloc not available in this context for tag removal: $e');
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã xóa ${_selectedTagsToRemove.length} thẻ khỏi ${widget.filePaths.length} tệp'),
          ),
        );

        // Clear tag cache
        TagManager.clearCache();

        // Notify about tag changes to refresh UI
        for (final file in widget.filePaths) {
          TagManager.instance.notifyTagChanged("preserve_scroll:$file");
        }

        // Call the callback so parent components know about the changes
        widget.onTagsRemoved();
      }
    } catch (e) {
      debugPrint('Error removing tags: $e');
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa thẻ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive dialog sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double dialogWidth =
        screenSize.width * 0.5; // Match single tag dialog
    final double dialogHeight =
        screenSize.height * 0.6; // Match single tag dialog

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        title: Text(
          'Xóa thẻ cho ${widget.filePaths.length} tệp',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogHeight,
            minHeight: dialogHeight * 0.7,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Expanded(
                  child: Center(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Đang tải thẻ...")
                    ],
                  )),
                )
              else if (_commonTags.isEmpty && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Không có thẻ chung nào giữa các tệp đã chọn',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedTagsToRemove.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                              "Đã chọn: ${_selectedTagsToRemove.length} thẻ",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      const Text(
                        'Chọn thẻ chung để xóa:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: _commonTags.map((tag) {
                              final isSelected =
                                  _selectedTagsToRemove.contains(tag);
                              return CheckboxListTile(
                                title: Text(tag),
                                value: isSelected,
                                onChanged: (_) => _toggleTagSelection(tag),
                                activeColor:
                                    Theme.of(context).colorScheme.error,
                                checkColor: Colors.white,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isRemoving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: _selectedTagsToRemove.isEmpty ||
                    _isRemoving ||
                    _commonTags.isEmpty
                ? null
                : _removeSelectedTags,
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: _isRemoving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('XÓA THẺ'),
          ),
        ],
      ),
    );
  }
}
