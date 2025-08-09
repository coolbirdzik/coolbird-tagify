### **Kế hoạch Tái cấu trúc SMB Streaming với `libsmb2`**

**1. Mục tiêu**

*   Thay thế hoàn toàn thư viện SMB tự phát triển ở tầng C++ (`mobile_smb_native`) bằng thư viện `libsmb2` đã được kiểm chứng và ổn định.
*   Sửa lỗi streaming file, đặc biệt là các file lớn, bằng cách triển khai một cơ chế streaming thực sự thay vì đọc toàn bộ file vào bộ nhớ.
*   Cải thiện độ ổn định, hiệu năng và khả năng tương thích của tính năng duyệt file SMB.

**2. Vấn đề hiện tại**

*   Thư viện SMB tự code đang gặp lỗi khi streaming file, gây ra thông báo lỗi và trải nghiệm người dùng kém.
*   Phương thức `readFileData` trong `MobileSMBService` có khả năng đọc toàn bộ file vào bộ nhớ, dẫn đến lỗi "File quá lớn" và tiêu tốn tài nguyên hệ thống.
*   Việc tự phát triển một giao thức phức tạp như SMB dễ phát sinh lỗi và khó bảo trì.

**3. Giải pháp đề xuất**

Chuyển sang sử dụng `libsmb2`, một thư viện C chuyên dụng cho giao thức SMB2/3. Thư viện này cung cấp các API cấp thấp, mạnh mẽ để xử lý kết nối, xác thực và các thao tác file, bao gồm cả việc đọc file theo từng đoạn (chunk-based reading) để streaming hiệu quả.

**4. Kế hoạch chi tiết**

#### **Giai đoạn 1: Tái cấu trúc tầng C++ (Thư viện `mobile_smb_native`)**

1.  **Tích hợp `libsmb2` vào dự án C++:**
    *   Thêm `libsmb2` làm một dependency trong `CMakeLists.txt` (hoặc file build tương đương).
    *   Cấu hình build system để liên kết (link) đúng cách với `libsmb2`.

2.  **Tạo C++ Wrapper cho `libsmb2`:**
    *   Tạo một lớp C++ (ví dụ: `Smb2ClientWrapper`) để đóng gói toàn bộ logic tương tác với `libsmb2`.
    *   Lớp này sẽ quản lý `smb2_context` và các file handle (`smb2fh`).

3.  **Triển khai lại các hàm Native:**
    *   **Kết nối/Ngắt kết nối:** Viết lại hàm `connect` và `disconnect` sử dụng `smb2_connect_share` và `smb2_disconnect_share`.
    *   **Liệt kê thư mục:** Viết lại hàm `listDirectory` sử dụng `smb2_opendir`, `smb2_readdir`, và `smb2_closedir`.
    *   **Thao tác file/thư mục:** Viết lại các hàm `createDirectory`, `deleteFile`, `deleteDirectory`, `rename` sử dụng các hàm tương ứng của `libsmb2` (`smb2_mkdir`, `smb2_unlink`, `smb2_rename`).

4.  **Triển khai Streaming thực sự:**
    *   Tạo hàm `openFile(path)` mới ở tầng C++ để mở một file và trả về một file handle (`smb2fh`).
    *   Tạo hàm `readFile(handle, buffer, size)` để đọc một đoạn dữ liệu (chunk) từ file đã mở vào một buffer.
    *   Tạo hàm `closeFile(handle)` để đóng file handle sau khi đọc xong.

5.  **Cập nhật FFI (Foreign Function Interface):**
    *   Cập nhật các định nghĩa FFI để Dart có thể gọi các hàm C++ mới này, đặc biệt là các hàm `openFile`, `readFile`, và `closeFile`.

#### **Giai đoạn 2: Điều chỉnh tầng Dart (Thư mục `lib`)**

1.  **Cập nhật `mobile_smb_service.dart`:**
    *   Sửa đổi các phương thức hiện có (`connect`, `listDirectory`, `deleteFile`, v.v.) để gọi các hàm FFI mới tương ứng.
    *   **Tái cấu trúc `openFileStream(remotePath)`:**
        1.  Gọi hàm FFI `openFile(path)` để lấy file handle.
        2.  Tạo một `StreamController<List<int>>`.
        3.  Bên trong StreamController, bắt đầu một vòng lặp để liên tục gọi hàm FFI `readFile(handle, ...)` để lấy từng chunk dữ liệu.
        4.  `yield` từng chunk dữ liệu vào stream.
        5.  Khi đọc xong hoặc có lỗi, gọi hàm FFI `closeFile(handle)` và đóng `StreamController`.
    *   **Loại bỏ `readFileData(remotePath)`:** Phương thức này là nguyên nhân chính gây lỗi bộ nhớ. Mọi hoạt động đọc file nên được chuyển qua `openFileStream`.

2.  **Kiểm tra và điều chỉnh `streaming_helper.dart`:**
    *   Đảm bảo `StreamingHelper` có thể hoạt động tốt với stream mới từ `openFileStream`.
    *   Logic kiểm tra kích thước file có thể được giữ lại như một cơ chế phòng vệ, nhưng ngưỡng giới hạn có thể được tăng lên hoặc loại bỏ nếu streaming đã ổn định.

3.  **Kiểm tra các thành phần UI:**
    *   Đảm bảo các màn hình như `SmbVideoPlayerScreen` và các trình xem media khác hoạt động chính xác với stream mới.

#### **Giai đoạn 3: Kiểm thử và Xác thực**

1.  **Kiểm thử Streaming:**
    *   Thử nghiệm streaming các file video và audio có kích thước lớn (vài GB) để xác nhận lỗi bộ nhớ đã được khắc phục.
    *   Kiểm tra tốc độ và độ mượt của streaming.

2.  **Kiểm thử các thao tác file:**
    *   Thực hiện toàn bộ các thao tác: tạo, xóa, đổi tên thư mục và file.
    *   Kiểm tra việc tải file lên và tải file xuống.

3.  **Kiểm thử các trường hợp lỗi:**
    *   Thử kết nối với thông tin sai (sai mật khẩu, sai địa chỉ host).
    *   Thử truy cập vào các đường dẫn không tồn tại.
    *   Kiểm tra khi mất kết nối mạng.

**5. Lợi ích mong đợi**

*   **Streaming ổn định:** Khắc phục hoàn toàn lỗi streaming và lỗi bộ nhớ khi làm việc với file lớn.
*   **Hiệu năng cao hơn:** `libsmb2` được tối ưu hóa cho hiệu năng cao.
*   **Tăng độ tin cậy:** Sử dụng một thư viện đã được cộng đồng kiểm chứng sẽ giảm thiểu lỗi và tăng độ ổn định chung.
*   **Dễ bảo trì:** Code sẽ trở nên gọn gàng và dễ bảo trì hơn khi logic SMB phức tạp được xử lý bởi một thư viện chuyên dụng.
