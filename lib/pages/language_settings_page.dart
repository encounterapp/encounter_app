import 'package:flutter/material.dart';
import 'package:encounter_app/services/language_service.dart';
import 'package:provider/provider.dart';
import 'package:encounter_app/providers/locale_provider.dart';
import 'package:encounter_app/l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale = localeProvider.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).selectLanguage),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: LanguageService.languages.length,
        itemBuilder: (context, index) {
          final language = LanguageService.languages[index];
          final locale = language['locale'] as Locale;
          final isSelected = currentLocale.languageCode == locale.languageCode;
          
          return ListTile(
            title: Text(language['name']),
            trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () async {
              if (!isSelected) {
                await localeProvider.setLocale(locale);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          );
        },
      ),
    );
  }
}

