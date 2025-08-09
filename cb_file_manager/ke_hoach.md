Hướng dẫn triển khai SMB File Streaming trong Flutter cho Android và iOS

Để thực hiện streaming file từ SMB server trong Flutter, bạn có nhiều cách tiếp cận khác nhau. Dưới đây là các phương pháp chính và chi tiết cách xử lý ở tầng C++ như VLC:
Các phương pháp chính
1. Sử dụng Package Dart có sẵn

Package smb_connect

là lựa chọn tốt nhất hiện tại:

    Hỗ trợ streaming operation và RandomAccessFile

    Rất nhanh, có thể dùng để stream music và video

    Hỗ trợ SMB 1.0, CIFS, SMB 2.0, SMB 2.1

    Được viết hoàn toàn bằng Dart

dart
final connect = await SmbConnect.connectAuth(
  host: "192.168.1.100",
  domain: "",
  username: "username",
  password: "password",
);

// Stream read
SmbFile file = await connect.file("/music/file.mp3");
Stream<Uint8List> reader = await connect.openRead(file);
reader.listen((event) {
  print("Read: ${event.length}");
});

2. Triển khai tầng C++ với libsmbclient

Để xử lý như VLC, bạn cần tích hợp libsmbclient vào Flutter thông qua FFI:
Bước 1: Tạo wrapper C++

cpp
// smb_client.cpp
#include <libsmbclient.h>
#include <stdint.h>

extern "C" {
    // Authentication callback
    void smb_auth_callback(const char* server, const char* share, 
                          char* workgroup, int wgmaxlen,
                          char* username, int unmaxlen,
                          char* password, int pwmaxlen) {
        // Set authentication credentials
    }
    
    // Initialize SMB client
    int smb_init() {
        return smbc_init(smb_auth_callback, 0);
    }
    
    // Open file for streaming
    int smb_open_file(const char* url) {
        return smbc_open(url, O_RDONLY, 0);
    }
    
    // Read data chunk
    int smb_read_chunk(int fd, uint8_t* buffer, int size) {
        return smbc_read(fd, buffer, size);
    }
    
    // Close file
    int smb_close_file(int fd) {
        return smbc_close(fd);
    }
}

Bước 2: Cấu hình build cho Android

Tạo file android/CMakeLists.txt:

text
cmake_minimum_required(VERSION 3.4.1)

# Add libsmbclient
find_library(smbclient-lib smbclient)

# Create shared library
add_library(smb_flutter SHARED
    ../src/smb_client.cpp
)

target_link_libraries(smb_flutter ${smbclient-lib})

Bước 3: Cấu hình build cho iOS

Trong ios/smb_flutter.podspec:

ruby
Pod::Spec.new do |s|
  s.name             = 'smb_flutter'
  s.version          = '0.0.1'
  s.summary          = 'SMB client for Flutter'
  
  s.dependency 'Flutter'
  s.ios.deployment_target = '9.0'
  
  # Link libsmbclient framework
  s.vendored_frameworks = 'libsmbclient.framework'
  
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
end

Bước 4: Tạo Dart bindings với FFI

dart
// smb_bindings.dart
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef SmbInitC = Int32 Function();
typedef SmbInit = int Function();

typedef SmbOpenFileC = Int32 Function(Pointer<Utf8> url);
typedef SmbOpenFile = int Function(Pointer<Utf8> url);

typedef SmbReadChunkC = Int32 Function(Int32 fd, Pointer<Uint8> buffer, Int32 size);
typedef SmbReadChunk = int Function(int fd, Pointer<Uint8> buffer, int size);

class SmbClient {
  late DynamicLibrary _lib;
  late SmbInit _smbInit;
  late SmbOpenFile _smbOpenFile;
  late SmbReadChunk _smbReadChunk;
  
  SmbClient() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libsmb_flutter.so')
        : DynamicLibrary.open('smb_flutter.framework/smb_flutter');
    
    _smbInit = _lib.lookup<NativeFunction<SmbInitC>>('smb_init').asFunction();
    _smbOpenFile = _lib.lookup<NativeFunction<SmbOpenFileC>>('smb_open_file').asFunction();
    _smbReadChunk = _lib.lookup<NativeFunction<SmbReadChunkC>>('smb_read_chunk').asFunction();
  }
  
  Future<void> initialize() async {
    final result = _smbInit();
    if (result != 0) {
      throw Exception('Failed to initialize SMB client');
    }
  }
  
  Stream<Uint8List> streamFile(String smbUrl) async* {
    final urlPtr = smbUrl.toNativeUtf8();
    final fd = _smbOpenFile(urlPtr);
    
    if (fd < 0) {
      calloc.free(urlPtr);
      throw Exception('Failed to open SMB file');
    }
    
    const chunkSize = 8192;
    final buffer = calloc<Uint8>(chunkSize);
    
    try {
      while (true) {
        final bytesRead = _smbReadChunk(fd, buffer, chunkSize);
        if (bytesRead <= 0) break;
        
        final chunk = Uint8List.fromList(
          buffer.asTypedList(bytesRead)
        );
        yield chunk;
      }
    } finally {
      calloc.free(buffer);
      calloc.free(urlPtr);
    }
  }
}

3. Giải pháp Hybrid với HTTP Proxy

Một cách tiếp cận khác được đề xuất trong

là tạo HTTP proxy trong app:

dart
class SmbHttpProxy {
  late HttpServer _server;
  
  Future<void> start() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    _server.listen(_handleRequest);
  }
  
  void _handleRequest(HttpRequest request) async {
    // Extract SMB path from request
    final smbPath = request.uri.queryParameters['smb_path'];
    
    // Open SMB connection
    final smbFile = await smbConnect.file(smbPath);
    final stream = await smbConnect.openRead(smbFile);
    
    // Stream data as HTTP response
    request.response.headers.contentType = ContentType.binary;
    await request.response.addStream(stream);
    await request.response.close();
  }
  
  String getProxyUrl(String smbPath) {
    return 'http://127.0.0.1:${_server.port}?smb_path=${Uri.encodeComponent(smbPath)}';
  }
}

4. Sử dụng VLC Player Plugin

Với flutter_vlc_player

, bạn có thể stream trực tiếp từ SMB:

dart
class SmbVideoPlayer extends StatefulWidget {
  @override
  _SmbVideoPlayerState createState() => _SmbVideoPlayerState();
}

class _SmbVideoPlayerState extends State<SmbVideoPlayer> {
  late VlcPlayerController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      'smb://username:password@server/share/video.mp4',
      autoPlay: true,
      options: VlcPlayerOptions(
        // Configure SMB options
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(1000),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VlcPlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
      placeholder: Center(child: CircularProgressIndicator()),
    );
  }
}

Lưu ý quan trọng
Permissions và Security

Android:

xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

iOS: Cần thêm vào Info.plist:

xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

Xử lý Authentication

Đối với SMB shares yêu cầu authentication, bạn cần xử lý credentials một cách an toàn:

dart
class SmbCredentials {
  final String username;
  final String password;
  final String domain;
  
  SmbCredentials({
    required this.username,
    required this.password,
    this.domain = '',
  });
}

Khuyến nghị

    Cho phát triển nhanh: Sử dụng package smb_connect

Cho performance cao: Triển khai tầng C++ với libsmbclient

Cho video streaming: Sử dụng flutter_vlc_player

Cho tính ổn định: Kết hợp HTTP proxy approach

Phương pháp C++ sẽ cho performance tốt nhất và linh hoạt như VLC, nhưng yêu cầu setup phức tạp hơn. Package Dart thuần túy sẽ dễ triển khai hơn nhưng có thể có giới hạn về performance.