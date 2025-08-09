# mobile_smb_native

A high-performance Flutter plugin for SMB/CIFS file operations using libsmb2 and Dart FFI.

## Features

- **High-performance SMB streaming** using libsmb2
- **Direct memory access** via Dart FFI
- **Cross-platform support** (Windows, Linux, macOS)
- **Real-time file streaming** without loading entire files into memory
- **Directory browsing** and file operations
- **Video thumbnail generation** (stub implementation)

## Architecture

This plugin uses a native C++ implementation with libsmb2 for SMB operations, connected to Dart via FFI for maximum performance.

### Native Layer
- **libsmb2**: Modern SMB client library
- **C++ wrapper**: Provides a clean interface for Dart FFI
- **CMake build system**: Cross-platform build configuration

### Dart Layer
- **FFI bindings**: Direct native function calls
- **Streaming API**: Memory-efficient file streaming
- **Service layer**: High-level API for SMB operations

## Platform Support

| Platform | Support | Status | Implementation |
|----------|---------|--------|----------------|
| Windows  | ✅       | Primary target | Full libsmb2 |
| Linux    | ✅       | Supported | Full libsmb2 |
| macOS    | ✅       | Supported | Full libsmb2 |
| Android  | 🚧       | Stub implementation | Limited functionality |
| iOS      | 🚧       | Stub implementation | Limited functionality |
| Web      | ❌       | Not applicable | N/A |

### Platform-Aware Usage

The plugin automatically detects platform capabilities and provides graceful fallbacks:

```dart
import 'package:mobile_smb_native/mobile_smb_native.dart';

// Use SmbPlatformService for automatic platform handling
final smbService = SmbPlatformService.instance;

// Check platform capabilities
final status = smbService.getPlatformStatus();
print('Platform: ${status['platform']}');
print('Native Available: ${status['nativeAvailable']}');
print('Support Level: ${status['supportLevel']}');

// Handle platform limitations
if (!smbService.isNativeAvailable) {
  print('Limited functionality: ${smbService.getPlatformErrorMessage()}');
  // Show appropriate UI or fallback behavior
}

// Safe operations that handle platform differences
if (await smbService.connect(config)) {
  final files = await smbService.listDirectory('/path');
  // Process files...
}
```

## Building

### Prerequisites

1. **Install vcpkg** (Windows):
   ```bash
   git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
   cd C:\vcpkg
   .\bootstrap-vcpkg.bat
   ```

2. **Install libsmb2**:
   ```bash
   .\vcpkg install libsmb2:x64-windows
   ```

3. **Build the native library**:
   ```bash
   cd mobile_smb_native
   .\build_native.ps1
   ```

### Manual Build

If you prefer to build manually:

```bash
cd mobile_smb_native
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build . --config Release
```

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  mobile_smb_native:
    path: ../mobile_smb_native  # Adjust path as needed
```

## Usage

### Basic Connection and File Operations

```dart
import 'package:mobile_smb_native/mobile_smb_native.dart';

// Create SMB client
final smbClient = MobileSmbClient();

// Configure connection
final config = SmbConnectionConfig(
  host: '192.168.1.100',
  port: 445,
  username: 'your_username',
  password: 'your_password',
  shareName: 'shared_folder',
);

// Connect to SMB server
final success = await smbClient.connect(config);
if (success) {
  print('Connected successfully!');
  
  // List shares
  final shares = await smbClient.listShares();
  print('Available shares: $shares');
  
  // List directory contents
  final files = await smbClient.listDirectory('/');
  for (final file in files) {
    print('${file.name} - ${file.isDirectory ? 'DIR' : 'FILE'}');
  }
  
  // Read a file
  final fileData = await smbClient.readFile('/example.txt');
  print('File content: ${String.fromCharCodes(fileData)}');
  
  // Write a file
  final success = await smbClient.writeFile('/new_file.txt', 
    'Hello, SMB!'.codeUnits);
  
  // Disconnect
  await smbClient.disconnect();
}
```

### High-Performance File Streaming

```dart
// Stream a large file without loading it entirely into memory
final stream = smbClient.openFileStream('/path/to/large/video.mp4');
if (stream != null) {
  await for (final chunk in stream) {
    // Process chunk (e.g., write to local file, send to media player)
    print('Received ${chunk.length} bytes');
  }
}
```

### Using the Native Service Directly

```dart
import 'package:mobile_smb_native/src/smb_native_service.dart';

// Get the singleton service instance
final service = SmbNativeService.instance;

// Connect
final connected = await service.connect(config);

// Stream with progress tracking
final progressStream = service.streamFileWithProgress(
  '/path/to/file.zip',
  onProgress: (progress) {
    print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

await for (final chunk in progressStream) {
   print('Chunk: ${chunk.data.length} bytes, Progress: ${chunk.progress}');
 }
 ```

### Connection Configuration

```dart
final config = SmbConnectionConfig(
  host: '192.168.1.100',        // SMB server IP or hostname
  port: 445,                    // SMB port (default: 445)
  username: 'user',             // Username
  password: 'pass',             // Password
  domain: 'WORKGROUP',          // Domain (optional)
  shareName: 'Documents',       // Share name (optional)
  timeout: 30000,               // Timeout in milliseconds
  smbVersion: 'SMB2',           // SMB version (SMB1, SMB2, SMB3)
);
```

### File Operations

```dart
// Check if connected
final isConnected = await smbClient.isConnected();

// Get file information
final fileInfo = await smbClient.getFileInfo('/path/to/file.txt');
if (fileInfo != null) {
  print('File size: ${fileInfo.size} bytes');
  print('Last modified: ${fileInfo.lastModified}');
}

// Create directory
final created = await smbClient.createDirectory('/new_folder');

// Delete file or directory
final deleted = await smbClient.delete('/path/to/delete');
```

## Android Setup

The plugin uses `jcifs-ng` library for Android SMB implementation. Make sure your app has internet permission:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## iOS Setup

The iOS implementation uses native Swift code. No additional setup required.

## Error Handling

```dart
try {
  final success = await smbClient.connect(config);
  if (!success) {
    print('Failed to connect to SMB server');
  }
} catch (e) {
  print('SMB error: $e');
}
```

## Limitations

- iOS implementation is currently a placeholder and needs native SMB library integration
- File streaming is not yet supported
- Progress callbacks for large file transfers are not implemented
- Rename operation is not supported

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.