# Mobile SMB Native - New Implementation

This document describes the new implementation of `mobile_smb_native` using `libsmbclient` and FFmpeg with Dart FFI.

## Overview

The new implementation replaces the existing platform-specific code with a unified native C++ solution that provides:

- **High-performance SMB streaming** using `libsmbclient`
- **Video thumbnail generation** using FFmpeg
- **Direct memory access** via Dart FFI
- **Cross-platform compatibility** (Android/iOS)

## Architecture

### Native Layer (C++)

```
native/
├── include/
│   └── smb_bridge.h          # C interface definitions
├── src/
│   ├── smb_bridge.cpp        # Main C interface implementation
│   ├── smb_client.cpp        # SMB client wrapper
│   ├── thumbnail_generator.cpp # FFmpeg thumbnail generator
│   └── stub_implementations.cpp # Stub for testing without libraries
└── CMakeLists.txt            # Build configuration
```

### Dart Layer

```
lib/src/
├── smb_native_ffi.dart       # FFI bindings
├── smb_native_service.dart   # High-level service API
└── mobile_smb_native.dart    # Main export file
```

## Key Features

### 1. SMB Connection Management

```dart
final smbService = SmbNativeService();

// Connect to SMB server
final success = await smbService.connect(
  'server_ip',
  'share_name', 
  'username',
  'password'
);

// Check connection status
if (smbService.isConnected) {
  // Perform operations
}

// Disconnect
await smbService.disconnect();
```

### 2. Directory Listing

```dart
final files = await smbService.listDirectory('/path/to/directory');

for (final file in files) {
  print('${file.name}: ${file.size} bytes');
  print('Is directory: ${file.isDirectory}');
  print('Modified: ${DateTime.fromMillisecondsSinceEpoch(file.modifiedTime * 1000)}');
}
```

### 3. File Streaming

```dart
// Stream file with progress callback
final stream = smbService.streamFileWithProgress(
  '/path/to/file.mp4',
  onProgress: (bytesRead, totalBytes) {
    final progress = (bytesRead / totalBytes) * 100;
    print('Progress: ${progress.toStringAsFixed(1)}%');
  },
);

await for (final chunk in stream) {
  // Process chunk data
  processVideoChunk(chunk);
}
```

### 4. Thumbnail Generation

```dart
// Generate thumbnail for image or video
final thumbnail = await smbService.generateThumbnail(
  '/path/to/media.mp4',
  150, // width
  150, // height
);

if (thumbnail != null) {
  print('Thumbnail: ${thumbnail.width}x${thumbnail.height}');
  print('Data size: ${thumbnail.data.length} bytes');
  
  // Convert to Flutter Image
  final image = Image.memory(
    Uint8List.fromList(thumbnail.data),
    width: thumbnail.width.toDouble(),
    height: thumbnail.height.toDouble(),
  );
}
```

### 5. File Operations

```dart
// Check if file exists
final exists = await smbService.fileExists('/path/to/file.txt');

// Get file size
final size = await smbService.getFileSize('/path/to/file.txt');

// Read entire file
final data = await smbService.readFile('/path/to/file.txt');
```

## Current Status

### ✅ Completed

- [x] Native C++ interface design
- [x] Dart FFI bindings
- [x] High-level service API
- [x] Stub implementations for testing
- [x] Android build configuration
- [x] iOS build configuration
- [x] Example application
- [x] Basic project structure

### 🚧 In Progress

- [ ] Integration with actual `libsmbclient`
- [ ] Integration with actual FFmpeg
- [ ] Platform-specific library packaging
- [ ] Performance optimization
- [ ] Error handling improvements

### 📋 TODO

- [ ] Add `libsmbclient` prebuilt libraries
- [ ] Add FFmpeg prebuilt libraries
- [ ] Implement proper JPEG encoding for thumbnails
- [ ] Add comprehensive error handling
- [ ] Add unit tests
- [ ] Add integration tests
- [ ] Performance benchmarking
- [ ] Memory leak testing
- [ ] Documentation completion

## Building

### Prerequisites

- Flutter SDK
- Android NDK (for Android builds)
- Xcode (for iOS builds)
- CMake 3.10.2+

### Android

```bash
cd mobile_smb_native/example
flutter build apk
```

### iOS

```bash
cd mobile_smb_native/example
flutter build ios
```

## Testing

The current implementation includes stub functions that simulate SMB operations without requiring actual SMB servers or media files. This allows for:

- UI testing
- API validation
- Integration testing
- Development workflow validation

### Running the Example

```bash
cd mobile_smb_native/example
flutter run
```

The example app provides a UI to:
- Test SMB connections (simulated)
- Browse directories (simulated)
- Generate thumbnails (simulated)
- View file information

## Integration with Real Libraries

To integrate with actual `libsmbclient` and FFmpeg:

1. **Add prebuilt libraries** to `android/src/main/jniLibs/` and iOS frameworks
2. **Update CMakeLists.txt** to link against real libraries
3. **Replace stub_implementations.cpp** with actual implementations
4. **Test with real SMB servers** and media files

## Performance Considerations

- **Memory Management**: All native memory is properly managed with cleanup functions
- **Streaming**: Large files are processed in chunks to avoid memory issues
- **Threading**: File operations are performed on background threads
- **Caching**: Thumbnail results can be cached at the Dart level

## Error Handling

The implementation provides comprehensive error codes:

- `SMB_SUCCESS`: Operation completed successfully
- `SMB_ERROR_CONNECTION`: Connection failed
- `SMB_ERROR_AUTHENTICATION`: Authentication failed
- `SMB_ERROR_FILE_NOT_FOUND`: File not found
- `SMB_ERROR_PERMISSION_DENIED`: Permission denied
- `SMB_ERROR_INVALID_PARAMETER`: Invalid parameter
- `SMB_ERROR_MEMORY_ALLOCATION`: Memory allocation failed
- `SMB_ERROR_THUMBNAIL_GENERATION`: Thumbnail generation failed

## Security

- Credentials are handled securely in native code
- Memory is cleared after use
- No credentials are logged or stored persistently
- All network operations use secure SMB protocols

## Contributing

When contributing to this implementation:

1. Follow the existing code style
2. Add appropriate error handling
3. Include memory cleanup
4. Test on both Android and iOS
5. Update documentation

## License

This implementation follows the same license as the original `mobile_smb_native` package.