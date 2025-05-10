import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/tag_manager.dart';
import 'package:cb_file_manager/helpers/batch_tag_manager.dart';
import '../../../helpers/io_extensions.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';

/// Shows dialog to add tags to a single file
void showAddTagToFileDialog(BuildContext context, String filePath) {
  final TextEditingController tagController = TextEditingController();

  // Get existing tags for pre-filling
  TagManager.getTags(filePath).then((existingTags) {
    if (existingTags.isNotEmpty) {
      tagController.text = existingTags.join(', ');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm thẻ cho ${File(filePath).basename()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagController,
              decoration: const InputDecoration(
                labelText: 'Nhập thẻ (phân cách bằng dấu phẩy)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () async {
              final tags = tagController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              await TagManager.setTags(filePath, tags);

              if (context.mounted) {
                Navigator.of(context).pop();

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã thêm ${tags.length} thẻ'),
                  ),
                );

                // Ensure tag cache is cleared
                TagManager.clearCache();

                // Try to refresh the file list to show updated tags - safely check for FolderListBloc
                try {
                  final bloc = BlocProvider.of<FolderListBloc>(context);
                  final String path = (bloc.state.currentPath is Directory)
                      ? (bloc.state.currentPath as Directory).path
                      : bloc.state.currentPath.toString();
                  bloc.add(FolderListRefresh(path));
                } catch (e) {
                  // Bloc not available, ignore the error
                  print('FolderListBloc not available in this context: $e');
                }
              }
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
  });
}

/// Shows dialog to delete specific tags from a file
void showDeleteTagDialog(
    BuildContext context, String filePath, List<String> tags) {
  final selectedTags = <String>{};

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Xóa thẻ'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn thẻ để xóa:'),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return CheckboxListTile(
                        title: Text(tag),
                        value: selectedTags.contains(tag),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    },
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
              child: const Text('HỦY'),
            ),
            TextButton(
              onPressed: selectedTags.isEmpty
                  ? null
                  : () async {
                      for (final tag in selectedTags) {
                        await TagManager.removeTag(filePath, tag);
                      }

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã xóa ${selectedTags.length} thẻ'),
                          ),
                        );

                        // Ensure tag cache is cleared
                        TagManager.clearCache();

                        // Try to refresh the file list - safely check for FolderListBloc
                        try {
                          final bloc = BlocProvider.of<FolderListBloc>(context);
                          final String path =
                              (bloc.state.currentPath is Directory)
                                  ? (bloc.state.currentPath as Directory).path
                                  : bloc.state.currentPath.toString();
                          bloc.add(FolderListRefresh(path));
                        } catch (e) {
                          // Bloc not available, ignore the error
                          print(
                              'FolderListBloc not available in this context: $e');
                        }
                      }
                    },
              child: const Text('XÓA'),
            ),
          ],
        );
      },
    ),
  );
}

/// Shows dialog to add tags to multiple files
void showBatchAddTagDialog(BuildContext context, List<String> filePaths) {
  final TextEditingController tagController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Thêm thẻ cho ${filePaths.length} tệp'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: tagController,
            decoration: const InputDecoration(
              labelText: 'Nhập thẻ (phân cách bằng dấu phẩy)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('HỦY'),
        ),
        TextButton(
          onPressed: () async {
            final tags = tagController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            if (tags.isNotEmpty) {
              // Apply each tag individually
              for (String tag in tags) {
                await BatchTagManager.addTagsToFiles(filePaths, tag);
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Đã thêm ${tags.length} thẻ vào ${filePaths.length} tệp'),
                  ),
                );

                // Ensure tag cache is cleared
                TagManager.clearCache();

                // Try to refresh the file list - safely check for FolderListBloc
                try {
                  final bloc = BlocProvider.of<FolderListBloc>(context);
                  final String path = (bloc.state.currentPath is Directory)
                      ? (bloc.state.currentPath as Directory).path
                      : bloc.state.currentPath.toString();
                  bloc.add(FolderListRefresh(path));
                } catch (e) {
                  // Bloc not available, ignore the error
                  print('FolderListBloc not available in this context: $e');
                }
              }
            }
          },
          child: const Text('LƯU'),
        ),
      ],
    ),
  );
}

/// Shows dialog to manage all tags in the system
void showManageTagsDialog(
    BuildContext context, List<String> allTags, String currentPath) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quản lý tất cả thẻ'),
      content: SizedBox(
        width: 350,
        height: 300,
        child: ListView.builder(
          itemCount: allTags.length,
          itemBuilder: (context, index) {
            final tag = allTags[index];
            return ListTile(
              title: Text(tag),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  showDeleteTagConfirmationDialog(context, tag, currentPath);
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('ĐÓNG'),
        ),
      ],
    ),
  );
}

/// Shows confirmation dialog for deleting a tag from all files
void showDeleteTagConfirmationDialog(
    BuildContext context, String tag, String currentPath) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Xác nhận xóa thẻ'),
        content: Text(
            'Bạn có chắc chắn muốn xóa thẻ "$tag" khỏi tất cả các tệp không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text('Đang xóa thẻ...'),
                      ],
                    ),
                  );
                },
              );

              try {
                // Remove tag from all files
                try {
                  // First find all files with this tag
                  final files = await TagManager.findFilesByTagGlobally(tag);
                  final filePaths = files.map((f) => f.path).toList();

                  // Remove the tag from all files
                  await BatchTagManager.removeTagFromFilesStatic(
                      filePaths, tag);

                  // Clear tag cache
                  TagManager.clearCache();
                } catch (e) {
                  // Log the error but continue with the UI flow
                  print('Error removing tag globally: $e');
                }

                if (context.mounted) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã xóa thẻ "$tag" khỏi tất cả các tệp'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Refresh the file list - safely check for FolderListBloc
                  try {
                    final folderListBloc =
                        BlocProvider.of<FolderListBloc>(context);
                    folderListBloc.add(FolderListRefresh(currentPath));
                  } catch (e) {
                    // Bloc not available, ignore the error
                    print('FolderListBloc not available for refresh: $e');
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi khi xóa thẻ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('XÓA', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

/// Shows dialog to remove tags from multiple files
void showRemoveTagsDialog(BuildContext context, List<String> filePaths) {
  final Set<String> availableTags = <String>{};
  bool isLoading = true;

  // Process each file to get all tags
  Future<void> loadTags() async {
    for (final filePath in filePaths) {
      final tags = await TagManager.getTags(filePath);
      availableTags.addAll(tags);
    }

    isLoading = false;
  }

  // Start loading tags
  loadTags();

  showDialog(
    context: context,
    builder: (context) {
      final selectedTags = <String>{};

      return StatefulBuilder(
        builder: (context, setState) {
          if (isLoading) {
            return AlertDialog(
              title: const Text('Loading Tags'),
              content: const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (availableTags.isEmpty) {
            return AlertDialog(
              title: const Text('Không có thẻ'),
              content: const Text('Các tệp đã chọn không có thẻ nào.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ĐÓNG'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Xóa thẻ'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chọn thẻ cần xóa khỏi các tệp đã chọn:'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: availableTags.map((tag) {
                        return CheckboxListTile(
                          title: Text(tag),
                          value: selectedTags.contains(tag),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
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
                child: const Text('HỦY'),
              ),
              TextButton(
                onPressed: selectedTags.isEmpty
                    ? null
                    : () async {
                        // Remove selected tags from files
                        for (final tag in selectedTags) {
                          await BatchTagManager.removeTagFromFilesStatic(
                              filePaths, tag);
                        }

                        if (context.mounted) {
                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Đã xóa ${selectedTags.length} thẻ khỏi ${filePaths.length} tệp'),
                            ),
                          );

                          // Ensure tag cache is cleared
                          TagManager.clearCache();

                          // Try to refresh file list - safely check for FolderListBloc
                          try {
                            final bloc =
                                BlocProvider.of<FolderListBloc>(context);
                            final String currentPath =
                                (bloc.state.currentPath is Directory)
                                    ? (bloc.state.currentPath as Directory).path
                                    : bloc.state.currentPath.toString();
                            bloc.add(FolderListRefresh(currentPath));
                          } catch (e) {
                            // Bloc not available, ignore the error
                            print(
                                'FolderListBloc not available in this context: $e');
                          }
                        }
                      },
                child: const Text('XÓA THẺ'),
              ),
            ],
          );
        },
      );
    },
  );
}
