import 'app_localizations.dart';

class EnglishLocalizations implements AppLocalizations {
  @override
  String get appTitle => 'CoolBird - File Manager';

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

  // Gallery
  @override
  String get imageGallery => 'Image Gallery';
  @override
  String get videoGallery => 'Video Gallery';
}
