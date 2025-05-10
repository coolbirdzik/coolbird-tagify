import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:path/path.dart' as p;
import 'package:cb_file_manager/widgets/tag_chip.dart';
import 'package:cb_file_manager/widgets/chips_input.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import 'dart:ui' as ui; // Import for ImageFilter
import 'package:flutter/rendering.dart';
import 'package:cb_file_manager/widgets/tag_management_section.dart';

/// Dialog for adding a tag to a file
void showAddTagToFileDialog(BuildContext context, String filePath) {
  // Get screen size for responsive dialog sizing
  final Size screenSize = MediaQuery.of(context).size;
  final double dialogWidth = screenSize.width * 0.5; // 50% of screen width
  final double dialogHeight = screenSize.height * 0.6; // 60% of screen height

  // Function to directly refresh the UI in parent components
  void _refreshParentUI(BuildContext dialogContext, String filePath,
      {bool preserveScroll = true}) {
    // Clear tag cache immediately
    TagManager.clearCache();

    // Notify the application about tag changes so any listening components can update
    // Add a special prefix if we need to preserve scroll position
    if (preserveScroll) {
      TagManager.instance.notifyTagChanged("preserve_scroll:" + filePath);
    } else {
      TagManager.instance.notifyTagChanged(filePath);
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              title: Text(
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
                  child: TagManagementSection(
                    filePath: filePath,
                    onTagsUpdated: () {
                      _refreshParentUI(context, filePath);
                    },
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
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Make sure to notify the parent UI of changes
                    _refreshParentUI(context, filePath);

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

// Helper function to add a tag to a file
void _addTagToFile(BuildContext context, String filePath, String tag) async {
  try {
    // Add tag to file
    await TagManager.addTag(filePath, tag);

    // Clear tag cache to ensure fresh data
    TagManager.clearCache();

    if (context.mounted) {
      try {
        // Try to notify the bloc to update the UI if available
        if (BlocProvider.of<FolderListBloc>(context, listen: false) != null) {
          final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
          bloc.add(AddTagToFile(filePath, tag));

          // Force refresh the UI to show changes immediately
          final currentPath = Directory(filePath).parent.path;
          bloc.add(FolderListRefresh(currentPath));
        }
      } catch (e) {
        // Bloc not available in this context - it's okay, just continue
        print('FolderListBloc not available in this context: $e');
      }

      // Show a snackbar to confirm the tag was added
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tag "$tag" added successfully'),
          duration: const Duration(seconds: 1),
        ),
      );

      // Dialog closing is now handled by the caller
    }
  } catch (e) {
    // Show error if tag couldn't be added
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper function to add a tag to a file without notifications
Future<void> _addTagToFileQuiet(
    BuildContext context, String filePath, String tag) async {
  try {
    // Clear cache first
    TagManager.clearCache();

    // Add tag to file
    await TagManager.addTag(filePath, tag);

    // No need to update UI here as we'll do it after all operations are complete
  } catch (e) {
    print('Error adding tag: $e');
  }
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
                            if (BlocProvider.of<FolderListBloc>(context,
                                    listen: false) !=
                                null) {
                              final bloc = BlocProvider.of<FolderListBloc>(
                                  context,
                                  listen: false);
                              bloc.add(
                                  RemoveTagFromFile(filePath, selectedTag!));

                              // Refresh the file list to show changes immediately
                              final currentPath =
                                  Directory(filePath).parent.path;
                              bloc.add(FolderListRefresh(currentPath));
                            }
                          } catch (e) {
                            // Bloc not available in this context - it's okay, just continue
                            print(
                                'FolderListBloc not available in this context: $e');
                          }

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
  List<String> tagSuggestions = [];
  List<String> selectedTags = [];

  // Get screen size for responsive dialog sizing
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

  // Function to directly refresh the UI in parent components
  void _refreshParentUIBatch() {
    // Clear tag cache immediately
    TagManager.clearCache();

    try {
      if (context.mounted && selectedFiles.isNotEmpty) {
        // Notify tag changes for each file with preserve_scroll prefix
        for (final file in selectedFiles) {
          TagManager.instance.notifyTagChanged("preserve_scroll:" + file);
        }
      }
    } catch (e) {
      print('Error refreshing parent UI: $e');
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
            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AlertDialog(
                title: Text(
                  'Add Tag to ${selectedFiles.length} files',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                content: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main content container
                    Container(
                      width: double.maxFinite,
                      constraints: BoxConstraints(
                        maxWidth: dialogWidth,
                        maxHeight: dialogHeight,
                        minHeight: dialogHeight * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Improved input field with ChipsInput
                            Focus(
                              focusNode: focusNode,
                              child: ChipsInput<String>(
                                values: selectedTags,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  labelText: 'Tag Name',
                                  labelStyle: TextStyle(fontSize: 18),
                                  hintText: 'Enter tag name',
                                  hintStyle: TextStyle(fontSize: 18),
                                  prefixIcon:
                                      const Icon(Icons.local_offer, size: 24),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                ),
                                style: TextStyle(fontSize: 18),
                                onChanged: (updatedTags) {
                                  setState(() {
                                    selectedTags.clear();
                                    selectedTags.addAll(updatedTags);
                                  });
                                },
                                onTextChanged: (value) {
                                  updateTagSuggestions(value);
                                  setState(() {});
                                },
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    final newTag = value.trim();
                                    if (!selectedTags.contains(newTag)) {
                                      setState(() {
                                        selectedTags.add(newTag);
                                      });
                                    }

                                    if (selectedTags.length == 1) {
                                      // If it's the first tag, add it directly
                                      _addTagToBatchFiles(
                                          context, selectedFiles, newTag);
                                    }
                                  }
                                },
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

                            // Space for suggestions
                            const SizedBox(height: 24),

                            // Popular tags section with improved design
                            FutureBuilder<Map<String, int>>(
                              future:
                                  TagManager.instance.getPopularTags(limit: 10),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox.shrink();

                                final popularTags = snapshot.data ?? {};
                                if (popularTags.isEmpty)
                                  return const SizedBox.shrink();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 24,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.amber[300]
                                              : Colors.amber,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Popular Tags:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12.0,
                                      runSpacing: 8.0,
                                      children:
                                          popularTags.entries.map((entry) {
                                        return TagChip(
                                          tag: entry.key,
                                          isCompact: true,
                                          onTap: () {
                                            if (!selectedTags
                                                .contains(entry.key)) {
                                              setState(() {
                                                selectedTags.add(entry.key);
                                              });
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tag suggestions dropdown overlay - positioned on top of everything else
                    if (tagSuggestions.isNotEmpty)
                      Positioned(
                        top: 70, // Position below input field
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: false,
                          child: Material(
                            color: Colors.transparent,
                            elevation: 20,
                            shadowColor: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 250),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[850]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      child: Text(
                                        'Suggestions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Colors.grey.withOpacity(0.1)),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: tagSuggestions.length > 6
                                          ? 6
                                          : tagSuggestions.length,
                                      itemBuilder: (context, index) {
                                        final suggestion =
                                            tagSuggestions[index];
                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              if (!selectedTags
                                                  .contains(suggestion)) {
                                                setState(() {
                                                  selectedTags.add(suggestion);
                                                  tagSuggestions = [];
                                                });
                                              }
                                            },
                                            child: ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                  Icons.local_offer,
                                                  size: 20),
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
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (context.mounted) {
                        try {
                          // Clear tag cache first
                          TagManager.clearCache();

                          // First get common tags among all files
                          final commonTags = await batchTagManager
                              .findCommonTags(selectedFiles);

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

                            // Debug information
                            print('File: $filePath');
                            print('  Original tags: $originalTagsSet');
                            print('  Selected tags: $currentTagsSet');
                            print('  Common tags: $commonTagsSet');

                            // Create updated tags set - keep non-common tags and add selected tags
                            final updatedTags =
                                Set<String>.from(originalTagsSet);

                            // Remove common tags that are no longer selected
                            final commonTagsToRemove =
                                commonTagsSet.difference(currentTagsSet);
                            updatedTags.removeAll(commonTagsToRemove);

                            // Add newly selected tags
                            updatedTags.addAll(currentTagsSet);

                            // Set all tags at once - most reliable approach
                            print('  Final tags: $updatedTags');
                            await TagManager.setTags(
                                filePath, updatedTags.toList());
                          }

                          // Make sure to notify the parent UI of changes
                          _refreshParentUIBatch();

                          // Close the dialog
                          Navigator.of(context).pop();
                        } catch (e) {
                          print('Error processing batch tags: $e');
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
                    child: const Text('SAVE'),
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

// Helper function to add a tag to multiple files
void _addTagToBatchFiles(
  BuildContext context,
  List<String> filePaths,
  String tag,
) async {
  try {
    // Add tag to multiple files
    await TagManager.addTagToFiles(filePaths, tag);

    // Clear tag cache to ensure fresh data
    TagManager.clearCache();

    if (context.mounted) {
      try {
        // Try to notify the bloc to update UI if available
        if (BlocProvider.of<FolderListBloc>(context, listen: false) != null) {
          final bloc = BlocProvider.of<FolderListBloc>(context, listen: false);
          bloc.add(FolderListBatchAddTag(filePaths, tag));

          // Refresh the file list to show changes immediately
          final currentPath = Directory(filePaths.first).parent.path;
          bloc.add(FolderListRefresh(currentPath));
        }
      } catch (e) {
        // Bloc not available in this context - it's okay, just continue
        print('FolderListBloc not available in this context: $e');
      }

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tag "$tag" added to ${filePaths.length} files'),
          duration: const Duration(seconds: 1),
        ),
      );

      // Dialog closing is now handled by the caller
    }
  } catch (e) {
    // Show error if tag couldn't be added
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding tag: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper function to add a tag to multiple files without notifications
Future<void> _addTagToBatchFilesQuiet(
  BuildContext context,
  List<String> filePaths,
  String tag,
) async {
  try {
    // Clear cache first
    TagManager.clearCache();

    // Add tag to multiple files
    await TagManager.addTagToFiles(filePaths, tag);

    // No need to notify here, as we'll do it after all operations are complete
  } catch (e) {
    print('Error adding tag: $e');
  }
}

/// Dialog for managing all tags
void showManageTagsDialog(
  BuildContext context,
  List<String> allTags,
  String currentPath,
) {
  final Set<String> selectedTags = Set.from(allTags);
  final focusNode = FocusNode();
  List<String> tagSuggestions = [];

  // Get screen size for responsive dialog sizing
  final Size screenSize = MediaQuery.of(context).size;
  final double dialogWidth = screenSize.width * 0.5; // 50% of screen width
  final double dialogHeight = screenSize.height * 0.7; // 70% of screen height

  // Function to directly refresh the UI in parent components
  void _refreshParentUIManage() {
    // Clear tag cache immediately
    TagManager.clearCache();

    try {
      if (context.mounted) {
        // For global tag management, notify with the directory path and preserve scroll
        TagManager.instance.notifyTagChanged("preserve_scroll:" + currentPath);
      }
    } catch (e) {
      print('Error refreshing parent UI: $e');
    }
  }

  void updateTagSuggestions(String text, Function setState) {
    if (text.isEmpty) {
      setState(() {
        tagSuggestions = [];
      });
      return;
    }

    TagManager.instance.searchTags(text).then((suggestions) {
      setState(() {
        tagSuggestions =
            suggestions.where((tag) => !selectedTags.contains(tag)).toList();
      });
    });
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.tag, size: 28, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text('Quản lý Tag', style: TextStyle(fontSize: 24)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 24),
                    tooltip: "Tải lại danh sách tag",
                    onPressed: () {
                      setState(() {
                        TagManager.clearCache();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã tải lại danh sách tag'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: dialogHeight,
                  minHeight: 400,
                  minWidth: dialogWidth * 0.8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Focus(
                        focusNode: focusNode,
                        child: ChipsInput<String>(
                          values: selectedTags.toList(),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelText: 'Thêm hoặc xóa Tag',
                            hintText: 'Nhập tên tag để thêm...',
                            prefixIcon: const Icon(Icons.local_offer),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50],
                          ),
                          onChanged: (updatedTags) {
                            setState(() {
                              selectedTags.clear();
                              selectedTags.addAll(updatedTags);
                            });
                          },
                          onTextChanged: (value) {
                            updateTagSuggestions(value, setState);
                          },
                          onSubmitted: (value) {
                            final newTag = value.trim();
                            if (newTag.isNotEmpty &&
                                !selectedTags.contains(newTag)) {
                              setState(() {
                                selectedTags.add(newTag);
                                tagSuggestions = [];
                              });
                            }
                          },
                          chipBuilder: (context, tag) {
                            return TagInputChip(
                              tag: tag,
                              onSelected: (selectedTag) {},
                              onDeleted: (removedTag) async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Xóa tag "$removedTag"?'),
                                    content: const Text(
                                      'Tag này sẽ bị xóa khỏi tất cả các tệp. Bạn có chắc chắn không?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('HỦY'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('XÓA',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  setState(() {
                                    selectedTags.remove(removedTag);
                                    updateTagSuggestions("", setState);
                                  });

                                  try {
                                    if (BlocProvider.of<FolderListBloc>(context,
                                            listen: false) !=
                                        null) {
                                      BlocProvider.of<FolderListBloc>(context,
                                              listen: false)
                                          .add(
                                        FolderListDeleteTagGlobally(removedTag),
                                      );
                                    }
                                  } catch (e) {
                                    print(
                                        'FolderListBloc not available in this context: $e');
                                  }

                                  TagManager.clearCache();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã xóa tag "$removedTag"'),
                                      backgroundColor: Colors.red,
                                      action: SnackBarAction(
                                        label: 'HOÀN TÁC',
                                        onPressed: () {
                                          setState(() {
                                            selectedTags.add(removedTag);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      if (tagSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  tooltip: "Thêm tag",
                                  onPressed: () {
                                    setState(() {
                                      if (!selectedTags.contains(suggestion)) {
                                        selectedTags.add(suggestion);
                                      }
                                      tagSuggestions = [];
                                    });
                                    focusNode.requestFocus();
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    if (!selectedTags.contains(suggestion)) {
                                      selectedTags.add(suggestion);
                                    }
                                    tagSuggestions = [];
                                  });
                                  focusNode.requestFocus();
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ĐÓNG'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('XONG'),
                  onPressed: () async {
                    if (context.mounted) {
                      // Make sure to notify the parent UI of changes
                      _refreshParentUIManage();
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Shows dialog to remove tags from multiple files
void showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
  // Function to directly refresh the UI in parent components
  void _refreshParentUIRemoveTags() {
    // Clear tag cache immediately
    TagManager.clearCache();

    try {
      if (context.mounted && filePaths.isNotEmpty) {
        // Notify tag changes for each file with preserve_scroll prefix
        for (final file in filePaths) {
          TagManager.instance.notifyTagChanged("preserve_scroll:" + file);
        }
      }
    } catch (e) {
      print('Error refreshing parent UI: $e');
    }
  }

  showDialog(
    context: context,
    builder: (context) => RemoveTagsChipDialog(
      filePaths: filePaths,
      onTagsRemoved: () {
        _refreshParentUIRemoveTags();
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
      print('Error loading tags for multiple files: $e');
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
          TagManager.instance.notifyTagChanged("preserve_scroll:" + file);
        }

        // Call the callback so parent components know about the changes
        widget.onTagsRemoved();
      }
    } catch (e) {
      print('Error removing tags: $e');
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
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    // Get screen size for responsive dialog sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double dialogWidth = screenSize.width * 0.5; // 50% of screen width
    final double dialogHeight = screenSize.height * 0.7; // 70% of screen height

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.error.withOpacity(0.8),
                    theme.colorScheme.error.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_sweep_outlined,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Xóa thẻ từ ${widget.filePaths.length} tệp',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Đóng',
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                        'Không có thẻ chung nào giữa các tệp đã chọn.',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hãy thử chọn các tệp khác nhau hoặc đảm bảo chúng có thẻ chung.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Chọn thẻ chung để xóa:',
                          style: theme.textTheme.titleMedium),
                    ),
                    if (_selectedTagsToRemove.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                            "Đã chọn: ${_selectedTagsToRemove.join(", ")}",
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.error)),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                            color: isLightMode
                                ? Colors.grey.shade100
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.2))),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _commonTags.map((tag) {
                              final isSelected =
                                  _selectedTagsToRemove.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (_) => _toggleTagSelection(tag),
                                backgroundColor: isSelected
                                    ? theme.colorScheme.error.withOpacity(0.2)
                                    : (isLightMode
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade700),
                                selectedColor:
                                    theme.colorScheme.error.withOpacity(0.3),
                                checkmarkColor: theme.colorScheme.error,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.error
                                        : null),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.error.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (!_isLoading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: isLightMode
                        ? Colors.grey.shade50
                        : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                        onPressed: _isRemoving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('HỦY'),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _selectedTagsToRemove.isEmpty ||
                              _isRemoving ||
                              _commonTags.isEmpty
                          ? null
                          : _removeSelectedTags,
                      icon: _isRemoving
                          ? Container(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : const Icon(Icons.delete_forever),
                      label: const Text('XÓA THẺ ĐÃ CHỌN'),
                      style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
