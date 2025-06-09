import 'dart:io';
import 'package:flutter/material.dart';
import 'ftp_client/index.dart';
import 'package:path/path.dart' as path;

/// Class đơn giản để kiểm tra kết nối FTP trực tiếp
/// Sử dụng custom FTP client implementation
class FTPTester {
  static Future<List<Map<String, dynamic>>> testConnection({
    required String host,
    required String username,
    String? password,
    int port = 21,
  }) async {
    debugPrint("=== FTP TEST START ===");
    debugPrint("Connecting to FTP: $host:$port with user $username");

    final result = <Map<String, dynamic>>[];

    try {
      // Tạo client FTP
      final ftpClient = FtpClient(
        host: host,
        port: port,
        username: username,
        password: password ?? 'anonymous@',
      );

      // Kết nối
      debugPrint("Attempting to connect...");
      final connected = await ftpClient.connect();
      if (!connected) {
        throw Exception("Connection failed");
      }
      debugPrint("Connected successfully!");

      // Kiểm tra thư mục hiện tại
      String? currentDir = ftpClient.currentDirectory;
      debugPrint("Current directory: $currentDir");

      // Liệt kê nội dung thư mục
      debugPrint("Listing directory content...");
      final listing = await ftpClient.listDirectory();
      debugPrint("Got ${listing.length} items");

      // Duyệt qua danh sách kết quả
      for (var item in listing) {
        final name = path.basename(item.path);
        final type = item.isDirectory ? "dir" : "file";
        final size = item is File ? (await item.stat()).size : 0;
        final modified =
            item is File ? (await item.stat()).modified : DateTime.now();

        debugPrint("Item: $name, Type: $type");

        // Thêm vào kết quả
        result.add({
          'name': name,
          'type': type,
          'size': size,
          'modified': modified,
        });
      }

      // Ngắt kết nối
      await ftpClient.disconnect();
      debugPrint("Disconnected successfully");
    } catch (e) {
      debugPrint("FTP TEST ERROR: $e");
      result.add({'error': e.toString()});
    }

    debugPrint("=== FTP TEST END ===");
    return result;
  }
}
