import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  // Singleton pattern
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // Keys for shared preferences
  static const String _languageCodeKey = 'language_code';
  static const String _countryCodeKey = 'country_code';

  // Available languages
  static const List<Map<String, dynamic>> languages = [
    {'name': 'English', 'locale': Locale('en', 'US')},
    {'name': '日本語', 'locale': Locale('ja', 'JP')},
    {'name': '한국어', 'locale': Locale('ko', 'KR')},
    {'name': 'Español', 'locale': Locale('es', 'ES')},
    {'name': 'Français', 'locale': Locale('fr', 'FR')},
    {'name': 'Deutsch', 'locale': Locale('de', 'DE')},
    {'name': 'Tiếng Việt', 'locale': Locale('vi', 'VN')},
  ];

  // Default locale
  final Locale defaultLocale = const Locale('en', 'US');

  // Get the current locale
  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String languageCode = prefs.getString(_languageCodeKey) ?? defaultLocale.languageCode;
    final String countryCode = prefs.getString(_countryCodeKey) ?? defaultLocale.countryCode!;
    
    return Locale(languageCode, countryCode);
  }

  // Set the locale
  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, locale.languageCode);
    await prefs.setString(_countryCodeKey, locale.countryCode ?? '');
  }

  // Get the language name from locale
  String getLanguageName(Locale locale) {
    try {
      return languages.firstWhere(
        (language) => language['locale'].languageCode == locale.languageCode,
        orElse: () => languages.first,
      )['name'];
    } catch (e) {
      return languages.first['name'];
    }
  }
}
