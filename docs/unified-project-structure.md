# Unified Project Structure

This document describes how source code and assets are organized.

## Top-Level

- `cb_file_manager/` - Flutter app
- `mobile_smb_native/` - Native plugin module
- `docs/` - Project documentation

## Flutter App (`cb_file_manager/`)

- `lib/`
  - `bloc/` - BLoC state management
  - `config/` - Environment, app config
  - `helpers/` - Utilities and shared helpers
  - `models/` - Data models
  - `pages/` - Screens and routes
  - `services/` - App services (network, storage, etc.)
  - `ui/` - Widgets and components
- `assets/` - Images, sounds
- `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/` - Platform scaffolding

## Native Plugin (`mobile_smb_native/`)

- `android/`, `ios/`, `linux/`, `macos/`, `windows/` - Platform-specific code
- `lib/` - Dart-facing API and platform interface
- `native/` - Shared native sources/headers

## Conventions

- Mirror structure in tests
- Group features by folder when cohesive
- Keep platform-specific assets under their platform folders
