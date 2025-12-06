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
  String get moreOptions;

  // File operations
  String get copy;
  String get cut;
  String get move;
  String get rename;
  String get newFolder;
  String get properties;
  String get openWith;
  String get openFolder;
  String get openFile;
  String get viewImage;
  String get open;
  String get pasteHere;
  String get manageTags;
  String get moveToTrash;
  String get errorAccessingDirectory;

  // Action bar tooltips
  String get searchTooltip;
  String get sortByTooltip;
  String get refreshTooltip;
  String get moreOptionsTooltip;
  String get adjustGridSizeTooltip;
  String get columnSettingsTooltip;
  String get viewModeTooltip;

  // Dialog titles
  String get adjustGridSizeTitle;
  String get columnVisibilityTitle;

  // Button labels
  String get apply;

  // Sort options
  String get sortNameAsc;
  String get sortNameDesc;
  String get sortDateModifiedOldest;
  String get sortDateModifiedNewest;
  String get sortDateCreatedOldest;
  String get sortDateCreatedNewest;
  String get sortSizeSmallest;
  String get sortSizeLargest;
  String get sortTypeAsc;
  String get sortTypeDesc;
  String get sortExtensionAsc;
  String get sortExtensionDesc;
  String get sortAttributesAsc;
  String get sortAttributesDesc;

  // View modes
  String get viewModeList;
  String get viewModeGrid;
  String get viewModeDetails;

  // Column names
  String get columnSize;
  String get columnType;
  String get columnDateModified;
  String get columnDateCreated;
  String get columnAttributes;

  // Column descriptions
  String get columnSizeDescription;
  String get columnTypeDescription;
  String get columnDateModifiedDescription;
  String get columnDateCreatedDescription;
  String get columnAttributesDescription;

  // Column visibility dialog
  String get columnVisibilityInstructions;

  // Grid size dialog
  String gridSizeLabel(int count);
  String get gridSizeInstructions;

  // More options menu
  String get selectMultipleFiles;
  String get viewImageGallery;
  String get viewVideoGallery;

  // Navigation
  String get home;
  String get back;
  String get forward;
  String get refresh;
  String get parentFolder;

  // Video Hub
  String get videoHub;
  String get manageYourVideos;
  String get videos;
  String get videoActions;
  String get allVideos;
  String get browseAllYourVideos;
  String get videosFolder;
  String get openFileManager;
  String get videoStatistics;
  String get totalVideos;

  String get internalStorage;
  String get storagePrefix;
  String get rootFolder;

  // File types
  String get image;
  String get video;
  String get audio;
  String get document;
  String get folder;
  String get file;

  // File type labels
  String get fileTypeGeneric;
  String get fileTypeJpeg;
  String get fileTypePng;
  String get fileTypeGif;
  String get fileTypeBmp;
  String get fileTypeTiff;
  String get fileTypeWebp;
  String get fileTypeSvg;
  String get fileTypeMp4;
  String get fileTypeAvi;
  String get fileTypeMov;
  String get fileTypeWmv;
  String get fileTypeFlv;
  String get fileTypeMkv;
  String get fileTypeMp3;
  String get fileTypeWav;
  String get fileTypeAac;
  String get fileTypeFlac;
  String get fileTypeOgg;
  String get fileTypePdf;
  String get fileTypeWord;
  String get fileTypeExcel;
  String get fileTypePowerPoint;
  String get fileTypeTxt;
  String get fileTypeRtf;
  String get fileTypeZip;
  String get fileTypeRar;
  String get fileType7z;
  String fileTypeWithExtension(String extension);

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
  String deleteTagConfirmation(String tag);
  String get tagDeleteConfirmationText;
  String tagDeleted(String tag);
  String errorDeletingTag(String error);
  String chooseTagColor(String tag);
  String tagColorUpdated(String tag);
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
  String noMatchingTagsMessage(String searchTags);
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
  String debugInfo(String tag);
  String get backToAllTags;
  String get tryAgain;
  String get filesWithTagCount;
  String get viewDetails;
  String get openContainingFolder;
  String get editTags;
  String get newTagTitle;
  String get enterTagName;
  String tagAlreadyExists(String tagName);
  String tagCreatedSuccessfully(String tagName);
  String get errorCreatingTag;
  String get tagsSavedSuccessfully;
  String get selectTagToRemove;
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

  // Gallery Hub
  String get galleryHub;
  String get managePhotosAndAlbums;
  String get images;
  String get galleryActions;
  String get quickAccess;
  String get browseAllYourPictures;
  String get browseAllYourPhotos;
  String get organizeInAlbums;
  String get picturesFolder;
  String get photosFromCamera;
  String get downloadedFiles;
  String get downloadedImages;
  String get featuredAlbums;
  String get personalized;
  String get configureFeaturedAlbums;
  String get noFeaturedAlbums;
  String get createSomeAlbumsToSeeThemFeaturedHere;
  String get removeFromFeatured;
  String get galleryStatistics;
  String get totalImages;
  String get albums;
  String get allImages;
  String get camera;
  String get downloads;
  String get recent;
  String get folders;

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

  String get resetSettings;

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
  String get fileName;
  String get filePath;
  String get fileType;
  String get fileLastModified;
  String get fileAccessed;
  String get loadingVideo;
  String get errorLoadingImage;
  String get createCopy;
  String get deleteFile;

  // Video actions
  String get share;
  String get playVideo;
  String get videoInfo;
  String get deleteVideo;
  String get loadingThumbnails;
  String get deleteVideosConfirm; // "Xóa {count} video?"
  String get deleteConfirmationMessage; // "Bạn có chắc chắn..."
  String videosSelected(int count); // "{count} video đã chọn"
  String videosDeleted(int count); // "Đã xóa {count} video"
  String searchingFor(String query); // "Tìm kiếm: {query}"
  String get errorDisplayingVideoInfo;
  String get searchVideos; // "Tìm kiếm video"
  String get enterVideoName; // "Nhập tên video..."

  // Selection and grid
  String? get selectMultiple; // "Chọn nhiều file"
  String? get gridSize; // "Kích thước lưới"

  // Clipboard actions
  String copiedToClipboard(String name);
  String cutToClipboard(String name);
  String get pasting;

  // Rename dialogs
  String get renameFileTitle;
  String get renameFolderTitle;
  String currentNameLabel(String name);
  String get newNameLabel;
  String renamedFileTo(String newName);
  String renamedFolderTo(String newName);

  // Downloads
  String downloadedTo(String location);
  String downloadFailed(String error);

  // Folder / Trash
  String movedToTrash(String name);
  String moveItemsToTrashConfirmation(int count, String itemType);
  String moveToTrashConfirmMessage(String name);
  String get clearFilter;
  String filteredBy(String filter);
  String noFilesMatchFilter(String filter);

  // Misc helper labels
  String get networkFile;
  String tagCount(int count);

  // Generic errors
  String errorGettingFolderProperties(String error);
  String errorSavingTags(String error);
  String errorCreatingFolder(String error);

  // UI labels
  String get noStorageLocationsFound;
  String get menuPinningOnlyLargeScreens;
  String get exitApplicationTitle;
  String get exitApplicationConfirm;
  String itemsSelected(int count);
  String get noActiveTab;
  String get masonryLayoutName;
  String get undo;
  String errorWithMessage(String message);

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

  // Tag list state
  String get tagListRefreshing;

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
  String get searchByNameOrTag;
  String get searchInSubfolders;
  String get featureNotImplemented;
  String get searchInAllFolders;
  String get searchInCurrentFolder;
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
  String get tabManager;
  String get openTabs;
  String get noTabsOpen;
  String get closeAllTabs;
  String get activeTab;
  String get closeTab;
  String get addNewTab;

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

  // Video player screenshot
  String get takeScreenshot;
  String get screenshotSaved;
  String get screenshotSavedAt;
  String get screenshotFailed;
  String get screenshotSavedToFolder;
  String get openScreenshotFolder;
  String get viewScreenshot;
  String get screenshotNotAvailableVlc;
  String get screenshotNotAvailableVlcMessage;
  String get screenshotFileNotFound;
  String get screenshotCannotOpenTab;
  String get screenshotErrorOpeningFolder;
  String get closeAction;
}
