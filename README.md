# CB File Hub

[![Build and Test](https://github.com/nth-zik/coolbird-tagify/actions/workflows/build-test.yml/badge.svg)](https://github.com/nth-zik/coolbird-tagify/actions/workflows/build-test.yml)
[![Release](https://github.com/nth-zik/coolbird-tagify/actions/workflows/release.yml/badge.svg)](https://github.com/nth-zik/coolbird-tagify/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A powerful cross-platform file manager built with Flutter, supporting local and network (SMB) file access with advanced media playback capabilities.

## ✨ Features

- 📁 **File Management**: Browse, organize, and manage files across multiple platforms
- 🌐 **Network Support**: Access files via SMB/CIFS network shares
- 🎥 **Media Playback**: Built-in video player with advanced controls
- 🖼️ **Thumbnail Generation**: Fast thumbnail generation for images and videos
- 📌 **Sidebar Pinning**: Pin drives, folders, or files into a dedicated `Pinned` drawer section
- 🧠 **Workspace Restore**: Optionally restore last opened tab and per-tab drawer expansion state
- 🌍 **Multi-language**: Support for multiple languages including Vietnamese
- 🎨 **Modern UI**: Clean and intuitive user interface
- 💾 **Local Database**: Fast file indexing with ObjectBox
- 🔄 **Cross-platform**: Works on Windows, Android, Linux, and macOS

## 📦 Downloads

Download the latest release for your platform:

### Windows

- **MSI Installer** (Recommended): Easy installation with shortcuts
- **Portable ZIP**: Extract and run without installation

### Android

- **APK**: Direct installation (enable "Unknown Sources")
- **AAB**: For Google Play Store distribution

### Linux

- **tar.gz**: Extract and run

### macOS

- **ZIP**: Extract and move to Applications

[📥 Download Latest Release](https://github.com/nth-zik/coolbird-tagify/releases/latest)

## 🚀 Quick Start

### Windows

**Option 1: MSI Installer (Recommended)**

1. Download `CBFileHub-Setup-vX.X.X.msi`
2. Run the installer
3. Launch from Start Menu or Desktop shortcut

**Option 2: Portable**

1. Download `CBFileHub-vX.X.X-windows.zip`
2. Extract to any folder
3. Run `cb_file_hub.exe`

**Note:** On Windows, you can run scripts using Git Bash (comes with Git for Windows)

### Android

1. Download `CBFileHub-vX.X.X-arm64-v8a.apk`
2. Enable "Install from Unknown Sources" in Settings
3. Install and launch

### Linux

```bash
# Extract
tar -xzf CBFileHub-vX.X.X-linux.tar.gz

# Run
cd bundle
./cb_file_hub
```

### macOS

1. Download `CBFileHub-vX.X.X-macos.zip`
2. Extract and move to Applications
3. Right-click and select "Open" (first time only)

## 🛠️ Development

### Prerequisites

- Flutter SDK 3.24.0 or later
- Dart SDK 2.15.0 or later
- Platform-specific requirements:
  - **Windows**: Visual Studio 2022 with C++ tools
  - **Android**: Android SDK, Java JDK 17+
  - **Linux**: GTK3 development libraries
  - **macOS**: Xcode, CocoaPods

### Setup

```bash
# Clone the repository
git clone https://github.com/nth-zik/coolbird-tagify.git
cd coolbirdfm-flutter

# Navigate to project directory
cd cb_file_manager

# Install dependencies
flutter pub get

# Run the app
flutter run
```

**Note for Windows users:** Use Git Bash or WSL to run bash scripts.

### Using Interactive Script (Easiest)

```bash
# Make executable (first time)
chmod +x scripts/build.sh

# Run interactive menu
./scripts/build.sh
```

Select from the menu:

- Build targets (Windows, Android, Linux, etc.)
- Development tools (clean, test, analyze)
- Release management

#### Using Makefile (For automation)

```bash
# Show all commands
make help

# Build for your platform
make windows      # Windows portable
make android      # Android APK
make linux        # Linux

# Build all platforms
make all
```

**Windows users:** Use Git Bash (comes with Git for Windows) to run these commands.

#### Manual Build

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release --split-per-abi

# Android AAB
flutter build appbundle --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

See [scripts/README.md](scripts/README.md) for detailed build instructions.

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze

# Format code
dart format .
```

## 📚 Documentation

- [Quick Start Guide](QUICK_START.md) - Get started quickly with make commands
- [Build Instructions](scripts/README.md) - Detailed build documentation
- [Windows Setup Guide](WINDOWS_SETUP.md) - Guide for Windows users
- [Windows Build Fix](WINDOWS_BUILD_FIX.md) - Troubleshooting Windows build issues
- [Release Guide](RELEASE_GUIDE.md) - How to create releases
- [Contributing](CONTRIBUTING.md) - Contribution guidelines
- [Changelog](CHANGELOG.md) - Version history

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution Steps

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Bug Reports

Found a bug? Please [open an issue](https://github.com/nth-zik/coolbird-tagify/issues/new) with:

- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)
- Environment details

## 💡 Feature Requests

Have an idea? [Open a feature request](https://github.com/nth-zik/coolbird-tagify/issues/new) and describe:

- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

## 📋 Roadmap

- [ ] Cloud storage integration (Google Drive, Dropbox)
- [ ] File encryption support
- [ ] Advanced search with filters
- [ ] Batch operations
- [ ] Plugin system
- [ ] iOS support
- [ ] Web version

## 🏗️ Architecture

```
cb_file_manager/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   ├── views/                 # UI screens
│   ├── widgets/               # Reusable widgets
│   ├── services/              # Business logic
│   │   ├── file_service.dart
│   │   ├── smb_service.dart
│   │   └── video_service.dart
│   ├── utils/                 # Utilities
│   └── constants/             # Constants
├── test/                      # Tests
├── assets/                    # Assets
└── pubspec.yaml              # Dependencies
```

## 🔧 Technologies

- **Framework**: Flutter 3.24.0
- **Language**: Dart
- **Database**: ObjectBox
- **Video Player**: Media Kit, VLC Player
- **Network**: SMB/CIFS via mobile_smb_native
- **State Management**: flutter_bloc, Provider
- **Build Tools**: GitHub Actions, WiX Toolset

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/YOUR_USERNAME/coolbirdfm-flutter?style=social)
![GitHub forks](https://img.shields.io/github/forks/YOUR_USERNAME/coolbirdfm-flutter?style=social)
![GitHub issues](https://img.shields.io/github/issues/YOUR_USERNAME/coolbirdfm-flutter)
![GitHub pull requests](https://img.shields.io/github/issues-pr/YOUR_USERNAME/coolbirdfm-flutter)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- All contributors who help improve this project
- Open source libraries used in this project

## 📞 Contact

- **Issues**: [GitHub Issues](https://github.com/nth-zik/coolbird-tagify/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nth-zik/coolbird-tagify/discussions)
- **Email**: your.email@example.com

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=YOUR_USERNAME/coolbirdfm-flutter&type=Date)](https://star-history.com/#YOUR_USERNAME/coolbirdfm-flutter&Date)

---

Made with ❤️ by the CB File Hub team
