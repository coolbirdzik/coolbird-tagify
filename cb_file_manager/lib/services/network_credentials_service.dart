import 'package:flutter/foundation.dart';
import '../models/database/network_credentials.dart';
import '../objectbox.g.dart';
import 'dart:convert';
import 'dart:io';

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
    if (_isInitialized) {
      return;
    }

    try {
      _credentialsBox = Box<NetworkCredentials>(store);
      _isInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('NetworkCredentialsService: Error initializing: $e');
      debugPrint('NetworkCredentialsService: Stack trace: $stackTrace');
      rethrow;
    }
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
    try {
      _checkInitialized();

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

        try {
          final result = _credentialsBox.put(existingCredentials);
          return result;
        } catch (e) {
          debugPrint(
              'NetworkCredentialsService: Error updating existing credential: $e');
          rethrow;
        }
      } else {
        // Lưu thông tin đăng nhập mới
        try {
          final result = _credentialsBox.put(credentials);
          return result;
        } catch (e) {
          debugPrint(
              'NetworkCredentialsService: Error saving new credential: $e');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
          'NetworkCredentialsService: Error saving network credentials: $e');
      debugPrint('NetworkCredentialsService: Stack trace: $stackTrace');
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

      // Tìm credential phù hợp nhất - ưu tiên exact match
      NetworkCredentials? bestMatch;

      for (var cred in allCredentials) {
        // Chuẩn hóa host của credential để so sánh
        final credNormalizedHost = cred.host
            .replaceAll(RegExp(r'^[a-z]+://'), '')
            .replaceAll(RegExp(r':\d+$'), '');

        bool serviceMatches = cred.serviceType == serviceType;
        bool hostMatches = credNormalizedHost ==
            normalizedHost; // Exact match thay vì contains

        if (serviceMatches && hostMatches) {
          // Nếu username được chỉ định, ưu tiên exact match
          if (username != null && username.isNotEmpty) {
            if (cred.username == username) {
              return cred; // Exact match - return ngay
            }
          } else {
            // Nếu không chỉ định username, lấy credential có username không trống
            if (cred.username.isNotEmpty) {
              if (bestMatch == null ||
                  cred.lastConnected.isAfter(bestMatch.lastConnected)) {
                bestMatch = cred;
              }
            }
          }
        }
      }

      return bestMatch;
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
