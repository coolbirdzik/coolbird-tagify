import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:path/path.dart';

/// Dialog for adding a tag to a file
void showAddTagToFileDialog(BuildContext context, String filePath) {
  final textController = TextEditingController();
  final focusNode = FocusNode();
  List<String> tagSuggestions = [];

  void updateTagSuggestions(String text) async {
    if (text.isEmpty) {
      tagSuggestions = [];
      return;
    }

    // Get tag suggestions based on current input
    final suggestions = await TagManager.instance.searchTags(text);
    tagSuggestions = suggestions;
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input field with improved design
                Focus(
                  focusNode: focusNode,
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelText: 'Tag Name',
                      hintText: 'Enter tag name',
                      prefixIcon: const Icon(Icons.local_offer),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      updateTagSuggestions(value);
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addTagToFile(context, filePath, value.trim());
                      }
                    },
                  ),
                ),

                // Tag suggestions with improved styling
                if (tagSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
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
                      itemCount:
                          tagSuggestions.length > 5 ? 5 : tagSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = tagSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_offer, size: 18),
                          title: Text(suggestion),
                          onTap: () {
                            _addTagToFile(context, filePath, suggestion);
                          },
                        );
                      },
                    ),
                  ),

                // Popular tags section with improved design
                if (tagSuggestions.isEmpty && textController.text.isEmpty)
                  FutureBuilder<Map<String, int>>(
                    future: TagManager.instance.getPopularTags(limit: 10),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      final popularTags = snapshot.data ?? {};
                      if (popularTags.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.star,
                                  size: 16,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.amber[300]
                                      : Colors.amber),
                              const SizedBox(width: 8),
                              const Text(
                                'Popular Tags:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: popularTags.entries.map((entry) {
                              return ActionChip(
                                avatar: const Icon(Icons.local_offer,
                                    size: 16, color: Colors.green),
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blueGrey[700]
                                    : Colors.blue[50],
                                label: Text(entry.key),
                                onPressed: () {
                                  _addTagToFile(context, filePath, entry.key);
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final tag = textController.text.trim();
                if (tag.isNotEmpty) {
                  _addTagToFile(context, filePath, tag);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('ADD'),
            ),
          ],
        );
      });
    },
  );
}

// Helper function to add a tag to a file and close the dialog
void _addTagToFile(BuildContext context, String filePath, String tag) async {
  // Add tag to file
  await TagManager.addTag(filePath, tag);

  // Clear tag cache to ensure fresh data
  TagManager.clearCache();

  if (context.mounted) {
    // Notify the bloc to update the UI
    BlocProvider.of<FolderListBloc>(context).add(AddTagToFile(filePath, tag));

    // Refresh the file list to show changes
    final currentPath = Directory(filePath).parent.path;
    BlocProvider.of<FolderListBloc>(context)
        .add(FolderListRefresh(currentPath));

    Navigator.of(context).pop();
  }
}

/// Dialog for deleting a tag from a file
void showDeleteTagDialog(
    BuildContext context, String filePath, List<String> tags) {
  String? selectedTag = tags.isNotEmpty ? tags.first : null;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Remove Tag'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
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
                    // First remove the tag directly for immediate effect
                    await TagManager.removeTag(filePath, selectedTag!);

                    // Clear tag cache to ensure fresh data
                    TagManager.clearCache();

                    if (context.mounted) {
                      // Notify bloc to update UI
                      BlocProvider.of<FolderListBloc>(context)
                          .add(RemoveTagFromFile(filePath, selectedTag!));

                      // Refresh the file list to show changes
                      final currentPath = Directory(filePath).parent.path;
                      BlocProvider.of<FolderListBloc>(context)
                          .add(FolderListRefresh(currentPath));

                      Navigator.of(context).pop();
                    }
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('REMOVE'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog for batch adding tags
void showBatchAddTagDialog(BuildContext context, List<String> selectedFiles) {
  final textController = TextEditingController();
  final focusNode = FocusNode();
  List<String> tagSuggestions = [];

  void updateTagSuggestions(String text) async {
    if (text.isEmpty) {
      tagSuggestions = [];
      return;
    }

    // Get tag suggestions based on current input
    final suggestions = await TagManager.instance.searchTags(text);
    tagSuggestions = suggestions;
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text('Add Tag to ${selectedFiles.length} files'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Improved input field with the same style
                Focus(
                  focusNode: focusNode,
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelText: 'Tag Name',
                      hintText: 'Enter tag name',
                      prefixIcon: const Icon(Icons.local_offer),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      updateTagSuggestions(value);
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addTagToBatchFiles(
                            context, selectedFiles, value.trim());
                      }
                    },
                  ),
                ),

                // Tag suggestions with consistent styling
                if (tagSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
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
                      itemCount:
                          tagSuggestions.length > 5 ? 5 : tagSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = tagSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.local_offer, size: 18),
                          title: Text(suggestion),
                          onTap: () {
                            _addTagToBatchFiles(
                                context, selectedFiles, suggestion);
                          },
                        );
                      },
                    ),
                  ),

                // Popular tags section with improved design
                if (tagSuggestions.isEmpty && textController.text.isEmpty)
                  FutureBuilder<Map<String, int>>(
                    future: TagManager.instance.getPopularTags(limit: 10),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      final popularTags = snapshot.data ?? {};
                      if (popularTags.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.star,
                                  size: 16,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.amber[300]
                                      : Colors.amber),
                              const SizedBox(width: 8),
                              const Text(
                                'Popular Tags:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: popularTags.entries.map((entry) {
                              return ActionChip(
                                avatar: const Icon(Icons.local_offer,
                                    size: 16, color: Colors.green),
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blueGrey[700]
                                    : Colors.blue[50],
                                label: Text(entry.key),
                                onPressed: () {
                                  _addTagToBatchFiles(
                                      context, selectedFiles, entry.key);
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final tag = textController.text.trim();
                if (tag.isNotEmpty) {
                  _addTagToBatchFiles(context, selectedFiles, tag);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('ADD'),
            ),
          ],
        );
      });
    },
  );
}

// Helper function to add a tag to multiple files and close the dialog
void _addTagToBatchFiles(
    BuildContext context, List<String> filePaths, String tag) async {
  // Add tag to multiple files
  await TagManager.addTagToFiles(filePaths, tag);

  // Clear tag cache to ensure fresh data
  TagManager.clearCache();

  if (context.mounted) {
    // Notify the bloc to update UI
    BlocProvider.of<FolderListBloc>(context)
        .add(FolderListBatchAddTag(filePaths, tag));

    // Refresh the file list to show changes
    final currentPath = Directory(filePaths.first).parent.path;
    BlocProvider.of<FolderListBloc>(context)
        .add(FolderListRefresh(currentPath));

    Navigator.of(context).pop();
  }
}

/// Dialog for managing all tags
void showManageTagsDialog(
    BuildContext context, List<String> allTags, String currentPath) {
  final Set<String> selectedTags = Set.from(allTags);
  final textController = TextEditingController();
  final focusNode = FocusNode();
  List<String> tagSuggestions = [];

  void updateTagSuggestions(String text, Function setState) {
    if (text.isEmpty) {
      setState(() {
        tagSuggestions = [];
      });
      return;
    }

    // Get tag suggestions based on current input
    TagManager.instance.searchTags(text).then((suggestions) {
      // Filter out tags that are already selected
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
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.tag, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Quản lý Tag'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: "Tải lại danh sách tag",
                  onPressed: () {
                    setState(() {
                      // Force refresh the tag list
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
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 450, minHeight: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Input field for adding new tags
                  Focus(
                    focusNode: focusNode,
                    child: TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Thêm Tag mới',
                        hintText: 'Nhập tên tag',
                        prefixIcon: const Icon(Icons.add_circle_outline),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    textController.clear();
                                    tagSuggestions = [];
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                      ),
                      autofocus: false,
                      onChanged: (value) {
                        updateTagSuggestions(value, setState);
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty &&
                            !selectedTags.contains(value.trim())) {
                          setState(() {
                            selectedTags.add(value.trim());
                            textController.clear();
                            tagSuggestions = [];
                          });
                        }
                      },
                    ),
                  ),

                  // Tag suggestions
                  if (tagSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
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
                            leading: const Icon(Icons.local_offer, size: 18),
                            title: Text(suggestion),
                            trailing: IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              tooltip: "Thêm tag",
                              onPressed: () {
                                setState(() {
                                  selectedTags.add(suggestion);
                                  textController.clear();
                                  tagSuggestions = [];
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                selectedTags.add(suggestion);
                                textController.clear();
                                tagSuggestions = [];
                              });
                              focusNode.requestFocus();
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // Section title
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[300]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tag hiện có (${selectedTags.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tag chips display with delete option
                  Expanded(
                    child: selectedTags.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Không có tag nào',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                Text(
                                  'Thêm tag mới bên trên',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: selectedTags.map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    avatar:
                                        const Icon(Icons.local_offer, size: 16),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.blueGrey[700]
                                            : Colors.blue[50],
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
                                    onDeleted: () async {
                                      // Confirm delete
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Xóa tag "$tag"?'),
                                          content: const Text(
                                              'Tag này sẽ bị xóa khỏi tất cả các tệp. Bạn có chắc chắn không?'),
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
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        setState(() {
                                          selectedTags.remove(tag);
                                        });

                                        // Also delete the tag globally
                                        BlocProvider.of<FolderListBloc>(context)
                                            .add(FolderListDeleteTagGlobally(
                                                tag));

                                        // Clear tag cache to ensure fresh data
                                        TagManager.clearCache();

                                        // Show snackbar
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Đã xóa tag "$tag"'),
                                            backgroundColor: Colors.red,
                                            action: SnackBarAction(
                                              label: 'HOÀN TÁC',
                                              onPressed: () {
                                                setState(() {
                                                  selectedTags.add(tag);
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
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
                  // Refresh folder contents to reflect changes
                  if (context.mounted) {
                    BlocProvider.of<FolderListBloc>(context)
                        .add(FolderListRefresh(currentPath));
                  }

                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
