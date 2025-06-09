import 'app_localizations.dart';

class EnglishLocalizations implements AppLocalizations {
  @override
  String get appTitle => 'CoolBird Tagify - File Manager';

  // Common actions
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get close => 'Close';
  @override
  String get search => 'Search';
  @override
  String get settings => 'Settings';

  // File operations
  @override
  String get copy => 'Copy';
  @override
  String get move => 'Move';
  @override
  String get rename => 'Rename';
  @override
  String get newFolder => 'New Folder';
  @override
  String get properties => 'Properties';
  @override
  String get openWith => 'Open with';

  // Navigation
  @override
  String get home => 'Home';
  @override
  String get back => 'Back';
  @override
  String get forward => 'Forward';
  @override
  String get refresh => 'Refresh';
  @override
  String get parentFolder => 'Parent Folder';
  @override
  String get local => 'Local';
  @override
  String get networks => 'Networks';

  // File types
  @override
  String get image => 'Image';
  @override
  String get video => 'Video';
  @override
  String get audio => 'Audio';
  @override
  String get document => 'Document';
  @override
  String get folder => 'Folder';
  @override
  String get file => 'File';

  // Settings
  @override
  String get language => 'Language';
  @override
  String get theme => 'Theme';
  @override
  String get darkMode => 'Dark Mode';
  @override
  String get lightMode => 'Light Mode';
  @override
  String get systemMode => 'System Mode';
  @override
  String get selectLanguage => 'Select the language you want to use';
  @override
  String get selectTheme => 'Choose the display theme for the app';
  @override
  String get selectThumbnailPosition =>
      'Choose the video thumbnail extraction position';
  @override
  String get systemThemeDescription => 'Follow the system theme settings';
  @override
  String get lightThemeDescription => 'Light interface for all screens';
  @override
  String get darkThemeDescription => 'Dark interface for all screens';
  @override
  String get vietnameseLanguage => 'Vietnamese';
  @override
  String get englishLanguage => 'English';

  // Messages
  @override
  String get fileDeleteConfirmation =>
      'Are you sure you want to delete this file?';
  @override
  String get folderDeleteConfirmation =>
      'Are you sure you want to delete this folder and all its contents?';
  @override
  String get fileDeleteSuccess => 'File deleted successfully';
  @override
  String get folderDeleteSuccess => 'Folder deleted successfully';
  @override
  String get operationFailed => 'Operation failed';

  // Tags
  @override
  String get tags => 'Tags';
  @override
  String get addTag => 'Add Tag';
  @override
  String get removeTag => 'Remove Tag';
  @override
  String get tagManagement => 'Tag Management';
  @override
  String get deleteTagConfirmation => 'Delete tag "%s"?';
  @override
  String get tagDeleteConfirmationText =>
      'This will remove the tag from all files. This action cannot be undone.';
  @override
  String get tagDeleted => 'Tag "%s" deleted successfully';
  @override
  String get errorDeletingTag => 'Error deleting tag: %s';
  @override
  String get chooseTagColor => 'Choose Color for "%s"';
  @override
  String get tagColorUpdated => 'Color for tag "%s" has been updated';
  @override
  String get allTags => 'All Tags';
  @override
  String get filesWithTag => 'Files with tag "%s"';
  @override
  String get tagsInDirectory => 'Tags in "%s"';
  @override
  String get aboutTags => 'About Tag Management';
  @override
  String get aboutTagsTitle => 'Introduction to tag management:';
  @override
  String get aboutTagsDescription =>
      'Tags help you organize files by adding custom labels. '
      'You can add or remove tags from files, and find all files with specific tags.';
  @override
  String get aboutTagsScreenDescription => '• All tags in your library\n'
      '• Files tagged with selected tag\n'
      '• Options to delete tags';
  @override
  String get deleteTag => 'Delete this tag from all files';

  // Gallery
  @override
  String get imageGallery => 'Image Gallery';
  @override
  String get videoGallery => 'Video Gallery';

  // Additional translations for database settings
  @override
  String get databaseSettings => 'Database Settings';
  @override
  String get databaseStorage => 'Database Storage';
  @override
  String get useObjectBox => 'Use ObjectBox Database';
  @override
  String get databaseDescription =>
      'Store tags and preferences in a local database';
  @override
  String get jsonStorage => 'Using JSON file for basic storage';
  @override
  String get objectBoxStorage =>
      'Using ObjectBox for efficient local database storage';

  // Cloud sync
  @override
  String get cloudSync => 'Cloud Sync';
  @override
  String get enableCloudSync => 'Enable Cloud Sync';
  @override
  String get cloudSyncDescription => 'Sync tags and preferences to the cloud';
  @override
  String get syncToCloud => 'Sync to Cloud';
  @override
  String get syncFromCloud => 'Sync from Cloud';
  @override
  String get cloudSyncEnabled =>
      'Tags and preferences will be synced to the cloud';
  @override
  String get cloudSyncDisabled => 'Cloud sync is disabled';
  @override
  String get enableObjectBoxForCloud =>
      'Enable ObjectBox database to use cloud sync';

  // Database statistics
  @override
  String get databaseStatistics => 'Database Statistics';
  @override
  String get totalUniqueTags => 'Total unique tags';
  @override
  String get taggedFiles => 'Tagged files';
  @override
  String get popularTags => 'Most Popular Tags';
  @override
  String get noTagsFound => 'No tags found';
  @override
  String get refreshStatistics => 'Refresh Statistics';

  // Import/Export
  @override
  String get importExportDatabase => 'Import/Export Database';
  @override
  String get backupRestoreDescription =>
      'Backup and restore your tags and file relationships';
  @override
  String get exportDatabase => 'Export Database';
  @override
  String get exportSettings => 'Export Settings';
  @override
  String get importDatabase => 'Import Database';
  @override
  String get importSettings => 'Import Settings';
  @override
  String get exportDescription => 'Save your tags to a file';
  @override
  String get importDescription => 'Restore your tags from a file';
  @override
  String get completeBackup => 'Complete Backup';
  @override
  String get completeRestore => 'Complete Restore';
  @override
  String get exportAllData => 'Export all settings and database data';
  @override
  String get importAllData => 'Import all settings and database data';

  // Export/Import messages
  @override
  String get exportSuccess => 'Successfully exported to: ';
  @override
  String get exportFailed => 'Export failed';
  @override
  String get importSuccess => 'Successfully imported';
  @override
  String get importFailed => 'Import failed or canceled';
  @override
  String get importCancelled => 'Import cancelled';
  @override
  String get errorExporting => 'Error exporting: ';
  @override
  String get errorImporting => 'Error importing: ';

  // Video thumbnails
  @override
  String get videoThumbnails => 'Video Thumbnails';
  @override
  String get thumbnailPosition => 'Thumbnail position:';
  @override
  String get percentOfVideo => 'percent of video';
  @override
  String get thumbnailDescription =>
      'Set the position in the video (as a percentage of total duration) where thumbnails will be extracted';
  @override
  String get thumbnailCache => 'Thumbnail Cache';
  @override
  String get thumbnailCacheDescription =>
      'Video thumbnails are cached to improve performance. If thumbnails appear outdated or you want to free up space, you can clear the cache.';
  @override
  String get clearThumbnailCache => 'Clear Thumbnail Cache';
  @override
  String get clearing => 'Clearing...';
  @override
  String get thumbnailCleared => 'All video thumbnails cleared';
  @override
  String get errorClearingThumbnail => 'Error clearing thumbnails: ';

  // New tab
  @override
  String get newTab => 'New Tab';

  // Admin access
  @override
  String get adminAccess => 'Admin Access';
  @override
  String get adminAccessRequired =>
      'This drive requires administrator privileges to access';

  // File system
  @override
  String get drives => 'Drives';
  @override
  String get system => 'System';

  // Settings data
  @override
  String get settingsData => 'Settings Data';
  @override
  String get viewManageSettings => 'View and manage settings data';

  // About app
  @override
  String get aboutApp => 'About App';
  @override
  String get appDescription => 'An advanced file management solution';
  @override
  String get version => 'Version';
  @override
  String get developer => 'Developer';

  // Empty state
  @override
  String get emptyFolder => 'Empty folder';
  @override
  String get noImagesFound => 'No images found in this folder';
  @override
  String get noVideosFound => 'No videos found in this folder';
  @override
  String get loading => 'Loading...';

  // File picker dialogs
  @override
  String get chooseBackupLocation => 'Choose backup location';
  @override
  String get chooseRestoreLocation => 'Choose Restore File';
  @override
  String get saveSettingsExport => 'Save Settings Export';
  @override
  String get saveDatabaseExport => 'Save Database Export';
  @override
  String get selectBackupFolder => 'Select Backup Folder';

  // File details
  @override
  String get fileSize => 'Size';
  @override
  String get fileLocation => 'Location';
  @override
  String get fileCreated => 'Created';
  @override
  String get fileModified => 'Modified';
  @override
  String get loadingVideo => 'Loading video...';
  @override
  String get errorLoadingImage => 'Error loading image';
  @override
  String get createCopy => 'Create copy';
  @override
  String get deleteFile => 'Delete File';

  // Sorting
  @override
  String get sort => 'Sort';
  @override
  String get sortByName => 'Sort by name';
  @override
  String get sortByPopularity => 'Sort by popularity';
  @override
  String get sortByRecent => 'Sort by recent';
  @override
  String get sortBySize => 'Sort by size';
  @override
  String get sortByDate => 'Sort by date';

  // Search errors
  @override
  String noFilesFoundTag(Map<String, String> args) =>
      'No files found with tag "${args['tag']}"';

  @override
  String noFilesFoundTagGlobal(Map<String, String> args) =>
      'No files found with tag "${args['tag']}" globally';

  @override
  String noFilesFoundTags(Map<String, String> args) =>
      'No files found with tags ${args['tags']}';

  @override
  String noFilesFoundTagsGlobal(Map<String, String> args) =>
      'No files found with tags ${args['tags']} globally';

  @override
  String errorSearchTag(Map<String, String> args) =>
      'Error searching by tag: ${args['error']}';

  @override
  String errorSearchTagGlobal(Map<String, String> args) =>
      'Error searching by tag globally: ${args['error']}';

  @override
  String errorSearchTags(Map<String, String> args) =>
      'Error searching by multiple tags: ${args['error']}';

  @override
  String errorSearchTagsGlobal(Map<String, String> args) =>
      'Error searching by multiple tags globally: ${args['error']}';

  // Search status
  @override
  String searchingTag(Map<String, String> args) =>
      'Searching for tag "${args['tag']}"...';

  @override
  String searchingTagGlobal(Map<String, String> args) =>
      'Searching for tag "${args['tag']}" globally...';

  @override
  String searchingTags(Map<String, String> args) =>
      'Searching for tags ${args['tags']}...';

  @override
  String searchingTagsGlobal(Map<String, String> args) =>
      'Searching for tags ${args['tags']} globally...';

  // Search UI
  @override
  String get searchTips => 'Search Tips';

  @override
  String get searchTipsTitle => 'Search Tips';

  @override
  String get viewTagSuggestions => 'View tag suggestions';

  @override
  String get globalSearchModeEnabled => 'Switched to global search';

  @override
  String get localSearchModeEnabled => 'Switched to current folder search';

  @override
  String get globalSearchMode => 'Searching globally (tap to switch)';

  @override
  String get localSearchMode => 'Searching current folder (tap to switch)';

  @override
  String get searchByFilename => 'Search by filename';

  @override
  String get searchByTags => 'Search by tags';

  @override
  String get searchMultipleTags => 'Search multiple tags';

  @override
  String get globalSearch => 'Global search';

  @override
  String get searchShortcuts => 'Shortcuts';

  @override
  String get searchHintText => 'Search files or use # to search by tags';

  @override
  String get searchHintTextTags => 'Search by tags... (e.g. #important #work)';

  @override
  String get suggestedTags => 'Suggested tags';

  @override
  String get noMatchingTags => 'No matching tags found';

  @override
  String get results => 'results';

  @override
  String get searchByFilenameDesc => 'Enter a filename to search.';

  @override
  String get searchByTagsDesc =>
      'Use the # symbol to search by tag. Example: #important';

  @override
  String get searchMultipleTagsDesc =>
      'Use multiple tags at once to filter results more precisely. Each tag needs a # symbol at the beginning and must be separated by spaces. Example: #work #urgent #2023';

  @override
  String get globalSearchDesc =>
      'Click on the folder/globe icon to toggle between searching the current folder and the entire system.';

  @override
  String get searchShortcutsDesc =>
      'Press Enter to start searching. Use arrow keys to select tags from suggestions.';

  // File operations related to networks
  @override
  String get download => 'Download';
  @override
  String get downloadFile => 'Download File';
  @override
  String get selectDownloadLocation => 'Select location to save the file:';
  @override
  String get selectFolder => 'Select folder';
  @override
  String get browse => 'Browse...';
  @override
  String get upload => 'Upload File';
  @override
  String get uploadFile => 'Upload File';
  @override
  String get selectFileToUpload => 'Select file to upload:';
  @override
  String get create => 'Create';
  @override
  String get folderName => 'Folder Name';
}
