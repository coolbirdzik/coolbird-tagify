import 'package:flutter/material.dart';

abstract class AppLocalizations {
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // App title
  String get appTitle;

  // Common actions
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get close;
  String get search;
  String get settings;

  // File operations
  String get copy;
  String get move;
  String get rename;
  String get newFolder;
  String get properties;
  String get openWith;

  // Navigation
  String get home;
  String get back;
  String get forward;
  String get refresh;
  String get parentFolder;

  // File types
  String get image;
  String get video;
  String get audio;
  String get document;
  String get folder;
  String get file;

  // Settings
  String get language;
  String get theme;
  String get darkMode;
  String get lightMode;
  String get systemMode;
  String get selectLanguage;
  String get selectTheme;
  String get selectThumbnailPosition;
  String get systemThemeDescription;
  String get lightThemeDescription;
  String get darkThemeDescription;
  String get vietnameseLanguage;
  String get englishLanguage;

  // Messages
  String get fileDeleteConfirmation;
  String get folderDeleteConfirmation;
  String get fileDeleteSuccess;
  String get folderDeleteSuccess;
  String get operationFailed;

  // Tags
  String get tags;
  String get addTag;
  String get removeTag;
  String get tagManagement;
  String get deleteTagConfirmation;
  String get tagDeleteConfirmationText;
  String get tagDeleted;
  String get errorDeletingTag;
  String get chooseTagColor;
  String get tagColorUpdated;
  String get allTags;
  String get filesWithTag;
  String get tagsInDirectory;
  String get aboutTags;
  String get aboutTagsTitle;
  String get aboutTagsDescription;
  String get aboutTagsScreenDescription;
  String get deleteTag;

  // Sorting
  String get sort;
  String get sortByName;
  String get sortByPopularity;
  String get sortByRecent;
  String get sortBySize;
  String get sortByDate;

  // Gallery
  String get imageGallery;
  String get videoGallery;

  // Storage locations
  String get local;
  String get networks;

  // Additional translations for database settings
  String get databaseSettings;
  String get databaseStorage;
  String get useObjectBox;
  String get databaseDescription;
  String get jsonStorage;
  String get objectBoxStorage;

  // Cloud sync
  String get cloudSync;
  String get enableCloudSync;
  String get cloudSyncDescription;
  String get syncToCloud;
  String get syncFromCloud;
  String get cloudSyncEnabled;
  String get cloudSyncDisabled;
  String get enableObjectBoxForCloud;

  // Database statistics
  String get databaseStatistics;
  String get totalUniqueTags;
  String get taggedFiles;
  String get popularTags;
  String get noTagsFound;
  String get refreshStatistics;

  // Import/Export
  String get importExportDatabase;
  String get backupRestoreDescription;
  String get exportDatabase;
  String get exportSettings;
  String get importDatabase;
  String get importSettings;
  String get exportDescription;
  String get importDescription;
  String get completeBackup;
  String get completeRestore;
  String get exportAllData;
  String get importAllData;

  // Export/Import messages
  String get exportSuccess;
  String get exportFailed;
  String get importSuccess;
  String get importFailed;
  String get importCancelled;
  String get errorExporting;
  String get errorImporting;

  // Video thumbnails
  String get videoThumbnails;
  String get thumbnailPosition;
  String get percentOfVideo;
  String get thumbnailDescription;
  String get thumbnailCache;
  String get thumbnailCacheDescription;
  String get clearThumbnailCache;
  String get clearing;
  String get thumbnailCleared;
  String get errorClearingThumbnail;

  // New tab
  String get newTab;

  // Admin access
  String get adminAccess;
  String get adminAccessRequired;

  // File system
  String get drives;
  String get system;

  // Settings data
  String get settingsData;
  String get viewManageSettings;

  // File details
  String get fileSize;
  String get fileLocation;
  String get fileCreated;
  String get fileModified;
  String get loadingVideo;
  String get errorLoadingImage;
  String get createCopy;
  String get deleteFile;

  // File picker dialogs
  String get chooseBackupLocation;
  String get chooseRestoreLocation;
  String get saveSettingsExport;
  String get saveDatabaseExport;
  String get selectBackupFolder;

  // About app
  String get aboutApp;
  String get appDescription;
  String get version;
  String get developer;

  // Empty state
  String get emptyFolder;
  String get noImagesFound;
  String get noVideosFound;
  String get loading;

  // Search errors
  String noFilesFoundTag(Map<String, String> args);
  String noFilesFoundTagGlobal(Map<String, String> args);
  String noFilesFoundTags(Map<String, String> args);
  String noFilesFoundTagsGlobal(Map<String, String> args);
  String errorSearchTag(Map<String, String> args);
  String errorSearchTagGlobal(Map<String, String> args);
  String errorSearchTags(Map<String, String> args);
  String errorSearchTagsGlobal(Map<String, String> args);

  // Search status
  String searchingTag(Map<String, String> args);
  String searchingTagGlobal(Map<String, String> args);
  String searchingTags(Map<String, String> args);
  String searchingTagsGlobal(Map<String, String> args);

  // Search UI
  String get searchTips;
  String get searchTipsTitle;
  String get viewTagSuggestions;
  String get globalSearchModeEnabled;
  String get localSearchModeEnabled;
  String get globalSearchMode;
  String get localSearchMode;
  String get searchByFilename;
  String get searchByTags;
  String get searchMultipleTags;
  String get globalSearch;
  String get searchShortcuts;
  String get searchHintText;
  String get searchHintTextTags;
  String get suggestedTags;
  String get noMatchingTags;
  String get results;
  String get searchByFilenameDesc;
  String get searchByTagsDesc;
  String get searchMultipleTagsDesc;
  String get globalSearchDesc;
  String get searchShortcutsDesc;
}
