import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/helpers/files/trash_manager.dart';
import 'package:intl/intl.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({Key? key}) : super(key: key);

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  final TrashManager _trashManager = TrashManager();
  List<TrashItem> _trashItems = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  String? _errorMessage;
  bool _showSystemOptions = false;

  @override
  void initState() {
    super.initState();
    _loadTrashItems();
  }

  Future<void> _loadTrashItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _trashManager.getTrashItems();
      setState(() {
        _trashItems = items;
        _isLoading = false;

        // Determine if we have system items to show system-specific options
        _showSystemOptions =
            Platform.isWindows && items.any((item) => item.isSystemTrashItem);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading trash items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;

      if (item.isSystemTrashItem && Platform.isWindows) {
        // Restore from Windows Recycle Bin
        success = await _trashManager
            .restoreFromWindowsRecycleBin(item.trashFileName);
      } else {
        // Restore from internal trash
        success = await _trashManager.restoreFromTrash(item.trashFileName);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${item.displayNameValue} restored successfully')),
        );
        // Refresh the trash items
        await _loadTrashItems();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to restore ${item.displayNameValue}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error restoring item: $e';
      });
    }
  }

  Future<void> _deleteItem(TrashItem item) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permanently Delete'),
            content: Text(
              'Are you sure you want to permanently delete "${item.displayNameValue}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        bool success = false;

        if (item.isSystemTrashItem && Platform.isWindows) {
          // Delete from Windows Recycle Bin
          success = await _trashManager
              .deleteFromWindowsRecycleBin(item.trashFileName);
        } else {
          // Delete from internal trash
          success = await _trashManager.deleteFromTrash(item.trashFileName);
        }

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${item.displayNameValue} permanently deleted')),
          );
          // Refresh the trash items
          await _loadTrashItems();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to delete ${item.displayNameValue}';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting item: $e';
        });
      }
    }
  }

  Future<void> _emptyTrash() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Empty Trash'),
            content: const Text(
              'Are you sure you want to permanently delete all items in the trash? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('EMPTY TRASH',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _trashManager.emptyTrash();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trash emptied successfully')),
          );
          // Refresh the trash items
          await _loadTrashItems();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to empty trash';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error emptying trash: $e';
        });
      }
    }
  }

  Future<void> _openSystemRecycleBin() async {
    if (Platform.isWindows) {
      try {
        await _trashManager.openWindowsRecycleBin();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Recycle Bin: $e')),
        );
      }
    }
  }

  Future<void> _restoreSelectedItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int failedCount = 0;

      for (final trashFileName in _selectedItems) {
        final item = _trashItems.firstWhere(
          (item) => item.trashFileName == trashFileName,
          orElse: () => throw Exception('Item not found'),
        );

        bool success = false;
        if (item.isSystemTrashItem && Platform.isWindows) {
          success = await _trashManager
              .restoreFromWindowsRecycleBin(item.trashFileName);
        } else {
          success = await _trashManager.restoreFromTrash(item.trashFileName);
        }

        if (success) {
          successCount++;
        } else {
          failedCount++;
        }
      }

      String message = '$successCount items restored successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Clear selection and refresh
      setState(() {
        _isSelectionMode = false;
        _selectedItems.clear();
      });

      await _loadTrashItems();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error restoring items: $e';
      });
    }
  }

  Future<void> _deleteSelectedItems() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permanently Delete ${_selectedItems.length} items?'),
            content: const Text(
              'This action cannot be undone. Are you sure you want to permanently delete these items?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        int successCount = 0;
        int failedCount = 0;

        for (final trashFileName in _selectedItems) {
          final item = _trashItems.firstWhere(
            (item) => item.trashFileName == trashFileName,
            orElse: () => throw Exception('Item not found'),
          );

          bool success = false;
          if (item.isSystemTrashItem && Platform.isWindows) {
            success = await _trashManager
                .deleteFromWindowsRecycleBin(item.trashFileName);
          } else {
            success = await _trashManager.deleteFromTrash(item.trashFileName);
          }

          if (success) {
            successCount++;
          } else {
            failedCount++;
          }
        }

        String message = '$successCount items permanently deleted';
        if (failedCount > 0) {
          message += ', $failedCount failed';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        // Clear selection and refresh
        setState(() {
          _isSelectionMode = false;
          _selectedItems.clear();
        });

        await _loadTrashItems();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting items: $e';
        });
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String trashFileName) {
    setState(() {
      if (_selectedItems.contains(trashFileName)) {
        _selectedItems.remove(trashFileName);
      } else {
        _selectedItems.add(trashFileName);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _trashItems.length) {
        // If all are selected, deselect all
        _selectedItems.clear();
      } else {
        // Otherwise, select all
        _selectedItems.clear();
        for (final item in _trashItems) {
          _selectedItems.add(item.trashFileName);
        }
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 B';

    final i = (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    final formattedSize = i == 0 ? size.toInt() : size.toStringAsFixed(1);

    return '$formattedSize ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash Bin'),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(EvaIcons.checkmarkSquare2Outline),
              tooltip: 'Select All',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(EvaIcons.refreshOutline),
              tooltip: 'Restore Selected',
              onPressed: _selectedItems.isEmpty ? null : _restoreSelectedItems,
            ),
            IconButton(
              icon: const Icon(EvaIcons.trash2Outline),
              tooltip: 'Delete Selected',
              onPressed: _selectedItems.isEmpty ? null : _deleteSelectedItems,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(EvaIcons.checkmarkSquare2Outline),
              tooltip: 'Select Items',
              onPressed: _trashItems.isEmpty ? null : _toggleSelectionMode,
            ),
            if (Platform.isWindows && _showSystemOptions)
              IconButton(
                icon: const Icon(EvaIcons.externalLinkOutline),
                tooltip: 'Open Recycle Bin',
                onPressed: _openSystemRecycleBin,
              ),
            IconButton(
              icon: const Icon(EvaIcons.trashOutline),
              tooltip: 'Empty Trash',
              onPressed: _trashItems.isEmpty ? null : _emptyTrash,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                EvaIcons.alertTriangleOutline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTrashItems,
                icon: const Icon(EvaIcons.refreshOutline),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_trashItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              EvaIcons.trash2Outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Trash is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Items you delete will appear here',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTrashItems,
              icon: const Icon(EvaIcons.refreshOutline),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrashItems,
      child: ListView.builder(
        itemCount: _trashItems.length,
        itemBuilder: (context, index) {
          final item = _trashItems[index];
          final isSelected = _selectedItems.contains(item.trashFileName);

          return ListTile(
            leading: _getFileIcon(item.displayNameValue),
            title: Text(
              item.displayNameValue,
              style: item.isSystemTrashItem
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original location: ${item.originalPath}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      'Deleted: ${_formatDate(item.trashedDate)} • ${_formatFileSize(item.size)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (item.isSystemTrashItem) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'System',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            selected: isSelected,
            trailing: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (value) =>
                        _toggleItemSelection(item.trashFileName),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(EvaIcons.refreshOutline, size: 20),
                        tooltip: 'Restore',
                        onPressed: () => _restoreItem(item),
                      ),
                      IconButton(
                        icon: const Icon(EvaIcons.trash2Outline, size: 20),
                        tooltip: 'Delete permanently',
                        onPressed: () => _deleteItem(item),
                      ),
                    ],
                  ),
            onTap: _isSelectionMode
                ? () => _toggleItemSelection(item.trashFileName)
                : null,
            onLongPress: () {
              if (!_isSelectionMode) {
                _toggleSelectionMode();
                _toggleItemSelection(item.trashFileName);
              }
            },
          );
        },
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    // Use FileTypeUtils to determine file type
    if (FileTypeUtils.isImageFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(EvaIcons.imageOutline, color: Colors.white),
      );
    }

    // Video file
    if (FileTypeUtils.isVideoFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(EvaIcons.videoOutline, color: Colors.white),
      );
    }

    // Audio file
    if (FileTypeUtils.isAudioFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(EvaIcons.musicOutline, color: Colors.white),
      );
    }

    // Document file
    if (FileTypeUtils.isDocumentFile(fileName) ||
        FileTypeUtils.isSpreadsheetFile(fileName) ||
        FileTypeUtils.isPresentationFile(fileName)) {
      return const CircleAvatar(
        backgroundColor: Colors.orange,
        child: Icon(EvaIcons.fileTextOutline, color: Colors.white),
      );
    }

    // Default icon
    return const CircleAvatar(
      backgroundColor: Colors.grey,
      child: Icon(EvaIcons.fileOutline, color: Colors.white),
    );
  }
}
