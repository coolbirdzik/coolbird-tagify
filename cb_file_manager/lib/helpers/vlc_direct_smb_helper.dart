import 'package:flutter/material.dart';
import '../helpers/file_type_helper.dart';
import '../services/network_browsing/i_smb_service.dart';
import '../ui/components/video_player/video_player.dart';
// Unified player is StreamingMediaPlayer; this file only builds URLs.

/// Helper để mở media với Native SMB streaming
/// Stream trực tiếp từ SMB sử dụng thư viện mobile_smb_native
class VlcDirectSmbHelper {
  /// Mở video/audio với Native SMB streaming
  /// Sử dụng mobile_smb_native để stream trực tiếp từ SMB
  static Future<void> openMediaWithVlcDirectSmb({
    required BuildContext context,
    required String smbPath,
    required String fileName,
    required FileType fileType,
    required ISmbService smbService,
  }) async {
    debugPrint('[VlcDirectSmbHelper] ENTERING openMediaWithVlcDirectSmb');
    try {
      // Kiểm tra file type
      if (!_isSupportedMediaType(fileType)) {
        throw Exception('Unsupported media type: $fileType');
      }

      // Kiểm tra kết nối SMB
      if (!smbService.isConnected) {
        throw Exception('SMB service not connected');
      }

      // Kiểm tra basePath
      final basePath = smbService.basePath;
      if (basePath.isEmpty) {
        throw Exception('SMB base path not available');
      }

      debugPrint('VlcDirectSmbHelper: Opening media with Native SMB streaming');
      debugPrint('VlcDirectSmbHelper: SMB Path: $smbPath');
      debugPrint('VlcDirectSmbHelper: File Name: $fileName');
      debugPrint('VlcDirectSmbHelper: File Type: $fileType');

      // Create SMB MRL URL (e.g. smb://host/share/path)
      // Create SMB MRL URL with credentials if available
      String smbUrl;
      try {
        final directLink = await smbService.getSmbDirectLink(smbPath);
        if (directLink != null && directLink.isNotEmpty) {
          smbUrl = directLink;
          debugPrint('VlcDirectSmbHelper: Using direct link with credentials');
        } else {
          smbUrl = createSmbUrl(smbService: smbService, smbPath: smbPath);
          debugPrint('VlcDirectSmbHelper: Using base SMB URL');
        }
      } catch (_) {
        // Fallback if credential fetch fails
        smbUrl = createSmbUrl(smbService: smbService, smbPath: smbPath);
        debugPrint('VlcDirectSmbHelper: Fallback to base SMB URL');
      }

      // Open with the unified StreamingMediaPlayer directly
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayer.smb(
            smbMrl: smbUrl,
            fileName: fileName,
            fileType: fileType,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('VlcDirectSmbHelper: Error opening media: $e');

      // Hiển thị error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi phát media'),
            content: Text(
              'Không thể phát file với VLC Direct SMB:\n\n$e\n\n'
              'Vui lòng kiểm tra:\n'
              '• Kết nối SMB\n'
              '• Đường dẫn file\n'
              '• Quyền truy cập file',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      rethrow;
    }
  }

  /// Kiểm tra xem có thể stream trực tiếp với VLC không
  static bool canStreamDirectly(FileType fileType) {
    return _isSupportedMediaType(fileType);
  }

  /// Tạo SMB URL từ SMB service và path
  static String createSmbUrl({
    required ISmbService smbService,
    required String smbPath,
  }) {
    if (!smbService.isConnected) {
      throw Exception('SMB service not connected');
    }

    // Base path from service (expected like smb://host[/share])
    final basePath = smbService.basePath;

    // Normalize internal app path like '#network/SMB/<host>/<share>/subdir/file'
    String normalized = smbPath;
    if (normalized.startsWith('#network/SMB/')) {
      normalized = normalized.substring('#network/SMB/'.length);
      final firstSlash = normalized.indexOf('/');
      if (firstSlash != -1) {
        // Drop host segment
        normalized = normalized.substring(firstSlash + 1);
      } else {
        normalized = '';
      }
    }

    // Remove leading slash
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    // Decode then re-encode per path segment to avoid double encoding
    final encodedPath = normalized
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((segment) => Uri.encodeComponent(Uri.decodeComponent(segment)))
        .join('/');

    // Ensure there is exactly one slash between basePath and path
    final needsSlash = !basePath.endsWith('/');
    final prefix = needsSlash ? '$basePath/' : basePath;
    return '$prefix$encodedPath';
  }

  /// Kiểm tra file type có được hỗ trợ không
  static bool _isSupportedMediaType(FileType fileType) {
    switch (fileType) {
      case FileType.video:
      case FileType.audio:
        return true;
      case FileType.image:
      case FileType.document:
      case FileType.archive:
      default:
        return false;
    }
  }

  /// Lấy danh sách các format được hỗ trợ bởi VLC
  static List<String> getSupportedVideoFormats() {
    return [
      'mp4',
      'avi',
      'mkv',
      'mov',
      'wmv',
      'flv',
      'webm',
      'm4v',
      'mpg',
      'mpeg',
      '3gp',
      'asf',
      'rm',
      'rmvb',
      'vob',
      'ts',
      'mts',
      'm2ts',
      'divx',
      'xvid',
      'ogv',
      'dv',
      'mxf'
    ];
  }

  static List<String> getSupportedAudioFormats() {
    return [
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'wma',
      'm4a',
      'opus',
      'ac3',
      'dts',
      'ape',
      'aiff',
      'au',
      'ra',
      'amr',
      'awb'
    ];
  }

  /// Kiểm tra extension có được hỗ trợ không
  static bool isSupportedExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    return getSupportedVideoFormats().contains(ext) ||
        getSupportedAudioFormats().contains(ext);
  }

  /// Lấy thông tin về VLC capabilities
  static Map<String, dynamic> getVlcCapabilities() {
    return {
      'direct_smb_streaming': true,
      'hardware_acceleration': true,
      'seek_support': true,
      'playback_speed_control': true,
      'volume_control': true,
      'subtitle_support': true,
      'audio_track_selection': true,
      'video_track_selection': true,
      'supported_protocols': ['smb', 'http', 'https', 'ftp', 'rtsp', 'rtmp'],
      'supported_video_codecs': [
        'H.264',
        'H.265/HEVC',
        'VP8',
        'VP9',
        'AV1',
        'MPEG-2',
        'MPEG-4',
        'DivX',
        'XviD',
        'WMV',
        'FLV',
        'Theora'
      ],
      'supported_audio_codecs': [
        'AAC',
        'MP3',
        'FLAC',
        'Vorbis',
        'Opus',
        'AC-3',
        'DTS',
        'PCM',
        'WMA',
        'ALAC'
      ],
    };
  }

  /// Debug info cho troubleshooting
  static void printDebugInfo({
    required ISmbService smbService,
    required String smbPath,
    required String fileName,
    required FileType fileType,
  }) {
    debugPrint('=== VLC Direct SMB Debug Info ===');
    debugPrint('SMB Service Connected: ${smbService.isConnected}');
    debugPrint('SMB Service connected: ${smbService.isConnected}');
    debugPrint('SMB Path: $smbPath');
    debugPrint('File Name: $fileName');
    debugPrint('File Type: $fileType');
    debugPrint('Supported: ${_isSupportedMediaType(fileType)}');

    try {
      final smbUrl = createSmbUrl(smbService: smbService, smbPath: smbPath);
      debugPrint('Generated SMB URL: $smbUrl');
    } catch (e) {
      debugPrint('Error creating SMB URL: $e');
    }

    debugPrint('VLC Capabilities: ${getVlcCapabilities()}');
    debugPrint('================================');
  }
}
