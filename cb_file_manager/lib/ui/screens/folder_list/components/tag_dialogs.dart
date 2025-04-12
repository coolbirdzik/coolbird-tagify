import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_bloc.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_event.dart';

/// Dialog for adding a tag to a file
void showAddTagToFileDialog(BuildContext context, String filePath) {
  final textController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            hintText: 'Enter tag name',
          ),
          autofocus: true,
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
                BlocProvider.of<FolderListBloc>(context)
                    .add(AddTagToFile(filePath, tag));
              }
              Navigator.of(context).pop();
            },
            child: const Text('ADD'),
          ),
        ],
      );
    },
  );
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
                onPressed: () {
                  if (selectedTag != null) {
                    BlocProvider.of<FolderListBloc>(context)
                        .add(RemoveTagFromFile(filePath, selectedTag!));
                  }
                  Navigator.of(context).pop();
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

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Add Tag to ${selectedFiles.length} files'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Tag Name',
            hintText: 'Enter tag name',
          ),
          autofocus: true,
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
                BlocProvider.of<FolderListBloc>(context)
                    .add(FolderListBatchAddTag(selectedFiles, tag));
              }
              Navigator.of(context).pop();
            },
            child: const Text('ADD'),
          ),
        ],
      );
    },
  );
}

/// Dialog for managing all tags
void showManageTagsDialog(BuildContext context, List<String> allTags) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Manage Tags'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allTags.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(allTags[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    BlocProvider.of<FolderListBloc>(context)
                        .add(FolderListDeleteTagGlobally(allTags[index]));
                    Navigator.of(context).pop();
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
            child: const Text('CLOSE'),
          ),
        ],
      );
    },
  );
}
