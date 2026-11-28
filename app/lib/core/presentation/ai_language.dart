import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_state.dart';
import '../l10n/app_language.dart';
import '../l10n/language_providers.dart';

/// The language code the AI is asked to answer in. It follows the app's
/// language, but only where the deployment has Bangla analysis turned on, and
/// is English otherwise, so a request never fails over the language.
final aiLanguageProvider = Provider<String>((ref) {
  final app = ref.watch(appLanguageProvider);
  final banglaReady = ref.watch(capabilitiesProvider).value?.banglaText == true;
  return app == AppLanguage.bn && banglaReady ? 'bn' : 'en';
});
