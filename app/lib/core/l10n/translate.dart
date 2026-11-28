import 'package:intl/intl.dart';

import 'app_language.dart';
import 'bn_catalogue.dart';
import 'digits.dart';

/// Catalogue entries that hold `{p0}`-style placeholders, as patterns. They
/// translate English text that was built with the values already filled in,
/// such as a message that came back from the server.
final List<({RegExp pattern, String bangla})> _templates = _sorted([
  for (final entry in bnCatalogue.entries)
    // A template needs some fixed words, or it would match almost anything.
    if (entry.key.contains('{p') &&
        entry.key.replaceAll(RegExp(r'\{p\d+\}'), '').trim().length >= 4)
      (
        pattern: RegExp(
          '^${entry.key.splitMapJoin(RegExp(r'\{p\d+\}'), onMatch: (m) => '(.+?)', onNonMatch: RegExp.escape)}\$',
          dotAll: true,
        ),
        bangla: entry.value,
      ),
]);

/// The most specific templates first, so `Mean target: {p0} kcal` is tried
/// before the bare `{p0} kcal`.
List<({RegExp pattern, String bangla})> _sorted(
  List<({RegExp pattern, String bangla})> all,
) {
  int fixed(({RegExp pattern, String bangla}) t) =>
      t.pattern.pattern.replaceAll('(.+?)', '').length;
  return all..sort((a, b) => fixed(b).compareTo(fixed(a)));
}

String _fromTemplates(String text) {
  for (final template in _templates) {
    final match = template.pattern.firstMatch(text);
    if (match == null) continue;
    // Placeholders are numbered in the order they appear in the English text,
    // which is the order of the capture groups.
    var result = template.bangla;
    for (var i = 0; i < match.groupCount; i++) {
      result = result.replaceAll('{p$i}', match.group(i + 1)!);
    }
    return result;
  }
  return text;
}

/// Translates [key], the English text, into [language].
///
/// Placeholders such as `{p0}` are replaced from [args]. Text with no entry in
/// the catalogue stays in English, so a missing translation never breaks a
/// screen. In Bangla every digit in the result is written as a Bangla digit.
String translate(
  AppLanguage language,
  String key, [
  Map<String, Object?> args = const {},
]) {
  if (language == AppLanguage.en) {
    var text = key;
    args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }
  var text = bnCatalogue[key] ?? (args.isEmpty ? _fromTemplates(key) : key);
  args.forEach((name, value) {
    text = text.replaceAll('{$name}', '$value');
  });
  return toBanglaDigits(text);
}

/// Formats [value] with thousands separators, in Bangla digits when needed.
String formatNumber(AppLanguage language, num value) {
  final text = NumberFormat.decimalPattern('en').format(value);
  return language == AppLanguage.bn ? toBanglaDigits(text) : text;
}

/// Turns the digits in [text] into Bangla digits when [language] is Bangla.
String localizeDigits(AppLanguage language, String text) =>
    language == AppLanguage.bn ? toBanglaDigits(text) : text;
