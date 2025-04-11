import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:encounter_app/providers/locale_provider.dart';
import 'package:encounter_app/services/language_service.dart';
import 'package:encounter_app/l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.languageSettings),
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: LanguageService.languages.length,
        itemBuilder: (context, index) {
          final language = LanguageService.languages[index];
          final locale = language['locale'] as Locale;
          
          return ListTile(
            title: Text(language['name']),
            trailing: localeProvider.isLocaleSelected(locale)
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              localeProvider.setLocale(locale);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${language['name']} ${localizations.selectLanguage}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          );
        },
      ),
    );
  }
}