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

  // Gallery
  String get imageGallery;
  String get videoGallery;

  // Storage locations
  String get local;
  String get networks;
}
