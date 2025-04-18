import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'english_localizations.dart';
import 'vietnamese_localizations.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'vi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Return the appropriate localization implementation based on language code
    switch (locale.languageCode) {
      case 'en':
        return EnglishLocalizations();
      case 'vi':
      default:
        return VietnameseLocalizations();
    }
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
