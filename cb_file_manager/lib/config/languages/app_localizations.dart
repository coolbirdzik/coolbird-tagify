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
  String get deleteAlbum;

  // Tag Management Screen
  String get tagManagementTitle;
  String get debugTags;
  String get searchTags;
  String get searchTagsHint;
  String get createNewTag;
  String get newTagTooltip;
  String get errorLoadingTags;
  String get noTagsFoundMessage;
  String get noTagsFoundDescription;
  String get createNewTagButton;
  String get noMatchingTagsMessage;
  String get clearSearch;
  String get tagManagementHeader;
  String get tagsCreated;
  String get tagManagementDescription;
  String get sortTags;
  String get sortByAlphabet;
  String get sortByPopular;
  String get listViewMode;
  String get gridViewMode;
  String get previousPage;
  String get nextPage;
  String get page;
  String get firstPage;
  String get lastPage;
  String get clickToViewFiles;
  String get changeTagColor;
  String get deleteTagFromAllFiles;
  String get openInNewTab;
  String get changeColor;
  String get noFilesWithTag;
  String get debugInfo;
  String get backToAllTags;
  String get tryAgain;
  String get filesWithTagCount;
  String get viewDetails;
  String get openContainingFolder;
  String get editTags;
  String get newTagTitle;
  String get enterTagName;
  String get tagAlreadyExists;
  String get tagCreatedSuccessfully;
  String get errorCreatingTag;
  String get openingFolder;
  String get folderNotFound;

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

  // File operations related to networks
  String get download;
  String get downloadFile;
  String get selectDownloadLocation;
  String get selectFolder;
  String get browse;
  String get upload;
  String get uploadFile;
  String get selectFileToUpload;
  String get create;
  String get folderName;

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

  // Permissions
  String get grantPermissionsToContinue;
  String get permissionsDescription;
  String get storagePhotosPermission;
  String get storagePhotosDescription;
  String get allFilesAccessPermission;
  String get allFilesAccessDescription;
  String get installPackagesPermission;
  String get installPackagesDescription;
  String get localNetworkPermission;
  String get localNetworkDescription;
  String get notificationsPermission;
  String get notificationsDescription;
  String get grantAllPermissions;
  String get grantingPermissions;
  String get enterApp;
  String get skipEnterApp;
  String get granted;
  String get grantPermission;

  // Home screen
  String get welcomeToFileManager;
  String get welcomeDescription;
  String get quickActions;
  String get browseFiles;
  String get browseFilesDescription;
  String get manageMedia;
  String get manageMediaDescription;
  String get tagFiles;
  String get tagFilesDescription;
  String get networkAccess;
  String get networkAccessDescription;
  String get keyFeatures;
  String get fileManagement;
  String get fileManagementDescription;
  String get smartTagging;
  String get smartTaggingDescription;
  String get mediaGallery;
  String get mediaGalleryDescription;
  String get networkSupport;
  String get networkSupportDescription;

  // Settings screen
  String get interface;
  String get selectInterfaceTheme;
  String get chooseInterface;
  String get interfaceDescription;
  String get showFileTags;
  String get showFileTagsDescription;
  String get showFileTagsToggle;
  String get showFileTagsToggleDescription;
  String get cacheManagement;
  String get cacheManagementDescription;
  String get cacheFolder;
  String get networkThumbnails;
  String get videoThumbnailsCache;
  String get tempFiles;
  String get notInitialized;
  String get refreshCacheInfo;
  String get cacheInfoUpdated;
  String get clearVideoThumbnailsCache;
  String get clearVideoThumbnailsDescription;
  String get clearNetworkThumbnailsCache;
  String get clearNetworkThumbnailsDescription;
  String get clearTempFilesCache;
  String get clearTempFilesDescription;
  String get clearAllCache;
  String get clearAllCacheDescription;
  String get videoCacheCleared;
  String get networkCacheCleared;
  String get tempFilesCleared;
  String get allCacheCleared;
  String get errorClearingCache;
  String get processing;
  String get regenerateThumbnailsWithNewPosition;
  String get thumbnailPositionUpdated;
  String get fileTagsEnabled;
  String get fileTagsDisabled;

  // System screen router
  String get unknownSystemPath;
  String get ftpConnectionRequired;
  String get ftpConnectionDescription;
  String get goToFtpConnections;
  String get cannotOpenNetworkPath;
  String get goBack;
  String get tagPrefix;

  // Network browsing
  String get ftpConnections;
  String get smbNetwork;
  String get refreshData;
  String get addConnection;
  String get noFtpConnections;
  String get activeConnections;
  String get savedConnections;
  String get connecting;
  String get connect;
  String get unknown;
  String get connectionError;
  String get loadCredentialsError;
  String get networkScanFailed;
  String get smbVersionUnknown;
  String get connectionInfoUnavailable;
  String get networkSettingsOpened;
  String get cannotOpenNetworkSettings;
  String get networkDiscoveryDisabled;
  String get networkDiscoveryDescription;
  String get openSettings;
  String get activeConnectionsTitle;
  String get activeConnectionsDescription;
  String get discoveredSmbServers;
  String get discoveredSmbServersDescription;
  String get noActiveSmbConnections;
  String get connectToSmbServer;
  String get connected;
  String get openConnection;
  String get disconnect;
  String get scanningForSmbServers;
  String get devicesWillAppear;
  String get scanningMayTakeTime;
  String get noSmbServersFound;
  String get tryScanningAgain;
  String get scanAgain;
  String get readyToScan;
  String get clickRefreshToScan;
  String get startScan;
  String get foundDevices;
  String get scanning;
  String get scanComplete;
  String get smbVersion;
  String get netbios;

  // Drawer menu items
  String get networksMenu;
  String get networkTab;
  String get about;

  // Tab manager
  String get newTabButton;
  String get openNewTabToStart;

  // Home screen
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get quickActionsTip;
  String get quickActionsHome;
  String get startHere;
  String get newTabAction;
  String get newTabActionDesc;
  String get tagsAction;
  String get tagsActionDesc;
  String get imageGalleryTab;
  String get videoGalleryTab;
  String get drivesTab;
  String get browseTab;
  String get documentsTab;
  String get homeTab;
  String get internalStorage;
  String get storagePrefix;
  String get rootFolder;
}
