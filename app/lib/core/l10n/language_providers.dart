import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

const _key = 'platewise.language';

/// The language the app is shown in. English until the person switches, and
/// the choice is remembered on this device. It also decides which language the
/// AI is asked to answer in.
class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return AppLanguage.en;
  }

  Future<void> _load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_key);
      if (saved != null && ref.mounted) state = AppLanguage.fromCode(saved);
    } on Object {
      /* English stays. */
    }
  }

  Future<void> set(AppLanguage language) async {
    state = language;
    try {
      await SharedPreferencesAsync().setString(_key, language.code);
    } on Object {
      /* The choice still holds until the app closes. */
    }
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );
