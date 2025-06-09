import 'package:objectbox/objectbox.dart';

@Entity()
class NetworkCredentials {
  @Id()
  int id = 0;

  // Loại dịch vụ (SMB, FTP, WebDAV)
  String serviceType;

  // Địa chỉ server
  String host;

  // Tên người dùng
  String username;

  // Mật khẩu (lưu ý: trong thực tế nên mã hóa mật khẩu trước khi lưu)
  String password;

  // Port tùy chọn
  int? port;

  // Domain cho SMB/CIFS
  String? domain;

  // Các tùy chọn bổ sung dạng JSON string
  String? additionalOptions;

  // Thời gian lần cuối kết nối
  @Property(type: PropertyType.date)
  DateTime lastConnected;

  // Constructor
  NetworkCredentials({
    required this.serviceType,
    required this.host,
    required this.username,
    required this.password,
    this.port,
    this.domain,
    this.additionalOptions,
    DateTime? lastConnected,
  }) : lastConnected = lastConnected ?? DateTime.now();

  // Helper để so sánh host (bỏ qua protocol, port)
  @Transient() // Đánh dấu property này không được lưu trong database
  String get normalizedHost => host
      .replaceAll(RegExp(r'^[a-z]+://'), '') // Bỏ protocol (smb://, ftp://)
      .replaceAll(RegExp(r':\d+$'), ''); // Bỏ port

  // Tạo key duy nhất để tìm kiếm trong database
  @Index()
  String get uniqueKey => '$serviceType:$normalizedHost:$username';
}
