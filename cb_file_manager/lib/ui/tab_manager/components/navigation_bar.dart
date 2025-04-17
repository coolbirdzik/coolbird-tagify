import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../tab_manager.dart';

/// Navigation bar component that includes back/forward buttons and path input field
class PathNavigationBar extends StatelessWidget {
  final String tabId;
  final TextEditingController pathController;
  final Function(String) onPathSubmitted;
  final String currentPath;

  const PathNavigationBar({
    Key? key,
    required this.tabId,
    required this.pathController,
    required this.onPathSubmitted,
    required this.currentPath,
  }) : super(key: key);

  // Helper method to get directory suggestions based on user input
  Future<List<String>> _getDirectorySuggestions(String query) async {
    if (query.isEmpty) return [];

    List<String> suggestions = [];
    try {
      // Determine parent directory and partial name
      String parentPath;
      String partialName = '';

      if (Platform.isWindows) {
        // Handle Windows paths
        if (query.contains('\\')) {
          // Contains backslash - extract parent path and partial name
          parentPath = query.substring(0, query.lastIndexOf('\\'));
          partialName =
              query.substring(query.lastIndexOf('\\') + 1).toLowerCase();
        } else {
          // Root drive or simple input, show drives or use current path
          if (query.length <= 2 && query.endsWith(':')) {
            // Drive letter only (like "C:") - list all drives
            suggestions = _getWindowsDrives();
            return suggestions
                .where((drive) =>
                    drive.toLowerCase().startsWith(query.toLowerCase()))
                .toList();
          } else {
            parentPath = currentPath;
            partialName = query.toLowerCase();
          }
        }
      } else {
        // Handle Unix-like paths
        if (query.contains('/')) {
          parentPath = query.substring(0, query.lastIndexOf('/'));
          partialName =
              query.substring(query.lastIndexOf('/') + 1).toLowerCase();

          // Handle empty parent path (when query starts with '/')
          if (parentPath.isEmpty && query.startsWith('/')) {
            parentPath = '/';
          }
        } else {
          parentPath = currentPath;
          partialName = query.toLowerCase();
        }
      }

      // Ensure parent path exists
      final parentDir = Directory(parentPath);
      if (await parentDir.exists()) {
        // List directories in the parent path
        await for (final entity in parentDir.list()) {
          try {
            if (entity is Directory) {
              final name = entity.path;
              if (name.toLowerCase().contains(partialName)) {
                suggestions.add(name);
              }
            }
          } catch (e) {
            // Skip directories we don't have access to
            print('Error accessing directory: $e');
          }
        }
      }
    } catch (e) {
      print('Error generating directory suggestions: $e');
    }

    return suggestions;
  }

  // Get list of available Windows drives
  List<String> _getWindowsDrives() {
    List<String> drives = [];
    // Common drive letters
    for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final driveRoot = '$letter:\\';
      if (Directory(driveRoot).existsSync()) {
        drives.add(driveRoot);
      }
    }
    return drives;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back button
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: context.read<TabManagerBloc>().canTabNavigateBack(tabId)
              ? () {
                  final tabBloc = context.read<TabManagerBloc>();
                  final state = tabBloc.state;
                  final tab = state.tabs.firstWhere((t) => t.id == tabId);
                  if (tab.navigationHistory.length > 1) {
                    // Push currentPath into forwardHistory
                    final newForward = List<String>.from(tab.forwardHistory)
                      ..add(tab.path);
                    // Remove currentPath from navigationHistory
                    final newHistory = List<String>.from(tab.navigationHistory)
                      ..removeLast();
                    final newPath = newHistory.last;
                    // Update TabData
                    tabBloc.emit(state.copyWith(
                      tabs: state.tabs
                          .map((t) => t.id == tabId
                              ? t.copyWith(
                                  path: newPath,
                                  navigationHistory: newHistory,
                                  forwardHistory: newForward)
                              : t)
                          .toList(),
                    ));
                    // Update UI through the parent's onPathSubmitted
                    onPathSubmitted(newPath);
                  }
                }
              : null,
          padding: const EdgeInsets.only(right: 4.0),
        ),

        // Forward button
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Forward',
          onPressed: context.read<TabManagerBloc>().canTabNavigateForward(tabId)
              ? () {
                  final tabBloc = context.read<TabManagerBloc>();
                  final state = tabBloc.state;
                  final tab = state.tabs.firstWhere((t) => t.id == tabId);
                  if (tab.forwardHistory.isNotEmpty) {
                    // Get next path
                    final nextPath = tab.forwardHistory.last;
                    // Remove this path from forwardHistory
                    final newForward = List<String>.from(tab.forwardHistory)
                      ..removeLast();
                    // Push currentPath into navigationHistory
                    final newHistory = List<String>.from(tab.navigationHistory)
                      ..add(nextPath);
                    // Update TabData
                    tabBloc.emit(state.copyWith(
                      tabs: state.tabs
                          .map((t) => t.id == tabId
                              ? t.copyWith(
                                  path: nextPath,
                                  navigationHistory: newHistory,
                                  forwardHistory: newForward)
                              : t)
                          .toList(),
                    ));
                    // Update UI through the parent's onPathSubmitted
                    onPathSubmitted(nextPath);
                  }
                }
              : null,
          padding: const EdgeInsets.only(right: 8.0),
        ),

        // Small spacing between buttons and text field
        const SizedBox(width: 4.0),

        // Address bar with autocomplete
        Expanded(
          child: RawAutocomplete<String>(
            textEditingController: pathController,
            focusNode: FocusNode(),
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return await _getDirectorySuggestions(textEditingValue.text);
            },
            onSelected: (String selection) {
              pathController.text = selection;
              onPathSubmitted(selection);
            },
            fieldViewBuilder: (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.navigate_next, size: 20),
                    onPressed: () {
                      onPathSubmitted(textEditingController.text);
                    },
                    padding: const EdgeInsets.all(0),
                    constraints: const BoxConstraints(),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (String value) {
                  onPathSubmitted(value);
                },
              );
            },
            optionsViewBuilder: (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) {
              // Handle empty results case gracefully
              if (options.isEmpty) {
                return const SizedBox
                    .shrink(); // Don't show anything if no results
              }

              // Calculate dimensions based on screen size
              final screenSize = MediaQuery.of(context).size;
              final width = screenSize.width * 0.8; // Use 80% of screen width
              final maxHeight = screenSize.height *
                  0.5; // Limit height to 50% of screen height

              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: maxHeight,
                      maxWidth: width,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        final baseName =
                            option.split(Platform.pathSeparator).last;
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4), // Make items more compact
                          leading: const Icon(Icons.folder, size: 18),
                          title: Text(
                            baseName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            option,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            onSelected(option);
                          },
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
    );
  }
}
