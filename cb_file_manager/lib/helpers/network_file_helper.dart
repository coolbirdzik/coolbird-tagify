import '../ui/utils/file_type_utils.dart';

/// Helper class để xử lý network files
class NetworkFileHelper {
  /// Kiểm tra xem file có phải là network file hay không
  static bool isNetworkFile(String filePath) {
    // Kiểm tra UNC path (Windows network path)
    if (filePath.startsWith('\\\\')) {
      return true;
    }

    // Kiểm tra SMB path
    if (filePath.toLowerCase().startsWith('smb://')) {
      return true;
    }

    // Kiểm tra HTTP/HTTPS URLs
    if (filePath.toLowerCase().startsWith('http://') ||
        filePath.toLowerCase().startsWith('https://')) {
      return true;
    }

    // Kiểm tra FTP URLs
    if (filePath.toLowerCase().startsWith('ftp://')) {
      return true;
    }

    return false;
  }

  /// Kiểm tra xem file có phải là SMB file hay không
  static bool isSmbFile(String filePath) {
    // Kiểm tra UNC path (Windows network path)
    if (filePath.startsWith('\\\\')) {
      return true;
    }

    // Kiểm tra SMB path
    if (filePath.toLowerCase().startsWith('smb://')) {
      return true;
    }

    return false;
  }

  /// Lấy protocol từ file path
  static String? getProtocol(String filePath) {
    if (filePath.startsWith('\\\\')) {
      return 'SMB';
    }

    if (filePath.toLowerCase().startsWith('smb://')) {
      return 'SMB';
    }

    if (filePath.toLowerCase().startsWith('http://')) {
      return 'HTTP';
    }

    if (filePath.toLowerCase().startsWith('https://')) {
      return 'HTTPS';
    }

    if (filePath.toLowerCase().startsWith('ftp://')) {
      return 'FTP';
    }

    return null;
  }

  /// Kiểm tra xem có nên hiển thị streaming speed cho file này hay không
  static bool shouldShowStreamingSpeed(String filePath) {
    // Chỉ hiển thị cho network files
    if (!isNetworkFile(filePath)) {
      return false;
    }

    // Kiểm tra xem có phải là media file không
    return FileTypeUtils.isImageFile(filePath) ||
        FileTypeUtils.isVideoFile(filePath) ||
        FileTypeUtils.isAudioFile(filePath);
  }
}
