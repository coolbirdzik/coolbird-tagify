# Brownfield Architecture Document

## UI/UX Architecture (Brownfield Analysis)

## Introduction

This section documents the current state of UI/UX in the project, focusing on reusable widgets, screens, and user interaction patterns. It is based on the latest feature documentation and observed code structure.

## Key Files & Entry Points

- `ui/components/*` – Modular UI components for reuse
- `ui/screens/*` – Screens for main app flows
- `ui/widgets/*` – Widgets for custom interactions

## Architecture & Integration

- Modular UI components are designed for maximum reuse across screens
- Screens implement main application flows and orchestrate widgets/components
- Widgets provide custom interactions and encapsulate complex UI logic
- Integration between screens and components follows a consistent pattern for cross-platform usability

## Technical Debt & Known Issues

- Some UI modules lack documentation, making onboarding and maintenance harder
- Manual testing is required for UI/UX changes; automated UI tests are not yet implemented

## Workarounds & Gotchas

- For troubleshooting UI issues, refer to the `doc/` folder for additional notes and guides
- Some legacy widgets may not follow current architectural patterns

## Testing Reality

- Usability and consistency are verified through manual testing
- No automated UI test coverage; future improvements should prioritize test automation

## Success Criteria

- UI/UX is consistent across platforms (Android, iOS, desktop)
- No major usability issues reported by users
- All new UI modules should include documentation and basic test coverage

## Recommendations

- Prioritize documentation for undocumented UI modules
- Begin implementing automated UI tests for critical screens and widgets
- Standardize integration patterns for new UI components
- Regularly review usability across platforms to maintain consistency

_Source: docs/features/ui-ux.md_

# cb_file_manager Brownfield Architecture Document

## Introduction

This document captures the current state of the cb_file_manager codebase, including technical debt, workarounds, and real-world patterns. It is intended for AI agents and developers working on enhancements.

### Document Scope

Comprehensive documentation of the entire system.

### Change Log

| Date       | Version | Description                 | Author  |
| ---------- | ------- | --------------------------- | ------- |
| 2025-09-15 | 1.0     | Initial brownfield analysis | Copilot |

---

## Quick Reference – Key Files and Entry Points

- **Main Entry:** `lib/` (Flutter/Dart main app code)
- **Configuration:** `analysis_options.yaml`, `devtools_options.yaml`, `pubspec.yaml`
- **Core Business Logic:** `services_*`, `helpers_*`, `models_*` folders
- **UI Components:** `ui_components_*`, `ui_screens_*`, `ui_widgets_*`
- **Tagging & Search:** `helpers_tags_*`, `ui_tab_manager_*`, `ui_screens_tag_management_*`
- **Database Models:** `models_objectbox_*`, `objectbox/`
- **Platform Integration:** `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`
- **Documentation:** `README.md`, `doc/` folder (contains module-level docs)

---

## High Level Architecture

### Technical Summary

- **Language:** Dart (Flutter)
- **Framework:** Flutter (cross-platform mobile/desktop/web)
- **State Management:** flutter_bloc
- **Database:** ObjectBox (local database for tags, user preferences, etc.)
- **Media:** media_kit, flutter_vlc_player (video/audio playback)
- **Tagging:** Custom tag manager, color manager, batch tag manager
- **Networking:** FTP, SMB, WebDAV support via service modules and plugins

### Actual Tech Stack (from pubspec.yaml)

| Category         | Technology                                                  | Version/Notes          |
| ---------------- | ----------------------------------------------------------- | ---------------------- |
| Runtime          | Dart SDK                                                    | >=2.15.0 <=3.32.1      |
| Framework        | Flutter                                                     | Latest supported       |
| State Mgmt       | flutter_bloc                                                | ^9.1.0                 |
| Database         | objectbox_flutter_libs                                      | ^4.3.0                 |
| Media            | media_kit, flutter_vlc_player                               | ^1.1.11, ^7.2.0        |
| UI Components    | eva_icons_flutter, flutter_chips_input, flutter_colorpicker | ^3.1.0, ^2.0.0, ^1.1.0 |
| Networking       | Custom FTP/SMB/WebDAV services                              | Local plugin, adapters |
| Platform Plugins | package_info_plus, path_provider_android, etc.              | Various                |

---

## Repository Structure Reality Check

- Type: Monorepo (all platforms and code in one repo)
- Package Manager: Flutter/Dart pub
- Notable: Extensive use of helpers and services for modularity; platform-specific folders for native code.

---

## Source Tree and Module Organization

```
cb_file_manager/
├── android/           # Native Android integration
├── assets/            # Images, sounds
├── doc/               # Module-level documentation
├── ios/               # Native iOS integration
├── lib/               # Main Flutter/Dart code
│   ├── helpers_*      # Utility modules (filesystem, tags, media, etc.)
│   ├── models_*       # Data models (ObjectBox, user prefs, etc.)
│   ├── services_*     # Business logic (networking, streaming, etc.)
│   ├── ui_components_*# Reusable UI widgets
│   ├── ui_screens_*   # App screens (file list, tag management, settings, etc.)
│   ├── ui_tab_manager_* # Tabbed navigation and search
│   └── ...            # Other features
├── linux/             # Native Linux integration
├── macos/             # Native macOS integration
├── packages/          # External packages
├── test/              # Dart/Flutter tests
├── web/               # Web integration
├── windows/           # Native Windows integration
├── pubspec.yaml       # Project dependencies
├── README.md          # Project overview
└── ...                # Other config and assets
```

---

## Key Modules and Their Purpose

- **Tag Management:** `helpers_tags_tag_manager`, `ui_screens_tag_management_*`, `models_objectbox_file_tag`
- **File Search:** `helpers_core_filesystem_utils`, `ui_tab_manager_components_search_bar`, `ui_tab_manager_components_search_results`
- **Network Browsing:** `services_network_browsing_*`, `ui_screens_network_browsing_*`
- **Streaming:** `services_streaming_*`, `ui_components_streaming_performance_widget`
- **UI/UX:** `ui_components_*`, `ui_screens_*`, `ui_widgets_*`
- **Database:** `models_objectbox_*`, `objectbox/`
- **Platform Integration:** Platform folders and plugins

---

## Data Models and APIs

- **File Tag Model:** `models_objectbox_file_tag`
- **User Preferences:** `models_objectbox_user_preference`
- **Database Provider:** `models_database_database_provider`, `models_objectbox_objectbox_database_provider`
- **Network Credentials:** `models_database_network_credentials`
- **API:** Internal service APIs for file operations, tagging, search, and streaming; external APIs for FTP/SMB/WebDAV.

---

## Technical Debt and Known Issues

1. **Legacy SMB/FTP code:** Some modules (e.g., `services_network_browsing_win32_smb_helper`) use legacy patterns and may lack full test coverage.
2. **Platform-specific quirks:** Native integrations (Windows, Linux, macOS) may have inconsistent behaviors.
3. **Modularization:** Helpers and services are highly modular but sometimes duplicated across features.
4. **Testing:** Test coverage is present but not comprehensive for all modules.
5. **Documentation:** Some helper/service modules lack detailed documentation in `doc/`.

---

## Workarounds and Gotchas

- **Tagging system:** Custom color manager and batch tag manager require specific initialization order.
- **Search:** File search performance depends on database indexing and may be slow for large directories.
- **Platform plugins:** Some plugins require manual setup in native folders (see platform-specific README).
- **Streaming:** Video/audio streaming may have platform-specific limitations (e.g., Windows audio fix).

---

## Integration Points and External Dependencies

| Service/Plugin         | Purpose              | Integration Type      | Key Files/Folders                |
| ---------------------- | -------------------- | --------------------- | -------------------------------- |
| ObjectBox              | Local database       | Dart/Flutter package  | models*objectbox*\*, objectbox/  |
| media_kit, flutter_vlc | Media playback       | Dart/Flutter package  | helpers*media*_, ui*components*_ |
| FTP/SMB/WebDAV         | Network file access  | Custom Dart services  | services*network_browsing*\*     |
| Platform plugins       | Device info, storage | Dart/Flutter packages | packages/, platform folders      |

---

## Development and Deployment

- **Local Development:** Standard Flutter workflow (`flutter run`, `flutter build`, etc.)
- **Platform Setup:** Requires platform-specific setup for Android, iOS, Windows, Linux, macOS, and web.
- **Build System:** Uses Flutter build commands; see `README.md` for details.
- **Testing:** Dart/Flutter test framework; run with `flutter test`.
- **Environment Variables:** Some features require configuration in `analysis_options.yaml` and platform-specific files.

---

## Testing Reality

- **Unit Tests:** Present in `test/`, coverage varies by module.
- **Integration Tests:** Limited, mostly for networking and database.
- **Manual Testing:** Required for platform-specific features and UI/UX.

---

## Appendix – Useful Commands and Scripts

```pwsh
flutter run                # Start app in development mode
flutter build apk          # Build Android APK
flutter build ios          # Build iOS app
flutter build windows      # Build Windows app
flutter test               # Run all tests
```

---

## Debugging and Troubleshooting

- **Logs:** Use Flutter/Dart logging; check platform-specific logs for native issues.
- **Common Issues:** See `README.md` and `doc/` for troubleshooting tips.
- **Platform Quirks:** Refer to platform folders and documentation for setup and known issues.

---

## Success Criteria

- Document reflects actual codebase, technical debt, and workarounds.
- Key files and modules referenced with actual paths.
- Models/APIs reference source files.
- Technical constraints and "gotchas" are clearly documented.

---
