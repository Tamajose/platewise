import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app_language.dart';
import 'translate.dart';

export 'app_language.dart';

/// Translation for widgets. Each call depends on the app's locale, so a screen
/// that uses it is rebuilt when the person switches language.
extension L10nContext on BuildContext {
  AppLanguage get language =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);

  /// The English [key], translated, with `{name}` placeholders filled from [args].
  String tr(String key, [Map<String, Object?> args = const {}]) =>
      translate(language, key, args);

  /// A number with separators, in Bangla digits in Bangla mode.
  String number(num value) => formatNumber(language, value);

  /// A date format in the current language. Bangla month and day names need
  /// the locale data loaded at start-up, so English is used where it is not.
  DateFormat dateFormat(String pattern) {
    if (language == AppLanguage.bn) {
      try {
        return DateFormat(pattern, 'bn');
      } on Object {
        /* The Bangla data is not loaded. */
      }
    }
    return DateFormat(pattern);
  }

  /// The time of day, such as 6:30 PM, in the current language.
  DateFormat get timeFormat {
    if (language == AppLanguage.bn) {
      try {
        return DateFormat.jm('bn');
      } on Object {
        /* The Bangla data is not loaded. */
      }
    }
    return DateFormat.jm();
  }

  /// Builds the `0/300` counter under a limited text field, with its digits
  /// written for the current language.
  InputCounterWidgetBuilder get counterBuilder =>
      (context, {required currentLength, required isFocused, maxLength}) =>
          Text(digits('$currentLength/$maxLength'));

  /// [text] with its digits written for the current language.
  String digits(String text) => localizeDigits(language, text);
}
