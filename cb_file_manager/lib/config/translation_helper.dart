import 'package:flutter/material.dart';
import 'languages/app_localizations.dart';

// Extension to make it easier to access translations
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this)!;
}
