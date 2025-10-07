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
  @override
  String get deleteAlbum => 'Xóa Album';

  // Tag Management Screen
  @override
  String get tagManagementTitle => 'Quản lý Tags';
  @override
  String get debugTags => 'Debug Tags';
  @override
  String get searchTags => 'Tìm kiếm';
  @override
  String get searchTagsHint => 'Tìm kiếm thẻ...';
  @override
  String get createNewTag => 'Tạo thẻ mới';
  @override
  String get newTagTooltip => 'Tạo thẻ mới';
  @override
  String get errorLoadingTags => 'Lỗi khi tải thẻ: ';
  @override
  String get noTagsFoundMessage => 'Không tìm thấy thẻ nào';
  @override
  String get noTagsFoundDescription => 'Tạo thẻ mới để bắt đầu phân loại tệp';
  @override
  String get createNewTagButton => 'Tạo thẻ mới';
  @override
  String get noMatchingTagsMessage =>
      'Không có thẻ nào phù hợp với "\${searchTags}"';
  @override
  String get clearSearch => 'Xóa tìm kiếm';
  @override
  String get tagManagementHeader => 'Quản lý thẻ';
  @override
  String get tagsCreated => 'thẻ đã tạo';
  @override
  String get tagManagementDescription =>
      'Nhấn vào thẻ để xem tất cả tệp có gắn thẻ đó. Sử dụng các nút bên phải để thay đổi màu hoặc xóa thẻ.';
  @override
  String get sortTags => 'Sắp xếp thẻ';
  @override
  String get sortByAlphabet => 'Theo bảng chữ cái';
  @override
  String get sortByPopular => 'Theo phổ biến';
  @override
  String get listViewMode => 'Chế độ danh sách';
  @override
  String get gridViewMode => 'Chế độ lưới';
  @override
  String get previousPage => 'Trang trước';
  @override
  String get nextPage => 'Trang sau';
  @override
  String get page => 'Trang';
  @override
  String get firstPage => 'Trang đầu';
  @override
  String get lastPage => 'Trang cuối';
  @override
  String get clickToViewFiles => 'Nhấn để xem tệp';
  @override
  String get changeTagColor => 'Thay đổi màu sắc';
  @override
  String get deleteTagFromAllFiles => 'Xóa thẻ này khỏi tất cả tệp';
  @override
  String get openInNewTab => 'Mở trong tab mới';
  @override
  String get changeColor => 'Thay đổi màu';
  @override
  String get noFilesWithTag => 'Không tìm thấy tệp nào có thẻ này';
  @override
  String get debugInfo => 'Thông tin gỡ lỗi: đang tìm thẻ "\${tag}"';
  @override
  String get backToAllTags => 'Quay về tất cả thẻ';
  @override
  String get tryAgain => 'Thử lại';
  @override
  String get filesWithTagCount => 'tệp';
  @override
  String get viewDetails => 'Xem chi tiết';
  @override
  String get openContainingFolder => 'Mở thư mục chứa';
  @override
  String get editTags => 'Chỉnh sửa thẻ';
  @override
  String get newTagTitle => 'Tạo thẻ mới';
  @override
  String get enterTagName => 'Nhập tên thẻ...';
  @override
  String get tagAlreadyExists => 'Thẻ "\${tagName}" đã tồn tại';
  @override
  String get tagCreatedSuccessfully => 'Đã tạo thẻ "\${tagName}" thành công';
  @override
  String get errorCreatingTag => 'Lỗi khi tạo thẻ: ';
  @override
  String get openingFolder => 'Opening folder: ';
  @override
  String get folderNotFound => 'Folder not found: ';

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
  String get developer => 'Phát triển bởi CoolBird - ngtanhung41@gmail.com';

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

  // Permissions
  @override
  String get grantPermissionsToContinue => 'Cấp quyền để tiếp tục';

  @override
  String get permissionsDescription =>
      'Để sử dụng ứng dụng mượt mà, vui lòng cấp các quyền sau đây. Bạn có thể bỏ qua và cấp sau trong Cài đặt.';

  @override
  String get storagePhotosPermission => 'Quyền lưu trữ/ảnh';

  @override
  String get storagePhotosDescription =>
      'Ứng dụng cần quyền truy cập Ảnh/Tệp để hiển thị và phát nội dung cục bộ.';

  @override
  String get allFilesAccessPermission => 'Truy cập tất cả files (Quan trọng)';

  @override
  String get allFilesAccessDescription =>
      'Cần quyền này để hiển thị đầy đủ tất cả files bao gồm APK, documents và các file khác trong thư mục Download.';

  @override
  String get installPackagesPermission => 'Cài đặt gói (APK)';

  @override
  String get installPackagesDescription =>
      'Cần quyền này để mở và cài đặt các file APK thông qua Package Installer.';

  @override
  String get localNetworkPermission => 'Mạng cục bộ';

  @override
  String get localNetworkDescription =>
      'Cho phép truy cập mạng nội bộ để duyệt SMB/NAS trong cùng mạng.';

  @override
  String get notificationsPermission => 'Thông báo (tùy chọn)';

  @override
  String get notificationsDescription =>
      'Bật thông báo để nhận cập nhật phát và tác vụ nền.';

  @override
  String get grantAllPermissions => 'Cấp toàn bộ quyền';

  @override
  String get grantingPermissions => 'Đang cấp quyền...';

  @override
  String get enterApp => 'Vào app';

  @override
  String get skipEnterApp => 'Bỏ qua, vào app';

  @override
  String get granted => 'Đã cấp';

  @override
  String get grantPermission => 'Cấp quyền';

  // Home screen
  @override
  String get welcomeToFileManager => 'Chào mừng đến với CoolBird File Manager';

  @override
  String get welcomeDescription => 'Trợ lý quản lý tệp mạnh mẽ của bạn';

  @override
  String get quickActions => 'Thao tác nhanh';

  @override
  String get browseFiles => 'Duyệt tệp';

  @override
  String get browseFilesDescription => 'Khám phá các tệp và thư mục cục bộ';

  @override
  String get manageMedia => 'Quản lý phương tiện';

  @override
  String get manageMediaDescription => 'Xem hình ảnh và video trong thư viện';

  @override
  String get tagFiles => 'Gắn thẻ tệp';

  @override
  String get tagFilesDescription => 'Tổ chức tệp bằng thẻ thông minh';

  @override
  String get networkAccess => 'Truy cập mạng';

  @override
  String get networkAccessDescription => 'Duyệt ổ đĩa và chia sẻ mạng';

  @override
  String get keyFeatures => 'Tính năng chính';

  @override
  String get fileManagement => 'Quản lý tệp';

  @override
  String get fileManagementDescription =>
      'Duyệt và tổ chức tệp một cách dễ dàng';

  @override
  String get smartTagging => 'Gắn thẻ thông minh';

  @override
  String get smartTaggingDescription =>
      'Gắn thẻ tệp để tìm kiếm nhanh như chớp';

  @override
  String get mediaGallery => 'Thư viện phương tiện';

  @override
  String get mediaGalleryDescription => 'Thư viện đẹp cho hình ảnh và video';

  @override
  String get networkSupport => 'Hỗ trợ mạng';

  @override
  String get networkSupportDescription => 'Truy cập liền mạch vào ổ đĩa mạng';

  // Settings screen
  @override
  String get interface => 'Giao diện';

  @override
  String get selectInterfaceTheme => 'Chọn giao diện và màu sắc yêu thích';

  @override
  String get chooseInterface => 'Chọn giao diện';

  @override
  String get interfaceDescription => 'Nhiều màu sắc và kiểu dáng khác nhau';

  @override
  String get showFileTags => 'Hiển thị tag của file';

  @override
  String get showFileTagsDescription =>
      'Hiển thị các tag của file bên ngoài danh sách file trong tất cả các chế độ xem';

  @override
  String get showFileTagsToggle => 'Hiển thị tag của file';

  @override
  String get showFileTagsToggleDescription =>
      'Bật/tắt hiển thị tag bên ngoài danh sách file';

  @override
  String get cacheManagement => 'Quản lý bộ nhớ cache';

  @override
  String get cacheManagementDescription =>
      'Xóa dữ liệu cache để giải phóng bộ nhớ';

  @override
  String get cacheFolder => 'Thư mục cache:';

  @override
  String get networkThumbnails => 'Thumbnail mạng:';

  @override
  String get videoThumbnailsCache => 'Thumbnail video:';

  @override
  String get tempFiles => 'File tạm:';

  @override
  String get notInitialized => 'Chưa khởi tạo';

  @override
  String get refreshCacheInfo => 'Làm mới';

  @override
  String get cacheInfoUpdated => 'Đã cập nhật thông tin cache';

  @override
  String get clearVideoThumbnailsCache => 'Xóa cache video thumbnails';

  @override
  String get clearVideoThumbnailsDescription =>
      'Xóa các thumbnail video đã tạo';

  @override
  String get clearNetworkThumbnailsCache => 'Xóa cache SMB/network thumbnails';

  @override
  String get clearNetworkThumbnailsDescription =>
      'Xóa các thumbnail mạng đã tạo';

  @override
  String get clearTempFilesCache => 'Xóa các file tạm';

  @override
  String get clearTempFilesDescription => 'Xóa file tạm từ chia sẻ mạng';

  @override
  String get clearAllCache => 'Xóa tất cả cache';

  @override
  String get clearAllCacheDescription => 'Xóa tất cả dữ liệu cache';

  @override
  String get videoCacheCleared => 'Đã xóa cache thumbnails video';

  @override
  String get networkCacheCleared => 'Đã xóa cache thumbnails mạng';

  @override
  String get tempFilesCleared => 'Đã xóa các file tạm';

  @override
  String get allCacheCleared => 'Đã xóa tất cả dữ liệu cache';

  @override
  String get errorClearingCache => 'Lỗi: ';

  @override
  String get processing => 'Đang xử lý...';

  @override
  String get regenerateThumbnailsWithNewPosition =>
      'Tạo lại thumbnail với vị trí mới';

  @override
  String get thumbnailPositionUpdated =>
      'Đã xóa cache và sẽ tạo lại thumbnail với vị trí ';

  @override
  String get fileTagsEnabled => 'Đã bật hiển thị tag của file';

  @override
  String get fileTagsDisabled => 'Đã tắt hiển thị tag của file';

  // System screen router
  @override
  String get unknownSystemPath => 'Đường dẫn hệ thống không xác định';

  @override
  String get ftpConnectionRequired => 'Cần kết nối FTP';

  @override
  String get ftpConnectionDescription =>
      'Bạn cần kết nối đến máy chủ FTP trước.';

  @override
  String get goToFtpConnections => 'Đi đến kết nối FTP';

  @override
  String get cannotOpenNetworkPath => 'Không thể mở đường dẫn mạng';

  @override
  String get goBack => 'Quay lại';

  @override
  String get tagPrefix => 'Tag';

  // Network browsing
  @override
  String get ftpConnections => 'Kết nối FTP';

  @override
  String get smbNetwork => 'Mạng SMB';

  @override
  String get refreshData => 'Làm mới';

  @override
  String get addConnection => 'Thêm kết nối';

  @override
  String get noFtpConnections => 'Không có kết nối FTP nào.';

  @override
  String get activeConnections => 'Kết nối đang hoạt động';

  @override
  String get savedConnections => 'Kết nối đã lưu';

  @override
  String get connecting => 'Đang kết nối';

  @override
  String get connect => 'Kết nối';

  @override
  String get unknown => 'Không xác định';

  @override
  String get connectionError => 'Lỗi kết nối';

  @override
  String get loadCredentialsError => 'Lỗi khi tải thông tin đăng nhập đã lưu';

  @override
  String get networkScanFailed => 'Quét mạng thất bại';

  @override
  String get smbVersionUnknown => 'Không xác định';

  @override
  String get connectionInfoUnavailable => 'Thông tin kết nối không khả dụng';

  @override
  String get networkSettingsOpened => 'Đã mở cài đặt mạng';

  @override
  String get cannotOpenNetworkSettings =>
      'Không thể mở cài đặt mạng, vui lòng mở thủ công';

  @override
  String get networkDiscoveryDisabled => 'Khám phá mạng có thể chưa được bật';

  @override
  String get networkDiscoveryDescription =>
      'Bật khám phá mạng trong cài đặt Windows để quét máy chủ SMB';

  @override
  String get openSettings => 'Mở cài đặt';

  @override
  String get activeConnectionsTitle => 'Kết nối đang hoạt động';

  @override
  String get activeConnectionsDescription => 'Máy chủ SMB bạn đang kết nối';

  @override
  String get discoveredSmbServers => 'Máy chủ SMB đã khám phá';

  @override
  String get discoveredSmbServersDescription =>
      'Máy chủ được khám phá trên mạng cục bộ';

  @override
  String get noActiveSmbConnections => 'Không có kết nối SMB đang hoạt động';

  @override
  String get connectToSmbServer => 'Kết nối đến máy chủ SMB để xem tại đây';

  @override
  String get connected => 'Đã kết nối';

  @override
  String get openConnection => 'Mở kết nối';

  @override
  String get disconnect => 'Ngắt kết nối';

  @override
  String get scanningForSmbServers => 'Đang quét máy chủ SMB...';

  @override
  String get devicesWillAppear =>
      'Thiết bị sẽ xuất hiện ở đây khi được khám phá';

  @override
  String get scanningMayTakeTime => 'Quá trình này có thể mất vài phút';

  @override
  String get noSmbServersFound => 'Không tìm thấy máy chủ SMB nào';

  @override
  String get tryScanningAgain => 'Thử quét lại hoặc kiểm tra cài đặt mạng';

  @override
  String get scanAgain => 'Quét lại';

  @override
  String get readyToScan => 'Sẵn sàng quét';

  @override
  String get clickRefreshToScan =>
      'Nhấp nút làm mới để bắt đầu quét máy chủ SMB';

  @override
  String get startScan => 'Bắt đầu quét';

  @override
  String get foundDevices => 'Tìm thấy';

  @override
  String get scanning => 'Đang quét...';

  @override
  String get scanComplete => 'Quét hoàn tất';

  @override
  String get smbVersion => 'Phiên bản SMB';

  @override
  String get netbios => 'NetBIOS';

  // Drawer menu items
  @override
  String get networksMenu => 'Mạng';

  @override
  String get networkTab => 'Mạng';

  @override
  String get about => 'Giới thiệu';

  // Tab manager
  @override
  String get newTabButton => 'Tab mới';

  @override
  String get openNewTabToStart => 'Mở tab mới để bắt đầu';

  // Home screen
  @override
  String get welcomeTitle => 'Chào mừng đến với CoolBird Tagify';

  @override
  String get welcomeSubtitle => 'Trợ lý quản lý tệp mạnh mẽ của bạn';

  @override
  String get quickActionsTip =>
      'Mẹo: Sử dụng các hành động nhanh bên dưới để bắt đầu nhanh chóng';

  @override
  String get quickActionsHome => 'Hành động nhanh';

  @override
  String get startHere => 'Bắt đầu tại đây';

  @override
  String get newTabAction => 'Tab mới';

  @override
  String get newTabActionDesc => 'Mở tab trình duyệt tệp mới';

  @override
  String get tagsAction => 'Thẻ';

  @override
  String get tagsActionDesc => 'Tổ chức với thẻ thông minh';

  @override
  String get imageGalleryTab => 'Thư viện ảnh';

  @override
  String get videoGalleryTab => 'Thư viện video';

  @override
  String get drivesTab => 'Ổ đĩa';

  @override
  String get browseTab => 'Duyệt';

  @override
  String get documentsTab => 'Tài liệu';

  @override
  String get homeTab => 'Trang chủ';

  @override
  String get internalStorage => 'Bộ nhớ trong';

  @override
  String get storagePrefix => 'Bộ nhớ';

  @override
  String get rootFolder => 'Thư mục gốc';
}
