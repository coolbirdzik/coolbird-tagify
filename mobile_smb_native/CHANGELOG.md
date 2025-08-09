# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2024-12-19

### Added
- **SmbPlatformService**: New platform-aware service that gracefully handles different platform capabilities
- **Platform Detection**: Automatic detection of native library availability
- **Graceful Fallbacks**: Proper error handling when native functionality is not available
- **Platform Status API**: Methods to check platform support level and capabilities
- **Mobile Stub Support**: Re-enabled Android and iOS with stub implementations
- **Enhanced Example App**: Updated example to demonstrate platform-aware usage
- **Improved Error Messages**: Platform-specific error messages and guidance

### Changed
- **Example App**: Now uses SmbPlatformService instead of direct SmbNativeService
- **UI Improvements**: Buttons and actions are disabled when native service is unavailable
- **Error Handling**: Better error handling and user feedback in example app
- **Platform Configuration**: Re-enabled Android and iOS in pubspec.yaml with stub implementations

### Fixed
- **Mobile Platform Crashes**: Fixed crashes on Android/iOS when native library is not available
- **FFI Loading**: Added proper try-catch blocks for FFI library loading
- **Stub Implementation**: Fixed function signatures in Android stub implementation

## [2.0.0] - 2024-12-19

### Added
- **libsmb2 Integration**: Complete rewrite using libsmb2 for high-performance SMB operations
- **Dart FFI Implementation**: Direct native function calls for maximum performance
- **High-Performance Streaming**: Memory-efficient file streaming without loading entire files
- **Cross-Platform Support**: Windows, Linux, and macOS support
- **Native C++ Layer**: Clean C++ wrapper around libsmb2
- **CMake Build System**: Modern build configuration with vcpkg integration
- **Progress Tracking**: Real-time progress callbacks for file operations
- **Thumbnail Generation**: Stub implementation for video thumbnail generation
- **PowerShell Build Script**: Automated build process for Windows

### Changed
- **BREAKING**: Complete API redesign for better performance and usability
- **BREAKING**: Moved from platform channels to FFI for native communication
- **BREAKING**: Changed from mobile-focused to desktop-focused implementation
- **Platform Support**: Now targets Windows/Linux/macOS instead of Android/iOS
- **Architecture**: Switched from platform-specific implementations to unified native library
- **Memory Management**: Improved memory efficiency with streaming architecture

### Removed
- **Android Support**: Temporarily removed (planned for future release)
- **iOS Support**: Temporarily removed (planned for future release)
- **Platform Channels**: Replaced with direct FFI calls
- **jcifs-ng Dependency**: Replaced with libsmb2
- **Swift Implementation**: Replaced with C++ implementation

### Technical Details

#### Native Layer Changes
- Added `smb_bridge.h/cpp`: Main C++ interface for SMB operations
- Added `smb2_client_wrapper.h/cpp`: libsmb2 wrapper with RAII management
- Added `thumbnail_generator.h/cpp`: Stub implementation for thumbnail generation
- Added `CMakeLists.txt`: Modern CMake configuration with vcpkg

#### Dart Layer Changes
- Added `smb_native_ffi.dart`: FFI bindings for native functions
- Added `smb_native_service.dart`: High-level service layer
- Modified `mobile_smb_native_method_channel.dart`: Migrated from platform channels to FFI
- Updated all service classes to use new FFI-based implementation

#### Build System
- Added `build_native.ps1`: Automated build script for Windows
- Added vcpkg integration for dependency management
- Added cross-platform CMake configuration

### Migration Guide

For users upgrading from v1.x:

1. **Platform Support**: This version targets desktop platforms (Windows/Linux/macOS)
2. **Build Requirements**: Install vcpkg and libsmb2 before building
3. **API Changes**: Review the updated API documentation in README.md
4. **Performance**: Expect significant performance improvements for large file operations

### Known Issues

- Thumbnail generation is currently a stub implementation
- Android/iOS support is planned for future releases
- Some advanced SMB features may not be fully implemented yet

## [1.x.x] - Previous Versions

Previous versions focused on mobile platforms (Android/iOS) using platform-specific implementations.
See git history for detailed changes in the 1.x series.