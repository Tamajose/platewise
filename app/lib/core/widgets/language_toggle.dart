import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../l10n/language_providers.dart';

/// Switches the whole app between English and Bangla. Each language is named
/// in its own script, so it can be found even when the app is in the other one.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      segments: [
        for (final language in AppLanguage.values)
          ButtonSegment(value: language, label: Text(language.nativeName)),
      ],
      selected: {current},
      onSelectionChanged: (choice) =>
          ref.read(appLanguageProvider.notifier).set(choice.first),
    );
  }
}

/// An icon button for app bars that switches to the other language. Its
/// tooltip names that language.
class LanguageSwitchButton extends ConsumerWidget {
  const LanguageSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    final other = current == AppLanguage.en ? AppLanguage.bn : AppLanguage.en;
    return IconButton(
      onPressed: () => ref.read(appLanguageProvider.notifier).set(other),
      tooltip: context.tr(
        other == AppLanguage.bn ? 'Switch to Bangla' : 'Switch to English',
      ),
      icon: const Icon(Icons.translate_rounded),
    );
  }
}
