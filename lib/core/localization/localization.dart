import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Russian is the base language; Kazakh and English are wired in so adding
/// translations is only an ARB edit (ТЗ п.24.1, п.24.15).
abstract final class AppLocalization {
  static const supportedLocales = [Locale('ru'), Locale('kk'), Locale('en')];
  static const fallbackLocale = Locale('ru');

  static const delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static Locale? resolve(Locale? device, Iterable<Locale> supported) {
    if (device == null) return fallbackLocale;
    for (final locale in supported) {
      if (locale.languageCode == device.languageCode) return locale;
    }
    return fallbackLocale;
  }
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
