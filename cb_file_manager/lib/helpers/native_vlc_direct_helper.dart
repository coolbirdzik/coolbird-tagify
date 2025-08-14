import 'package:flutter/material.dart';
import 'package:mobile_smb_native/mobile_smb_native.dart';
import '../helpers/file_type_helper.dart';
import '../services/network_browsing/i_smb_service.dart';
import '../ui/components/video_player/video_player.dart';
import 'vlc_direct_smb_helper.dart';

/// Helper để mở media với Native VLC Direct SMB streaming
/// Sử dụng mobile_smb_native để tạo SMB URL trực tiếp cho VLC
class NativeVlcDirectHelper {
  /// Mở video/audio với Native VLC Direct SMB streaming
  /// Sử dụng mobile_smb_native để tạo SMB URL trực tiếp cho VLC
  static Future<void> openMediaWithNativeVlcDirect({
    required BuildContext context,
    required String smbPath,
    required String fileName,
    required FileType fileType,
    required ISmbService smbService,
  }) async {
    debugPrint('[NativeVlcDirectHelper] ENTERING openMediaWithNativeVlcDirect');
    try {
      // Kiểm tra file type
      if (!_isSupportedMediaType(fileType)) {
        throw Exception('Unsupported media type: $fileType');
      }

      // Kiểm tra kết nối SMB
      if (!smbService.isConnected) {
        throw Exception('SMB service not connected');
      }

      debugPrint(
          'NativeVlcDirectHelper: Opening media with Native VLC Direct SMB streaming');
      debugPrint('NativeVlcDirectHelper: SMB Path: $smbPath');
      debugPrint('NativeVlcDirectHelper: File Name: $fileName');
      debugPrint('NativeVlcDirectHelper: File Type: $fileType');

      // Resolve REAL SMB MRL (prefer native direct link with credentials)
      String finalSmbMrl;
      try {
        final directLink = await smbService.getSmbDirectLink(smbPath);
        if (directLink != null && directLink.isNotEmpty) {
          finalSmbMrl = directLink;
          debugPrint(
              'NativeVlcDirectHelper: Using direct SMB link from service');
        } else {
          finalSmbMrl = VlcDirectSmbHelper.createSmbUrl(
            smbService: smbService,
            smbPath: smbPath,
          );
          debugPrint('NativeVlcDirectHelper: Using constructed SMB URL');
        }
      } catch (_) {
        finalSmbMrl = VlcDirectSmbHelper.createSmbUrl(
          smbService: smbService,
          smbPath: smbPath,
        );
        debugPrint('NativeVlcDirectHelper: Fallback to constructed SMB URL');
      }

      debugPrint('NativeVlcDirectHelper: Final SMB MRL => ' + finalSmbMrl);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayer.smb(
            smbMrl: finalSmbMrl,
            fileName: fileName,
            fileType: fileType,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NativeVlcDirectHelper: Error opening media: $e');

      // Hiển thị error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi phát media'),
            content: Text(
              'Không thể phát file với Native VLC Direct SMB:\n\n$e\n\n'
              'Vui lòng kiểm tra:\n'
              '• Kết nối SMB\n'
              '• Đường dẫn file\n'
              '• Quyền truy cập file\n'
              '• Native SMB client availability',
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

  /// Kiểm tra xem có thể stream trực tiếp với Native VLC không
  static bool canStreamDirectly(FileType fileType) {
    return _isSupportedMediaType(fileType);
  }

  /// Kiểm tra xem Native SMB client có sẵn sàng không
  static Future<bool> isNativeSmbAvailable() async {
    try {
      // Try to initialize the native SMB service
      // This will throw an exception if the native library is not available
      final smbService = SmbNativeService.instance;
      return true;
    } catch (e) {
      debugPrint('NativeVlcDirectHelper: Native SMB not available: $e');
      return false;
    }
  }

  /// Kiểm tra xem có thể sử dụng Native VLC Direct streaming không
  static Future<bool> canUseNativeVlcDirect({
    required FileType fileType,
    required ISmbService smbService,
  }) async {
    debugPrint(
        'NativeVlcDirectHelper: Checking if can use Native VLC Direct...');
    debugPrint('NativeVlcDirectHelper: File type: $fileType');
    debugPrint(
        'NativeVlcDirectHelper: SMB service type: ${smbService.runtimeType}');
    debugPrint(
        'NativeVlcDirectHelper: SMB service connected: ${smbService.isConnected}');

    // Kiểm tra file type
    if (!_isSupportedMediaType(fileType)) {
      debugPrint('NativeVlcDirectHelper: ❌ File type not supported: $fileType');
      return false;
    }
    debugPrint('NativeVlcDirectHelper: ✅ File type supported: $fileType');

    // Kiểm tra kết nối SMB
    if (!smbService.isConnected) {
      debugPrint('NativeVlcDirectHelper: ❌ SMB service not connected');
      return false;
    }
    debugPrint('NativeVlcDirectHelper: ✅ SMB service connected');

    // Kiểm tra Native SMB availability
    final nativeAvailable = await isNativeSmbAvailable();
    if (!nativeAvailable) {
      debugPrint('NativeVlcDirectHelper: ❌ Native SMB not available');
      return false;
    }
    debugPrint('NativeVlcDirectHelper: ✅ Native SMB available');

    debugPrint(
        'NativeVlcDirectHelper: ✅ All checks passed - can use Native VLC Direct');
    return true;
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

  /// Lấy danh sách các format audio được hỗ trợ bởi VLC
  static List<String> getSupportedAudioFormats() {
    return [
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'm4a',
      'wma',
      'opus',
      'ac3',
      'dts',
      'ra',
      'amr',
      'ape',
      'wv',
      'tta',
      'alac',
      'aiff',
      'au',
      'snd',
      'mid',
      'midi',
      'kar',
      'rmi'
    ];
  }

  /// So sánh hiệu suất giữa các phương pháp streaming
  static Map<String, String> getStreamingMethodComparison() {
    return {
      'Native VLC Direct': 'Cao nhất - Stream trực tiếp từ SMB URL',
      'VLC Direct SMB': 'Cao - Stream trực tiếp nhưng có thể cần credentials',
      'HTTP Proxy': 'Trung bình - Qua HTTP proxy server',
      'LibSMB2 Direct': 'Cao - Sử dụng native libsmb2',
      'Chunked Download': 'Thấp - Tải từng chunk và tạo file tạm',
    };
  }

  /// Lấy thông tin về Native VLC Direct streaming
  static Map<String, String> getNativeVlcDirectInfo() {
    return {
      'Phương pháp': 'Native VLC Direct SMB',
      'Mô tả': 'Stream trực tiếp từ SMB URL sử dụng mobile_smb_native',
      'Ưu điểm': 'Hiệu suất cao nhất, không cần file tạm, hỗ trợ seek',
      'Nhược điểm': 'Cần native SMB client, có thể cần credentials',
      'Tương thích': 'Android, iOS (với native library)',
      'Protocol': 'SMB2/SMB3 trực tiếp',
      'Buffering': 'Native VLC buffering',
      'Seek support': 'Có',
      'Hardware acceleration': 'Có',
    };
  }
}
