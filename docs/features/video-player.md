# Video Player Feature Documentation

## Overview

The Video Player feature in cb_file_manager enables users to preview and play video files directly within the application. It supports a wide range of video formats and provides essential playback controls for a seamless user experience.

## Video Player Components

- **Main implementation:**
  - `lib/video_player/video_player_widget.dart`: Widget chính để phát video
  - `lib/video_player/video_controls.dart`: Widget điều khiển phát/tạm dừng, tua, âm lượng, fullscreen
  - `lib/video_player/video_player_service.dart`: Quản lý trạng thái, lifecycle, và các thao tác với player
- **Packages sử dụng:**
  - `video_player`: Hỗ trợ playback cơ bản, đa nền tảng
  - `flutter_vlc_player`: Hỗ trợ nhiều định dạng, stream, phụ đề, tuỳ chọn nâng cao
- **Tính năng chính:**
  - Play, pause, tua (seek), điều chỉnh âm lượng, chuyển đổi fullscreen
  - Hỗ trợ phụ đề (nếu có)
  - Hiển thị thumbnail trước khi phát
  - Tự động phát lại (loop) nếu được cấu hình

## Usage & Integration

- **Tích hợp:**
  - Video player được nhúng trong màn hình xem chi tiết file (`FileDetailScreen`) và màn hình preview nhanh
  - Có thể sử dụng widget `VideoPlayerWidget` như sau:

```dart
import 'package:cb_file_manager/video_player/video_player_widget.dart';

// Trong build method:
VideoPlayerWidget(
	source: VideoSource.file('/path/to/video.mp4'),
	autoPlay: true,
	showControls: true,
)
```

- **Nguồn video hỗ trợ:**
  - File cục bộ (local file)
  - Đường dẫn mạng (HTTP/HTTPS, SMB, FTP nếu được hỗ trợ)
  - Stream nội bộ hoặc từ server

## Error Handling & Logging

- **Các lỗi thường gặp:**
  - Định dạng không hỗ trợ: Hiển thị thông báo "Unsupported format"
  - File không tồn tại hoặc không truy cập được: "File not found or inaccessible"
  - Lỗi khi load hoặc phát video: "Playback error"
- **Xử lý lỗi:**
  - Bắt exception từ player và hiển thị thông báo rõ ràng trên UI
  - Ghi log chi tiết vào hệ thống logging (xem `logging.md`)
  - Gợi ý người dùng kiểm tra lại file hoặc thử định dạng khác

## Performance Optimization

- **Buffering & caching:**
  - Sử dụng preload/buffer để giảm thời gian chờ khi phát
  - Hỗ trợ cache tạm thời cho video stream (nếu backend cho phép)
- **Hardware acceleration:**
  - Ưu tiên sử dụng hardware decoder trên Android/iOS để giảm tải CPU
- **Tối ưu UI:**
  - Ẩn controls khi không thao tác để tăng diện tích xem video
  - Sử dụng thumbnail chất lượng thấp cho preview nhanh
- **Lưu ý:**
  - Kiểm tra memory leak khi chuyển đổi nhiều video liên tục
  - Giải phóng tài nguyên player khi widget bị dispose

## Best Practices

- Kiểm tra sự tồn tại và định dạng file trước khi phát
- Đảm bảo gọi `dispose()` cho controller khi không sử dụng nữa
- Sử dụng try-catch cho mọi thao tác với player
- Test trên nhiều thiết bị, hệ điều hành, và các định dạng video khác nhau
- Đảm bảo UI responsive khi xoay màn hình hoặc chuyển đổi fullscreen

## Testing

- **Unit tests:**
  - Kiểm tra logic của các widget điều khiển (play/pause, seek, volume)
  - Mock player để test các trạng thái (loading, error, playing, paused)
- **Integration tests:**
  - Test luồng phát video thực tế trên thiết bị/thử nghiệm CI
  - Kiểm tra chuyển đổi giữa các nguồn video (local/network)
- **Manual testing:**
  - Thử nghiệm với nhiều định dạng (mp4, mkv, avi, mov...)
  - Test các trường hợp lỗi: file hỏng, file lớn, mạng yếu
  - Kiểm tra UI khi phát, khi lỗi, khi chuyển đổi chế độ fullscreen

## Success Criteria

- Phát video mượt mà, không giật lag với các định dạng phổ biến
- Controls phản hồi nhanh, dễ sử dụng
- Xử lý tốt các trường hợp lỗi, file không hỗ trợ hoặc mất kết nối
- Không rò rỉ bộ nhớ khi chuyển đổi video hoặc thoát màn hình
- UI thích ứng tốt với nhiều kích thước màn hình và trạng thái thiết bị
