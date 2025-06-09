import 'app_localizations.dart';

class VietnameseLocalizations implements AppLocalizations {
  @override
  String get appTitle => 'CoolBird Tagify - Trình Quản Lý Tệp';

  // Common actions
  @override
  String get ok => 'Đồng ý';
  @override
  String get cancel => 'Hủy bỏ';
  @override
  String get save => 'Lưu lại';
  @override
  String get delete => 'Xóa';
  @override
  String get edit => 'Chỉnh sửa';
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
  String get forward => 'Tiến tới';
  @override
  String get refresh => 'Làm mới';
  @override
  String get parentFolder => 'Thư mục chứa';

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
  String get file => 'Tệp tin';

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
  @override
  String get selectLanguage => 'Chọn ngôn ngữ bạn muốn sử dụng';
  @override
  String get selectTheme => 'Chọn giao diện hiển thị cho ứng dụng';
  @override
  String get selectThumbnailPosition =>
      'Chọn vị trí trích xuất hình thu nhỏ video';
  @override
  String get systemThemeDescription => 'Theo cài đặt giao diện của hệ thống';
  @override
  String get lightThemeDescription => 'Giao diện sáng cho tất cả màn hình';
  @override
  String get darkThemeDescription => 'Giao diện tối cho tất cả màn hình';
  @override
  String get vietnameseLanguage => 'Tiếng Việt';
  @override
  String get englishLanguage => 'Tiếng Anh';

  // Messages
  @override
  String get fileDeleteConfirmation =>
      'Bạn có chắc chắn muốn xóa tệp tin này không?';
  @override
  String get folderDeleteConfirmation =>
      'Bạn có chắc chắn muốn xóa thư mục này và tất cả nội dung bên trong không?';
  @override
  String get fileDeleteSuccess => 'Đã xóa tệp tin thành công';
  @override
  String get folderDeleteSuccess => 'Đã xóa thư mục thành công';
  @override
  String get operationFailed => 'Thao tác không thành công';

  // Tags
  @override
  String get tags => 'Thẻ';
  @override
  String get addTag => 'Thêm thẻ';
  @override
  String get removeTag => 'Xóa thẻ';
  @override
  String get tagManagement => 'Quản lý thẻ đánh dấu';
  @override
  String get deleteTagConfirmation => 'Xóa thẻ "%s"?';
  @override
  String get tagDeleteConfirmationText =>
      'Thao tác này sẽ xóa thẻ khỏi tất cả các tệp. Hành động này không thể hoàn tác.';
  @override
  String get tagDeleted => 'Thẻ "%s" đã được xóa thành công';
  @override
  String get errorDeletingTag => 'Lỗi khi xóa thẻ: %s';
  @override
  String get chooseTagColor => 'Chọn màu cho thẻ "%s"';
  @override
  String get tagColorUpdated => 'Màu cho thẻ "%s" đã được cập nhật';
  @override
  String get allTags => 'Tất cả thẻ';
  @override
  String get filesWithTag => 'Tệp có thẻ "%s"';
  @override
  String get tagsInDirectory => 'Thẻ trong "%s"';
  @override
  String get aboutTags => 'Về quản lý thẻ';
  @override
  String get aboutTagsTitle => 'Giới thiệu về quản lý thẻ:';
  @override
  String get aboutTagsDescription =>
      'Thẻ giúp bạn tổ chức tệp bằng cách thêm nhãn tùy chỉnh. '
      'Bạn có thể thêm hoặc xóa thẻ khỏi các tệp, và tìm tất cả các tệp có thẻ cụ thể.';
  @override
  String get aboutTagsScreenDescription =>
      '• Tất cả thẻ trong thư viện của bạn\n'
      '• Các tệp được gắn thẻ đã chọn\n'
      '• Tùy chọn để xóa thẻ';
  @override
  String get deleteTag => 'Xóa thẻ này khỏi tất cả tệp';

  // Gallery
  @override
  String get imageGallery => 'Thư viện ảnh';
  @override
  String get videoGallery => 'Thư viện video';

  // Storage locations
  @override
  String get local => 'Cục bộ';
  @override
  String get networks => 'Mạng';

  // File operations related to networks
  @override
  String get download => 'Tải xuống';
  @override
  String get downloadFile => 'Tải tệp xuống';
  @override
  String get selectDownloadLocation => 'Chọn vị trí lưu tệp:';
  @override
  String get selectFolder => 'Chọn thư mục';
  @override
  String get browse => 'Duyệt...';
  @override
  String get upload => 'Tải lên';
  @override
  String get uploadFile => 'Tải tệp lên';
  @override
  String get selectFileToUpload => 'Chọn tệp để tải lên:';
  @override
  String get create => 'Tạo';
  @override
  String get folderName => 'Tên thư mục';

  // Additional translations for database settings
  @override
  String get databaseSettings => 'Cài đặt cơ sở dữ liệu';
  @override
  String get databaseStorage => 'Lưu trữ cơ sở dữ liệu';
  @override
  String get useObjectBox => 'Sử dụng cơ sở dữ liệu ObjectBox';
  @override
  String get databaseDescription =>
      'Lưu trữ thẻ và tùy chọn trong cơ sở dữ liệu cục bộ';
  @override
  String get jsonStorage => 'Đang sử dụng tệp JSON cho lưu trữ cơ bản';
  @override
  String get objectBoxStorage =>
      'Đang sử dụng ObjectBox cho lưu trữ cơ sở dữ liệu hiệu quả';

  // Cloud sync
  @override
  String get cloudSync => 'Đồng bộ hóa đám mây';
  @override
  String get enableCloudSync => 'Bật đồng bộ hóa đám mây';
  @override
  String get cloudSyncDescription => 'Đồng bộ hóa thẻ và tùy chọn lên đám mây';
  @override
  String get syncToCloud => 'Đồng bộ lên đám mây';
  @override
  String get syncFromCloud => 'Đồng bộ từ đám mây';
  @override
  String get cloudSyncEnabled => 'Thẻ và tùy chọn sẽ được đồng bộ lên đám mây';
  @override
  String get cloudSyncDisabled => 'Đồng bộ hóa đám mây đang tắt';
  @override
  String get enableObjectBoxForCloud =>
      'Bật cơ sở dữ liệu ObjectBox để sử dụng đồng bộ đám mây';

  // Database statistics
  @override
  String get databaseStatistics => 'Thống kê cơ sở dữ liệu';
  @override
  String get totalUniqueTags => 'Tổng số thẻ duy nhất';
  @override
  String get taggedFiles => 'Tệp tin được gắn thẻ';
  @override
  String get popularTags => 'Thẻ phổ biến nhất';
  @override
  String get noTagsFound => 'Không tìm thấy thẻ nào';
  @override
  String get refreshStatistics => 'Làm mới thống kê';

  // Import/Export
  @override
  String get importExportDatabase => 'Nhập/Xuất cơ sở dữ liệu';
  @override
  String get backupRestoreDescription =>
      'Sao lưu và khôi phục thẻ và mối quan hệ tệp tin';
  @override
  String get exportDatabase => 'Xuất cơ sở dữ liệu';
  @override
  String get exportSettings => 'Xuất cài đặt';
  @override
  String get importDatabase => 'Nhập cơ sở dữ liệu';
  @override
  String get importSettings => 'Nhập cài đặt';
  @override
  String get exportDescription => 'Lưu thẻ của bạn vào một tệp tin';
  @override
  String get importDescription => 'Khôi phục thẻ của bạn từ một tệp tin';
  @override
  String get completeBackup => 'Sao lưu toàn bộ';
  @override
  String get completeRestore => 'Khôi phục toàn bộ';
  @override
  String get exportAllData => 'Xuất tất cả cài đặt và dữ liệu cơ sở dữ liệu';
  @override
  String get importAllData => 'Nhập tất cả cài đặt và dữ liệu cơ sở dữ liệu';

  // Export/Import messages
  @override
  String get exportSuccess => 'Đã xuất thành công đến: ';
  @override
  String get exportFailed => 'Xuất không thành công';
  @override
  String get importSuccess => 'Đã nhập thành công';
  @override
  String get importFailed => 'Nhập không thành công hoặc đã hủy';
  @override
  String get importCancelled => 'Đã hủy nhập';
  @override
  String get errorExporting => 'Lỗi khi xuất: ';
  @override
  String get errorImporting => 'Lỗi khi nhập: ';

  // Video thumbnails
  @override
  String get videoThumbnails => 'Hình thu nhỏ video';
  @override
  String get thumbnailPosition => 'Vị trí hình thu nhỏ:';
  @override
  String get percentOfVideo => 'phần trăm của video';
  @override
  String get thumbnailDescription =>
      'Đặt vị trí trong video (tính bằng phần trăm tổng thời lượng) nơi hình thu nhỏ sẽ được trích xuất';
  @override
  String get thumbnailCache => 'Bộ nhớ đệm hình thu nhỏ';
  @override
  String get thumbnailCacheDescription =>
      'Hình thu nhỏ video được lưu trong bộ nhớ đệm để cải thiện hiệu suất. Nếu hình thu nhỏ xuất hiện lỗi thời hoặc bạn muốn giải phóng dung lượng, bạn có thể xóa bộ nhớ đệm.';
  @override
  String get clearThumbnailCache => 'Xóa bộ nhớ đệm hình thu nhỏ';
  @override
  String get clearing => 'Đang xóa...';
  @override
  String get thumbnailCleared => 'Đã xóa tất cả hình thu nhỏ video';
  @override
  String get errorClearingThumbnail => 'Lỗi khi xóa hình thu nhỏ: ';

  // New tab
  @override
  String get newTab => 'Thẻ mới';

  // Admin access
  @override
  String get adminAccess => 'Yêu cầu quyền quản trị';
  @override
  String get adminAccessRequired =>
      'Ổ đĩa này yêu cầu quyền quản trị để truy cập';

  // File system
  @override
  String get drives => 'Ổ đĩa';
  @override
  String get system => 'Hệ thống';

  // Settings data
  @override
  String get settingsData => 'Dữ liệu cài đặt';
  @override
  String get viewManageSettings => 'Xem và quản lý dữ liệu cài đặt';

  // About app
  @override
  String get aboutApp => 'Thông tin ứng dụng';
  @override
  String get appDescription => 'Trình quản lý tệp mạnh mẽ với khả năng gắn thẻ';
  @override
  String get version => 'Phiên bản: 1.0.0';
  @override
  String get developer => 'Phát triển bởi CoolBird Team';

  // Empty state
  @override
  String get emptyFolder => 'Thư mục trống';
  @override
  String get noImagesFound => 'Không tìm thấy hình ảnh trong thư mục này';
  @override
  String get noVideosFound => 'Không tìm thấy video trong thư mục này';
  @override
  String get loading => 'Đang tải thông tin...';

  // File details
  @override
  String get fileSize => 'Kích thước';
  @override
  String get fileLocation => 'Vị trí';
  @override
  String get fileCreated => 'Tạo lúc';
  @override
  String get fileModified => 'Sửa lúc';
  @override
  String get loadingVideo => 'Đang tải video...';
  @override
  String get errorLoadingImage => 'Lỗi khi tải hình ảnh';
  @override
  String get createCopy => 'Tạo bản sao';
  @override
  String get deleteFile => 'Xóa tệp';

  // File picker dialogs
  @override
  String get chooseBackupLocation => 'Chọn vị trí lưu bản sao lưu';
  @override
  String get chooseRestoreLocation => 'Chọn tệp sao lưu để khôi phục';
  @override
  String get saveSettingsExport => 'Lưu xuất cài đặt';
  @override
  String get saveDatabaseExport => 'Lưu xuất cơ sở dữ liệu';
  @override
  String get selectBackupFolder => 'Chọn thư mục sao lưu để nhập';

  // Sorting
  @override
  String get sort => 'Sắp xếp';
  @override
  String get sortByName => 'Sắp xếp theo tên';
  @override
  String get sortByPopularity => 'Sắp xếp theo độ phổ biến';
  @override
  String get sortByRecent => 'Sắp xếp theo gần đây';
  @override
  String get sortBySize => 'Sắp xếp theo kích thước';
  @override
  String get sortByDate => 'Sắp xếp theo ngày';

  // Search errors
  @override
  String noFilesFoundTag(Map<String, String> args) =>
      'Không tìm thấy tệp nào có tag "${args['tag']}"';

  @override
  String noFilesFoundTagGlobal(Map<String, String> args) =>
      'Không tìm thấy tệp nào có tag "${args['tag']}" trên toàn hệ thống';

  @override
  String noFilesFoundTags(Map<String, String> args) =>
      'Không tìm thấy tệp nào có các tag ${args['tags']}';

  @override
  String noFilesFoundTagsGlobal(Map<String, String> args) =>
      'Không tìm thấy tệp nào có các tag ${args['tags']} trên toàn hệ thống';

  @override
  String errorSearchTag(Map<String, String> args) =>
      'Lỗi khi tìm kiếm theo tag: ${args['error']}';

  @override
  String errorSearchTagGlobal(Map<String, String> args) =>
      'Lỗi khi tìm kiếm theo tag trên toàn hệ thống: ${args['error']}';

  @override
  String errorSearchTags(Map<String, String> args) =>
      'Lỗi khi tìm kiếm với nhiều tag: ${args['error']}';

  @override
  String errorSearchTagsGlobal(Map<String, String> args) =>
      'Lỗi khi tìm kiếm với nhiều tag trên toàn hệ thống: ${args['error']}';

  // Search status
  @override
  String searchingTag(Map<String, String> args) =>
      'Đang tìm kiếm tag "${args['tag']}"...';

  @override
  String searchingTagGlobal(Map<String, String> args) =>
      'Đang tìm kiếm tag "${args['tag']}" trên toàn hệ thống...';

  @override
  String searchingTags(Map<String, String> args) =>
      'Đang tìm kiếm các tag ${args['tags']}...';

  @override
  String searchingTagsGlobal(Map<String, String> args) =>
      'Đang tìm kiếm các tag ${args['tags']} trên toàn hệ thống...';

  // Search UI
  @override
  String get searchTips => 'Mẹo tìm kiếm';

  @override
  String get searchTipsTitle => 'Mẹo tìm kiếm';

  @override
  String get viewTagSuggestions => 'Xem gợi ý tag';

  @override
  String get globalSearchModeEnabled => 'Đã chuyển sang tìm kiếm toàn cục';

  @override
  String get localSearchModeEnabled =>
      'Đã chuyển sang tìm kiếm thư mục hiện tại';

  @override
  String get globalSearchMode => 'Đang tìm kiếm toàn cục (nhấn để chuyển)';

  @override
  String get localSearchMode =>
      'Đang tìm kiếm thư mục hiện tại (nhấn để chuyển)';

  @override
  String get searchByFilename => 'Tìm theo tên tệp';

  @override
  String get searchByTags => 'Tìm theo tag';

  @override
  String get searchMultipleTags => 'Tìm nhiều tag';

  @override
  String get globalSearch => 'Tìm kiếm toàn cục';

  @override
  String get searchShortcuts => 'Phím tắt';

  @override
  String get searchHintText => 'Tìm kiếm tệp hoặc dùng # để tìm theo tag';

  @override
  String get searchHintTextTags => 'Tìm theo tag... (ví dụ: #important #work)';

  @override
  String get suggestedTags => 'Tags gợi ý';

  @override
  String get noMatchingTags => 'Không tìm thấy tag phù hợp';

  @override
  String get results => 'kết quả';

  @override
  String get searchByFilenameDesc => 'Nhập tên tệp để tìm kiếm.';

  @override
  String get searchByTagsDesc =>
      'Sử dụng ký hiệu # để tìm theo tag. Ví dụ: #important';

  @override
  String get searchMultipleTagsDesc =>
      'Sử dụng nhiều tag cùng lúc để lọc kết quả chính xác hơn. Mỗi tag cần có ký tự # ở đầu và phải cách nhau bởi khoảng trắng. Ví dụ: #work #urgent #2023';

  @override
  String get globalSearchDesc =>
      'Bấm vào biểu tượng thư mục/toàn cầu để chuyển đổi giữa tìm kiếm thư mục hiện tại và toàn hệ thống.';

  @override
  String get searchShortcutsDesc =>
      'Nhấn Enter để bắt đầu tìm kiếm. Dùng phím mũi tên để chọn tag từ gợi ý.';
}
