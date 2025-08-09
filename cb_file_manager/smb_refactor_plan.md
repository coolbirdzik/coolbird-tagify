# Kế hoạch Chi tiết Refactor SMB cho Mobile

---

#### **Mục tiêu chính:**
Xây dựng lại `MobileSMBService` để hỗ trợ streaming file (video/audio) một cách hiệu quả, giảm độ trễ và tối ưu hóa việc sử dụng bộ nhớ bằng cách đọc file theo từng đoạn (chunk) thay vì tải toàn bộ file vào bộ nhớ.

---

### **Giai đoạn 1: Nền tảng Native và Cầu nối FFI**

Đây là giai đoạn quan trọng nhất, tập trung vào việc xây dựng lõi xử lý native.

1.  **Tích hợp `libsmbclient` vào Native Plugin:**
    *   **Phân tích:** `libsmbclient` là một thư viện C mạnh mẽ, cung cấp đầy đủ các hàm để tương tác với SMB. Đây là lựa chọn tối ưu cho hiệu năng.
    *   **Thực thi:**
        *   **Android:** Cấu hình `CMakeLists.txt` trong thư mục `android` của plugin `mobile_smb_native` để biên dịch `libsmbclient` từ mã nguồn hoặc liên kết với thư viện đã được biên dịch sẵn (`.a` hoặc `.so`).
        *   **iOS:** Tạo một `Podspec` cho `mobile_smb_native` để tự động tải và liên kết `libsmbclient` thông qua CocoaPods, hoặc tích hợp thư viện đã được biên dịch sẵn dưới dạng `XCFramework`.

2.  **Xây dựng C++ Wrapper:**
    *   **Phân tích:** Tạo một lớp C++ wrapper (`smb_client.cpp` như trong `ke_hoach.md`) để làm trung gian, giúp mã Dart giao tiếp với `libsmbclient` một cách an toàn và dễ dàng.
    *   **Thực thi:** Triển khai các hàm C++ để thực hiện các tác vụ sau:
        *   `smb_init()`: Khởi tạo và cấu hình `libsmbclient`.
        *   `smb_connect(host, username, password, domain)`: Thực hiện kết nối và xác thực.
        *   `smb_list_directory(path)`: Liệt kê nội dung thư mục. Hàm này sẽ trả về một con trỏ tới danh sách các cấu trúc `NativeFileInfo` (chứa tên, kích thước, loại file).
        *   `smb_get_file_info(path)`: Lấy thông tin chi tiết của một file/thư mục.
        *   `smb_open_file(path)`: Mở một file và trả về một file handle (dạng số nguyên hoặc con trỏ).
        *   `smb_read_chunk(handle, buffer, size)`: **Hàm cốt lõi cho streaming**. Đọc một đoạn dữ liệu từ file handle vào một buffer được cấp phát.
        *   `smb_seek_file(handle, offset, whence)`: Di chuyển con trỏ đọc trong file, cực kỳ quan trọng cho việc tua video.
        *   `smb_close_file(handle)`: Đóng file handle khi không sử dụng nữa.
        *   `smb_free_...()`: Các hàm tiện ích để giải phóng bộ nhớ được cấp phát bởi C++ (ví dụ: `smb_free_file_list`).

3.  **Tạo Dart FFI Bindings:**
    *   **Phân tích:** Sử dụng `dart:ffi` để tạo cầu nối giữa mã Dart và các hàm C++ đã viết.
    *   **Thực thi:** Trong `lib/services/network_browsing/smb_native_bindings.dart` (tạo file mới nếu cần):
        *   Định nghĩa các `typedef` cho mỗi hàm C++, ánh xạ các kiểu dữ liệu C (ví dụ: `Int32`, `Pointer<Utf8>`) sang các kiểu Dart tương ứng.
        *   Sử dụng `DynamicLibrary.open()` để load thư viện native.
        *   Sử dụng `lookup<T>()` để lấy tham chiếu đến các hàm C++ và ép kiểu chúng thành các hàm Dart.

---

### **Giai đoạn 2: Tích hợp vào Logic của Ứng dụng**

Sau khi có nền tảng native vững chắc, chúng ta sẽ tích hợp nó vào logic hiện có của ứng dụng.

4.  **Refactor `MobileSMBService`:**
    *   **Phân tích:** Đây là lớp logic chính cần được viết lại. Nó sẽ không còn sử dụng `MobileSmbClient` cũ mà sẽ gọi trực tiếp các hàm FFI đã tạo.
    *   **Thực thi:** Trong `lib/services/network_browsing/mobile_smb_service.dart`:
        *   **`connect()`**: Gọi hàm `smb_connect()` từ FFI.
        *   **`listDirectory()`**: Gọi `smb_list_directory()`, sau đó duyệt qua con trỏ kết quả, chuyển đổi từng `NativeFileInfo` thành `Directory` hoặc `File` của Dart và giải phóng bộ nhớ native.
        *   **`getFileSize()`**: Gọi `smb_get_file_info()` để lấy kích thước file.
        *   **`openFileStream()`**: Đây là thay đổi quan trọng nhất.
            *   Gọi `smb_open_file()` để lấy file handle.
            *   Tạo một `StreamController<List<int>>`.
            *   Trong callback `onListen` của stream, bắt đầu một vòng lặp `while` để liên tục gọi `smb_read_chunk()`.
            *   Với mỗi chunk dữ liệu đọc được, `add()` nó vào stream controller.
            *   Khi đọc hết file hoặc có lỗi, đóng stream.
            *   Trong callback `onCancel`, đảm bảo gọi `smb_close_file()` để tránh rò rỉ tài nguyên.
            *   Trả về `controller.stream`.

5.  **Cập nhật `StreamingHelper` và `NetworkThumbnailHelper`:**
    *   **Phân tích:** Các lớp helper này cần được điều chỉnh để hoạt động với luồng streaming mới.
    *   **Thực thi:**
        *   Trong `StreamingHelper`, loại bỏ hoàn toàn logic tạm thời sử dụng `readFileData()`. Luồng xử lý giờ đây sẽ luôn tin tưởng vào `openFileStream()` vì nó đã là một giải pháp streaming thực thụ.
        *   Trong `NetworkThumbnailHelper`, khi tạo thumbnail cho file SMB trên mobile, nó sẽ gián tiếp sử dụng `openFileStream` mới (thông qua các lớp service) để đọc một phần đầu của file ảnh/video, giúp tạo thumbnail nhanh hơn và hiệu quả hơn.

---

### **Giai đoạn 3: Kiểm thử và Hoàn thiện**

6.  **Kiểm thử toàn diện:**
    *   **Biên dịch:** Đảm bảo `build.gradle` (Android) và `Podfile` (iOS) được cấu hình chính xác để biên dịch và liên kết `libsmbclient`.
    *   **Chức năng:**
        *   Kiểm tra kết nối tới các loại server SMB khác nhau.
        *   Kiểm tra việc duyệt thư mục, bao gồm cả các thư mục có tên chứa ký tự đặc biệt.
        *   **Kiểm tra streaming:** Mở các file video có kích thước khác nhau. Thử tua (seek) tới các vị trí khác nhau để đảm bảo `smb_seek_file` hoạt động đúng.
    *   **Hiệu năng:** Sử dụng Flutter DevTools để theo dõi việc sử dụng bộ nhớ và CPU, đảm bảo không có hiện tượng rò rỉ bộ nhớ (memory leak) từ lớp native.
