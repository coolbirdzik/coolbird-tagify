# Detailed Feature List of cb_file_manager

## 1. File & Folder Management

- Browse, search, and sort files/folders with multiple view modes (grid/list, breadcrumb navigation).
- View file/folder details, quick preview support.
- Actions: delete, move, rename, create new, manage trash bin (trash_manager.dart).
- Sort by name, type, creation date, size (folder_sort_manager.dart).
- File icon support, file type recognition (file_icon_helper.dart, file_type_helper.dart).

## 2. Tagging & Tag Management

- Assign multiple tags to files/folders, manage tag colors (tag_color_manager.dart).
- Search and filter files by tag, batch tagging support (batch_tag_manager.dart).
- Intuitive UI: tag chip, tag management screen, tag management tab.
- Store tags with ObjectBox, sync tags with files/folders.

## 3. Advanced Search

- Search by name, type, tag, file/folder attributes.
- Fast search, filter results by multiple criteria.
- Results displayed in tabs, switchable view modes.
- Real-time search, optimized performance with database indexing.

## 4. Network Connection & Remote File Browsing

- Connect and browse files via FTP, SMB, WebDAV.
- Manage login information, securely store credentials.
- Auto-discover network devices (network_discovery_service.dart).
- Optimized SMB browsing speed, chunk reader, prefetch controller support.
- UI: FTP/SMB/WebDAV browsing screens, network connection management.

## 5. Streaming & Media

- Play video/audio directly from files/folders, support for multiple formats.
- Generate video thumbnails, quick preview display.
- Manage streaming speed, show performance metrics.
- Media playback supported on multiple platforms (Windows, Android, iOS, ...).
- UI: video player dialog, streaming performance widget.

## 6. Database & Preferences Management

- Store tags, user preferences, network credentials with ObjectBox.
- Manage app configuration, theme, language, database settings.
- Automatic backup, restore data when needed.

## 7. UI/UX & Navigation

- Tabbed navigation: quickly switch between tabs and screens.
- Scrollable tab bar, tab manager, multiple view modes supported.
- Drawer, dialogs, action bar, address bar widget for quick actions.
- Loading skeleton, lazy video thumbnail for optimized user experience.

## 8. System & Settings Management

- Settings screen: configure app, database, theme, language.
- Manage trash bin, restore deleted files.
- Folder sort management, optimize folder structure.
- Multi-platform support: Android, iOS, Windows, Linux, macOS, Web.

---

This document describes in detail the current features of cb_file_manager, helping AI agents and developers easily reference, extend, or maintain the system.
