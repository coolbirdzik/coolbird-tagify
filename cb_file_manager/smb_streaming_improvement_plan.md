# Kế hoạch cải thiện tốc độ Streaming Video qua SMB trên Mobile

## 1. Phân tích hiện trạng

- **Vấn đề:** Chức năng streaming video qua giao thức SMB trên nền tảng di động (Android/iOS) hoạt động rất chậm sau khi tải xong chunk dữ liệu đầu tiên. Tốc độ chỉ đạt khoảng 20kb/s, không đủ để xem video mượt mà.
- **Công nghệ:**
  - Sử dụng thư viện `mobile_smb_native` tự phát triển, dựa trên `libsmb2` để tương tác với SMB.
  - Phía Flutter, `StreamingHelper` và `MobileSMBService` là các thành phần chính chịu trách nhiệm cho việc mở và quản lý luồng dữ liệu.
  - Video được phát bằng `media_kit`.
- **Nhận định ban đầu:** Vấn đề không nằm ở kết nối mạng ban đầu (vì chunk đầu tải nhanh), mà nằm ở quá trình đọc dữ liệu liên tục từ stream SMB sau đó. Nguyên nhân có thể do kích thước đọc (read chunk size) quá nhỏ, cơ chế buffering không hiệu quả, hoặc do tương tác giữa tầng Dart và native chưa được tối ưu.

## 2. Nguyên nhân tiềm ẩn

1.  **Kích thước Chunk đọc quá nhỏ:** `mobile_smb_native` có thể đang đọc dữ liệu từ `libsmb2` với từng gói tin rất nhỏ. Mỗi lần đọc đều có độ trễ (network latency, FFI call overhead), nên việc đọc nhiều gói tin nhỏ sẽ cực kỳ chậm.
2.  **Cơ chế Buffering không hiệu quả:** `StreamingHelper` và `NetworkFileCacheService` có thể chưa có cơ chế "đọc trước" (read-ahead) đủ tốt. Luồng dữ liệu có thể chỉ được đọc khi video player yêu cầu, thay vì chủ động lấp đầy một buffer lớn để sẵn sàng cho player.
3.  **Tương tác với thư viện Native (`libsmb2`) chưa tối ưu:** Có khả năng thư viện `libsmb2` chưa được cấu hình để cho phép kích thước đọc/ghi tối đa. `libsmb2` có hàm `smb2_set_max_read_size` để tăng giới hạn này, nhưng có thể nó chưa được gọi trong mã C++.
4.  **Cấu hình Video Player (`media_kit`):** Video player có thể đang yêu cầu các chunk dữ liệu quá nhỏ, hoặc internal buffer của nó quá bé, dẫn đến việc phải yêu cầu dữ liệu liên tục và không hiệu quả.

## 3. Kế hoạch hành động chi tiết

### Bước 1: Tăng kích thước Buffer đọc dữ liệu phía Dart

Đây là giải pháp có thể thực hiện nhanh nhất và có khả năng mang lại hiệu quả tức thì.

- **Hành động:**
  1.  Mở file `lib/services/network_browsing/mobile_smb_service.dart`.
  2.  Tìm đến phương thức `openFileStream`.
  3.  Trong phương thức này, bạn đang gọi `_smbClient.openFileStreamOptimized`. Hãy tăng giá trị của tham số `chunkSize`.
- **Gợi ý:**
  - Giá trị hiện tại có thể là `32 * 1024` (32KB).
  - Hãy thử nghiệm tăng lên các giá trị lớn hơn như `128 * 1024` (128KB), `256 * 1024` (256KB), hoặc thậm chí `1024 * 1024` (1MB).
  - Theo dõi tốc độ stream sau mỗi lần thay đổi để tìm ra giá trị tối ưu.

### Bước 2: Cải thiện cơ chế Buffering và Read-Ahead

Thay vì chỉ đọc dữ liệu khi player cần, chúng ta sẽ tạo một cơ chế đệm chủ động đọc trước dữ liệu.

- **Hành động:**
  1.  Xem xét lại lớp `NetworkFileCacheService` và `StreamingHelper`.
  2.  Triển khai một `CircularBuffer` hoặc một cơ chế tương tự để làm buffer trung gian.
  3.  Tạo một `Isolate` hoặc `Future` chạy nền có nhiệm vụ liên tục đọc dữ liệu từ `mobile_smb_native` (với chunk size lớn đã tăng ở Bước 1) và đổ vào `CircularBuffer`.
  4.  Khi video player yêu cầu dữ liệu, `StreamingHelper` sẽ lấy dữ liệu từ `CircularBuffer` này thay vì gọi trực tiếp xuống native.
- **Lợi ích:** Giảm độ trễ và đảm bảo luôn có sẵn một lượng lớn dữ liệu cho video player, giúp tránh tình trạng "buffering" liên tục.

### Bước 3: Tối ưu hóa phía Native (`mobile_smb_native`)

Đây là bước can thiệp sâu hơn nhưng có thể giải quyết gốc rễ vấn đề.

- **Hành động:**
  1.  Mở mã nguồn C/C++ của thư viện `mobile_smb_native`.
  2.  Trong hàm khởi tạo kết nối SMB, tìm và gọi hàm `smb2_set_max_read_size` và `smb2_set_max_write_size` từ `libsmb2`.
  3.  Đặt giá trị tối đa cho phép, ví dụ: `smb2_set_max_read_size(smb2_context, 1024 * 1024);` // 1MB.
  4.  Kiểm tra lại vòng lặp đọc file trong mã C++. Đảm bảo rằng nó đang yêu cầu đọc một lượng dữ liệu lớn trong mỗi lần gọi `smb2_read`.
- **Lưu ý:** Việc này yêu cầu kiến thức về C++ và FFI (Foreign Function Interface) của Dart.

### Bước 4: Tối ưu hóa cấu hình Video Player (`media_kit`)

Đảm bảo `media_kit` được cấu hình để hoạt động tốt với streaming.

- **Hành động:**
  1.  Xem lại file `lib/ui/components/video_player/custom_video_player.dart` và `lib/services/video_player_optimizer.dart`.
  2.  Khi khởi tạo `Player` của `media_kit`, tìm các tùy chọn liên quan đến kích thước buffer (`buffer-size`, `ring-buffer-size`, v.v.).
  3.  Thử nghiệm tăng kích thước buffer của player lên vài megabytes. Ví dụ: `Player(configuration: PlayerConfiguration(buffer: 10 * 1024 * 1024))`.
- **Mục tiêu:** Giúp player có thể lưu trữ một đoạn video dài hơn, giảm tần suất yêu cầu dữ liệu mới từ stream.

### Bước 5: Tích hợp cơ chế giám sát và đo lường

Sử dụng `StreamingSpeedMonitor` một cách hiệu quả hơn để chẩn đoán chính xác vấn đề.

- **Hành động:**
  1.  Trong `StreamingHelper` hoặc `NetworkFileCacheService`, log lại kích thước của mỗi `chunk` dữ liệu nhận được từ native và thời gian giữa các lần nhận.
  2.  Sử dụng thông tin này để xác định chính xác узкое место (bottleneck) đang nằm ở đâu: do native trả về chunk nhỏ, hay do Dart xử lý chậm.

## 4. Lộ trình thực hiện đề xuất

1.  **Tuần 1:**
    - **Thực hiện Bước 1:** Tăng `chunkSize` trong `mobile_smb_service.dart`. Đây là thay đổi dễ nhất và có khả năng cải thiện tình hình ngay lập tức.
    - **Thực hiện Bước 5:** Tích hợp logging chi tiết để thu thập dữ liệu về tốc độ và kích thước chunk.
2.  **Tuần 2:**
    - **Thực hiện Bước 3:** Can thiệp vào mã C++ của `mobile_smb_native` để gọi `smb2_set_max_read_size`.
3.  **Tuần 3:**
    - **Thực hiện Bước 2:** Triển khai cơ chế read-ahead buffering nếu các bước trên chưa giải quyết triệt để vấn đề.
    - **Thực hiện Bước 4:** Tinh chỉnh cấu hình buffer của `media_kit`.
4.  **Tuần 4:**
    - Kiểm thử (Testing), đo lường hiệu năng và tinh chỉnh lại các tham số (chunk size, buffer size) để đạt được kết quả tốt nhất.

Chúc bạn thành công!