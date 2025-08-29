import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';

enum FileType {
  image,
  video,
  audio,
  document,
  pdf,
  archive,
  code,
  spreadsheet,
  presentation,
  text,
  unknown
}

class FileTypeHelper {
  // Check if the file is an image based on extension
  static bool isImage(String extension) {
    return FileTypeUtils.isImageFile('file$extension');
  }

  // Check if the file is a video based on extension
  static bool isVideo(String extension) {
    return FileTypeUtils.isVideoFile('file$extension');
  }

  // Check if the file is an audio based on extension
  static bool isAudio(String extension) {
    return FileTypeUtils.isAudioFile('file$extension');
  }

  // Check if the file is a document based on extension
  static bool isDocument(String extension) {
    return FileTypeUtils.isDocumentFile('file$extension');
  }

  // Get file type based on extension
  static FileType getFileType(String extension) {
    if (extension.isEmpty) return FileType.unknown;

    final lowercaseExt = extension.toLowerCase();

    if (isImage(lowercaseExt)) {
      return FileType.image;
    } else if (isVideo(lowercaseExt)) {
      return FileType.video;
    } else if (isAudio(lowercaseExt)) {
      return FileType.audio;
    } else if (isDocument(lowercaseExt)) {
      return FileType.document;
    } else if (lowercaseExt == '.pdf') {
      return FileType.pdf;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(lowercaseExt)) {
      return FileType.archive;
    } else if (['.xls', '.xlsx', '.csv', '.ods'].contains(lowercaseExt)) {
      return FileType.spreadsheet;
    } else if (['.ppt', '.pptx', '.odp'].contains(lowercaseExt)) {
      return FileType.presentation;
    } else if (['.txt', '.md', '.json', '.xml'].contains(lowercaseExt)) {
      return FileType.text;
    } else if ([
      '.js',
      '.html',
      '.css',
      '.py',
      '.java',
      '.c',
      '.cpp',
      '.h',
      '.cs',
      '.php',
      '.rb',
      '.dart',
      '.swift',
      '.kt'
    ].contains(lowercaseExt)) {
      return FileType.code;
    }

    return FileType.unknown;
  }

  // Get icon for file type
  static IconData getIconForFileType(FileType type) {
    switch (type) {
      case FileType.image:
        return EvaIcons.imageOutline;
      case FileType.video:
        return EvaIcons.videoOutline;
      case FileType.audio:
        return EvaIcons.musicOutline;
      case FileType.document:
        return EvaIcons.fileTextOutline;
      case FileType.pdf:
        return EvaIcons.fileOutline;
      case FileType.archive:
        return EvaIcons.archiveOutline;
      case FileType.code:
        return EvaIcons.code;
      case FileType.spreadsheet:
        return EvaIcons.gridOutline;
      case FileType.presentation:
        return EvaIcons.monitorOutline;
      case FileType.text:
        return EvaIcons.textOutline;
      case FileType.unknown:
      default:
        return EvaIcons.fileOutline;
    }
  }

  // Get color for file type
  static Color getColorForFileType(FileType type) {
    switch (type) {
      case FileType.image:
        return Colors.green;
      case FileType.video:
        return Colors.red;
      case FileType.audio:
        return Colors.blue;
      case FileType.document:
        return Colors.indigo;
      case FileType.pdf:
        return Colors.red.shade700;
      case FileType.archive:
        return Colors.amber.shade700;
      case FileType.code:
        return Colors.teal;
      case FileType.spreadsheet:
        return Colors.green.shade700;
      case FileType.presentation:
        return Colors.orange;
      case FileType.text:
        return Colors.blueGrey;
      case FileType.unknown:
      default:
        return Colors.grey;
    }
  }
}
