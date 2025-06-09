import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import '../tab_manager.dart';

/// Navigation bar component that includes back/forward buttons and path input field
class PathNavigationBar extends StatefulWidget {
  final String tabId;
  final TextEditingController pathController;
  final Function(String) onPathSubmitted;
  final String currentPath;
  final bool isNetworkPath;

  const PathNavigationBar({
    Key? key,
    required this.tabId,
    required this.pathController,
    required this.onPathSubmitted,
    required this.currentPath,
    this.isNetworkPath = false,
  }) : super(key: key);

  @override
  State<PathNavigationBar> createState() => _PathNavigationBarState();
}

class _PathNavigationBarState extends State<PathNavigationBar> {
  // Lưu trữ tham chiếu đến TabManagerBloc
  TabManagerBloc? _tabBloc;
  bool _canNavigateBack = false;
  bool _canNavigateForward = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy TabManagerBloc mỗi khi dependencies thay đổi
    try {
      _tabBloc = context.read<TabManagerBloc>();
      _updateNavigationState();
    } catch (e) {
      debugPrint('Error accessing TabManagerBloc: $e');
      _tabBloc = null;
    }
  }

  void _updateNavigationState() {
    if (_tabBloc != null) {
      setState(() {
        _canNavigateBack = _tabBloc!.canTabNavigateBack(widget.tabId);
        _canNavigateForward = _tabBloc!.canTabNavigateForward(widget.tabId);
      });
    }
  }

  // Xử lý nút điều hướng lùi
  void _handleBackNavigation() {
    if (_tabBloc == null || !_canNavigateBack) return;

    final state = _tabBloc!.state;
    final tab = state.tabs.firstWhere((t) => t.id == widget.tabId);
    if (tab.navigationHistory.length > 1) {
      // Push currentPath into forwardHistory
      final newForward = List<String>.from(tab.forwardHistory)..add(tab.path);
      // Remove currentPath from navigationHistory
      final newHistory = List<String>.from(tab.navigationHistory)..removeLast();
      final newPath = newHistory.last;
      // Update TabData
      _tabBloc!.emit(state.copyWith(
        tabs: state.tabs
            .map((t) => t.id == widget.tabId
                ? t.copyWith(
                    path: newPath,
                    navigationHistory: newHistory,
                    forwardHistory: newForward)
                : t)
            .toList(),
      ));
      // Update UI through the parent's onPathSubmitted
      widget.onPathSubmitted(newPath);
    }
  }

  // Xử lý nút điều hướng tiến
  void _handleForwardNavigation() {
    if (_tabBloc == null || !_canNavigateForward) return;

    final state = _tabBloc!.state;
    final tab = state.tabs.firstWhere((t) => t.id == widget.tabId);
    if (tab.forwardHistory.isNotEmpty) {
      // Get next path
      final nextPath = tab.forwardHistory.last;
      // Remove this path from forwardHistory
      final newForward = List<String>.from(tab.forwardHistory)..removeLast();
      // Push currentPath into navigationHistory
      final newHistory = List<String>.from(tab.navigationHistory)
        ..add(nextPath);
      // Update TabData
      _tabBloc!.emit(state.copyWith(
        tabs: state.tabs
            .map((t) => t.id == widget.tabId
                ? t.copyWith(
                    path: nextPath,
                    navigationHistory: newHistory,
                    forwardHistory: newForward)
                : t)
            .toList(),
      ));
      // Update UI through the parent's onPathSubmitted
      widget.onPathSubmitted(nextPath);
    }
  }

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
            parentPath = widget.currentPath;
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
          parentPath = widget.currentPath;
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
            debugPrint('Error accessing directory: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating directory suggestions: $e');
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
    // Gọi lại _updateNavigationState để đảm bảo trạng thái mới nhất
    if (_tabBloc != null) {
      _updateNavigationState();
    }

    return Row(
      children: [
        IconButton(
          icon: const Icon(EvaIcons.arrowBack),
          onPressed: _canNavigateBack
              ? () => BlocProvider.of<TabManagerBloc>(context)
                  .backNavigationToPath(widget.tabId)
              : null,
          tooltip: 'Go back',
        ),
        IconButton(
          icon: const Icon(EvaIcons.arrowForward),
          onPressed: _canNavigateForward
              ? () => BlocProvider.of<TabManagerBloc>(context)
                  .forwardNavigationToPath(widget.tabId)
              : null,
          tooltip: 'Go forward',
        ),

        // Special display for network paths
        if (widget.isNetworkPath) ...[
          const Icon(EvaIcons.wifi),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatNetworkPath(widget.currentPath),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: TextField(
              controller: widget.pathController,
              decoration: InputDecoration(
                hintText: 'Path',
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .inputDecorationTheme
                    .fillColor
                    ?.withOpacity(0.7),
              ),
              onSubmitted: widget.onPathSubmitted,
              textInputAction: TextInputAction.go,
            ),
          ),
        ],
      ],
    );
  }

  // Format a network path for display
  String _formatNetworkPath(String path) {
    if (!path.startsWith('#network/')) return path;

    try {
      final parts = path.split('/');
      if (parts.length < 3) return path;

      final protocol = parts[1].toUpperCase(); // SMB, FTP, etc.
      final server = Uri.decodeComponent(parts[2]);

      if (parts.length >= 4 && parts[3].startsWith('S')) {
        // We have a share
        final share = Uri.decodeComponent(parts[3].substring(1));

        if (parts.length > 4) {
          // We have a subfolder
          final remainingPath = parts.sublist(4).join('/');
          return '$protocol://$server/$share/$remainingPath';
        } else {
          return '$protocol://$server/$share';
        }
      } else {
        return '$protocol://$server';
      }
    } catch (_) {
      return path;
    }
  }
}
