import 'package:flutter/foundation.dart';
import '../models/database/network_credentials.dart';
import '../objectbox.g.dart';
import 'dart:convert';

/// Service để quản lý thông tin đăng nhập mạng lưu trong ObjectBox
class NetworkCredentialsService {
  static final NetworkCredentialsService _instance =
      NetworkCredentialsService._();

  factory NetworkCredentialsService() => _instance;

  late Box<NetworkCredentials> _credentialsBox;
  bool _isInitialized = false;

  NetworkCredentialsService._();

  /// Khởi tạo service với tham chiếu đến ObjectBox store
  Future<void> init(Store store) async {
    if (_isInitialized) return;

    _credentialsBox = Box<NetworkCredentials>(store);
    _isInitialized = true;
    debugPrint('NetworkCredentialsService initialized successfully');
  }

  /// Lưu thông tin đăng nhập mới
  Future<int> saveCredentials({
    required String serviceType,
    required String host,
    required String username,
    required String password,
    int? port,
    String? domain,
    Map<String, dynamic>? additionalOptions,
  }) async {
    _checkInitialized();

    try {
      // Tạo đối tượng cần lưu
      final credentials = NetworkCredentials(
        serviceType: serviceType,
        host: host,
        username: username,
        password: password,
        port: port,
        domain: domain,
        additionalOptions:
            additionalOptions != null ? jsonEncode(additionalOptions) : null,
        lastConnected: DateTime.now(),
      );

      // Tìm thông tin đăng nhập có sẵn bằng cách lấy tất cả rồi lọc thủ công
      // Cách này không hiệu quả nhưng sẽ giúp tránh lỗi
      final allCredentials = _credentialsBox.getAll();

      NetworkCredentials? existingCredentials;
      for (var cred in allCredentials) {
        if (cred.serviceType == serviceType &&
            cred.host == host &&
            cred.username == username) {
          existingCredentials = cred;
          break;
        }
      }

      if (existingCredentials != null) {
        // Cập nhật thông tin đăng nhập hiện có
        existingCredentials.password = password;
        existingCredentials.port = port;
        existingCredentials.domain = domain;
        existingCredentials.additionalOptions = credentials.additionalOptions;
        existingCredentials.lastConnected = DateTime.now();

        return _credentialsBox.put(existingCredentials);
      } else {
        // Lưu thông tin đăng nhập mới
        return _credentialsBox.put(credentials);
      }
    } catch (e) {
      debugPrint('Error saving network credentials: $e');
      rethrow;
    }
  }

  /// Tìm thông tin đăng nhập cho host và service
  NetworkCredentials? findCredentials({
    required String serviceType,
    required String host,
    String? username,
  }) {
    _checkInitialized();

    try {
      // Chuẩn hóa host
      final normalizedHost = host
          .replaceAll(RegExp(r'^[a-z]+://'), '')
          .replaceAll(RegExp(r':\d+$'), '');

      // Lấy tất cả thông tin đăng nhập và lọc thủ công
      final allCredentials = _credentialsBox.getAll();

      for (var cred in allCredentials) {
        bool serviceMatches = cred.serviceType == serviceType;

        bool hostMatches = cred.host.contains(normalizedHost);

        bool usernameMatches =
            username == null || username.isEmpty || cred.username == username;

        if (serviceMatches && hostMatches && usernameMatches) {
          return cred;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error finding credentials: $e');
      return null;
    }
  }

  /// Lấy tất cả thông tin đăng nhập đã lưu cho một loại dịch vụ
  List<NetworkCredentials> getCredentialsByServiceType(String serviceType) {
    _checkInitialized();

    try {
      // Lấy tất cả thông tin đăng nhập và lọc thủ công
      final allCredentials = _credentialsBox.getAll();
      return allCredentials
          .where((cred) => cred.serviceType == serviceType)
          .toList();
    } catch (e) {
      debugPrint('Error getting credentials by service type: $e');
      return [];
    }
  }

  /// Xóa thông tin đăng nhập cụ thể
  bool deleteCredentials(int id) {
    _checkInitialized();
    return _credentialsBox.remove(id);
  }

  /// Kiểm tra đã khởi tạo service chưa
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'NetworkCredentialsService has not been initialized yet');
    }
  }
}
