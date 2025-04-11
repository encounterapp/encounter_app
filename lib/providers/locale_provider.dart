import 'package:flutter/material.dart';
import 'package:encounter_app/services/language_service.dart';

class LocaleProvider extends ChangeNotifier {
  final LanguageService _languageService = LanguageService();
  Locale _locale;

  LocaleProvider() : _locale = const Locale('en', 'US') {
    _loadSavedLocale();
  }

  Locale get locale => _locale;

  Future<void> _loadSavedLocale() async {
    _locale = await _languageService.getLocale();
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode && 
        _locale.countryCode == locale.countryCode) return;
    
    _locale = locale;
    await _languageService.setLocale(locale);
    notifyListeners();
  }
  
  // Method to check if a specific locale is currently selected
  bool isLocaleSelected(Locale checkLocale) {
    return _locale.languageCode == checkLocale.languageCode && 
           _locale.countryCode == checkLocale.countryCode;
  }
}