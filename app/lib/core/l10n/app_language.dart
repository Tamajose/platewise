import 'dart:ui' show Locale;

/// The languages the interface can be shown in.
enum AppLanguage {
  en('en', 'English'),
  bn('bn', 'বাংলা');

  const AppLanguage(this.code, this.nativeName);

  /// The code the backend and the stored choice use.
  final String code;

  /// The language's name, written in that language.
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => en);
}
