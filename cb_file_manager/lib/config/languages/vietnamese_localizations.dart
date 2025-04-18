import 'app_localizations.dart';

class VietnameseLocalizations implements AppLocalizations {
  @override
  String get appTitle => 'CoolBird - Quản lý Tệp';

  // Common actions
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Hủy';
  @override
  String get save => 'Lưu';
  @override
  String get delete => 'Xóa';
  @override
  String get edit => 'Sửa';
  @override
  String get close => 'Đóng';
  @override
  String get search => 'Tìm kiếm';
  @override
  String get settings => 'Cài đặt';

  // File operations
  @override
  String get copy => 'Sao chép';
  @override
  String get move => 'Di chuyển';
  @override
  String get rename => 'Đổi tên';
  @override
  String get newFolder => 'Thư mục mới';
  @override
  String get properties => 'Thuộc tính';
  @override
  String get openWith => 'Mở bằng';

  // Navigation
  @override
  String get home => 'Trang chủ';
  @override
  String get back => 'Quay lại';
  @override
  String get forward => 'Tiến';
  @override
  String get refresh => 'Làm mới';
  @override
  String get parentFolder => 'Thư mục cha';

  // File types
  @override
  String get image => 'Hình ảnh';
  @override
  String get video => 'Video';
  @override
  String get audio => 'Âm thanh';
  @override
  String get document => 'Tài liệu';
  @override
  String get folder => 'Thư mục';
  @override
  String get file => 'Tệp';

  // Settings
  @override
  String get language => 'Ngôn ngữ';
  @override
  String get theme => 'Giao diện';
  @override
  String get darkMode => 'Chế độ tối';
  @override
  String get lightMode => 'Chế độ sáng';
  @override
  String get systemMode => 'Theo hệ thống';

  // Messages
  @override
  String get fileDeleteConfirmation => 'Bạn có chắc chắn muốn xóa tệp này?';
  @override
  String get folderDeleteConfirmation =>
      'Bạn có chắc chắn muốn xóa thư mục này và tất cả nội dung bên trong?';
  @override
  String get fileDeleteSuccess => 'Đã xóa tệp thành công';
  @override
  String get folderDeleteSuccess => 'Đã xóa thư mục thành công';
  @override
  String get operationFailed => 'Thao tác thất bại';

  // Tags
  @override
  String get tags => 'Thẻ';
  @override
  String get addTag => 'Thêm thẻ';
  @override
  String get removeTag => 'Xóa thẻ';
  @override
  String get tagManagement => 'Quản lý thẻ';

  // Gallery
  @override
  String get imageGallery => 'Thư viện ảnh';
  @override
  String get videoGallery => 'Thư viện video';

  // Storage locations
  @override
  String get local => 'Tệp cục bộ';
  @override
  String get networks => 'Kết nối mạng';
}
