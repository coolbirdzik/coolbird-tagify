import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pathlib;
import 'package:cb_file_manager/config/languages/app_localizations.dart';
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart'; // For formatFileSize

class GalleryListView extends StatelessWidget {
  final List<File> imageFiles;
  final Set<String> selectedFilePaths;
  final bool isSelectionMode;
  final Function(File, int) onTap;
  final Function(File) onLongPress;
  final Function(File, bool) onSelectionChanged;

  const GalleryListView({
    Key? key,
    required this.imageFiles,
    required this.selectedFilePaths,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: imageFiles.length,
      itemBuilder: (context, index) {
        final file = imageFiles[index];
        final isSelected = selectedFilePaths.contains(file.path);
        final fileExtension = pathlib.extension(file.path).toLowerCase();

        final listTile = ListTile(
          leading: SizedBox(
            width: 60,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
          title: Text(
            pathlib.basename(file.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: FutureBuilder<FileStat>(
            future: file.stat(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                return Text(AppLocalizations.of(context)!.loading);
              }

              if (snapshot.hasError) {
                return const Text('Error');
              }

              final fileStat = snapshot.data!;
              final fileSize = formatFileSize(fileStat.size);
              final fileDate = formatDate(fileStat.modified);
              return Text('$fileExtension • $fileSize • $fileDate');
            },
          ),
          selected: isSelected,
          trailing: isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged(file, value ?? false),
                )
              : null,
          onTap: isSelectionMode
              ? () => onSelectionChanged(file, !isSelected)
              : () => onTap(file, index),
          onLongPress: () => onLongPress(file),
        );

        if (isMobile) {
          return Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: listTile,
          );
        } else {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: listTile,
          );
        }
      },
    );
  }

  String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hôm nay ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Hôm qua ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
