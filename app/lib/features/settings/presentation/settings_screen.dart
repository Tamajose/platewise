import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/export_providers.dart';
import 'settings_controller.dart';
import '../../../core/l10n/l10n.dart';

/// Profile summary, account, language, privacy and data deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(message))));

  Future<void> erase(
    BuildContext context,
    WidgetRef ref, {
    required bool account,
    required bool demo,
    required bool pending,
  }) async {
    final proceed =
        pending ||
        await ConfirmationSheet.ask(
          context,
          title: account
              ? context.tr('Delete your account?')
              : demo
              ? context.tr('Clear this demo?')
              : context.tr('Delete your app data?'),
          message: account
              ? context.tr(
                  'This permanently removes your profile, logs, corrections, photos and sign-in identity.',
                )
              : demo
              ? context.tr(
                  'This removes the profile and all local demo logs on this device.',
                )
              : context.tr(
                  'This removes your profile, logs, corrections and photos. Your sign-in identity stays available.',
                ),
          action: account
              ? context.tr('Delete account')
              : context.tr('Delete data'),
          danger: true,
        );
    if (!proceed || !context.mounted) return;
    final done = await ref
        .read(settingsControllerProvider.notifier)
        .erase(account: account);
    if (!done || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Nothing is left to show, so go straight to the welcome screen.
    context.go(Routes.welcome);
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.tr(account ? 'Account deleted' : 'Data deleted')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final capability = ref.watch(capabilitiesProvider).value;
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final busy = state.busy;
    return Standalone(
      title: context.tr('Settings'),
      body: ref
          .watch(overviewProvider)
          .when(
            loading: () => PageScroll(
              children: [LoadingState(context.tr('Loading settings…'))],
            ),
            error: (e, _) => PageScroll(
              children: [
                ErrorState(
                  failureMessage(e),
                  retry: () => ref.invalidate(overviewProvider),
                ),
              ],
            ),
            data: (value) {
              final profile = value.profile;
              return PageScroll(
                children: [
                  PageHeading(context.tr('Profile & privacy')),
                  const SizedBox(height: 14),
                  if (state.error != null) ...[
                    ErrorState(state.error!),
                    const SizedBox(height: 10),
                  ],
                  if (busy)
                    LoadingState(context.tr('Working on your request…')),
                  if (value.deletionPending) ...[
                    ErrorState(
                      context.tr(
                        'Deletion is pending. Resume the request to remove any remaining data.',
                      ),
                    ),
                    const SizedBox(height: 9),
                    PrimaryButton(
                      value.deletionAccount
                          ? context.tr('Resume account deletion')
                          : context.tr('Resume data deletion'),
                      busy: busy,
                      onPressed: () => erase(
                        context,
                        ref,
                        account: value.deletionAccount,
                        demo: demo,
                        pending: true,
                      ),
                    ),
                  ] else ...[
                    if (profile != null) ...[
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionTitle(context.tr('Profile')),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('BMI {p0} · {p1}', {
                                'p0': profile.bmi.toStringAsFixed(1),
                                'p1': profile.zone,
                              }),
                            ),
                            Text(
                              profile.target == null
                                  ? context.tr('No calorie target')
                                  : context.tr('Daily target {p0} kcal', {
                                      'p0': context.number(profile.target!),
                                    }),
                            ),
                            Text(
                              context.tr('Water goal {p0} ml · {p1} units', {
                                'p0': context.number(profile.waterGoal),
                                'p1': context.tr(
                                  profile.units == 'us' ? 'US' : 'Metric',
                                ),
                              }),
                            ),
                            const SizedBox(height: 9),
                            DisclaimerNotice(
                              text: context.tr(
                                'BMI is a screening measure. PlateWise does not give medical advice.',
                              ),
                            ),
                            const SizedBox(height: 9),
                            SecondaryButton(
                              context.tr('Edit profile and goals'),
                              onPressed: () => context.push(Routes.profile),
                            ),
                            TextButton(
                              onPressed: () => context.push(Routes.energy),
                              child: Text(
                                context.tr('Estimate adult energy needs'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(context.tr('Account')),
                          const SizedBox(height: 6),
                          Text(
                            demo
                                ? context.tr(
                                    'Changes stay on this device in demo mode.',
                                  )
                                : context.tr(
                                    'Keep the same guest ID when adding a verified email and password.',
                                  ),
                          ),
                          if (!demo)
                            TextButton(
                              onPressed: () => context.push(Routes.account),
                              child: Text(context.tr('Manage account')),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(context.tr('Language')),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              "Language of the app and of the AI's answers.",
                            ),
                          ),
                          const SizedBox(height: 10),
                          const LanguageToggle(),
                          const SizedBox(height: 10),
                          Text(
                            context.tr('Bangla text analysis: {p0}', {
                              'p0': context.tr(
                                capability?.banglaText == true
                                    ? 'enabled by this deployment'
                                    : 'unavailable',
                              ),
                            }),
                          ),
                          Text(
                            context.tr('Bangla speech: {p0}', {
                              'p0': context.tr(
                                capability?.banglaSpeech == true
                                    ? 'enabled by this deployment'
                                    : 'unavailable',
                              ),
                            }),
                          ),
                          Text(
                            context.tr(
                              'The AI answers in Bangla only where this deployment has Bangla turned on. Otherwise it answers in English.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(context.tr('Data and privacy')),
                          const SizedBox(height: 7),
                          Text(
                            demo
                                ? context.tr(
                                    'Demo data is stored locally in this app. Use sample information.',
                                  )
                                : context.tr(
                                    'Meals and photos stay private to your account. Live analysis sends the selected input to the configured provider. Avoid personal information in photos, recordings and descriptions.',
                                  ),
                          ),
                          const SizedBox(height: 6),
                          if (!demo && profile != null) ...[
                            Material(
                              type: MaterialType.transparency,
                              child: SwitchListTile(
                                value: profile.correctionConsent,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.tr('Allow correction contributions'),
                                ),
                                subtitle: Text(
                                  context.tr(
                                    'Opt in to submit a curated food, portion and range. Turning it off removes your queued contributions.',
                                  ),
                                ),
                                onChanged: busy
                                    ? null
                                    : controller.setCorrectionConsent,
                              ),
                            ),
                            if (profile.correctionConsent)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => context.push(Routes.correction),
                                child: Text(
                                  context.tr('Submit a food correction'),
                                ),
                              ),
                          ],
                          Material(
                            type: MaterialType.transparency,
                            child: SwitchListTile(
                              value:
                                  ref.watch(exportPermissionProvider).value ??
                                  false,
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.tr('Allow data export')),
                              subtitle: Text(
                                context.tr(
                                  'Lets this device save your daily stats as a file. Off by default, and you can turn it off at any time.',
                                ),
                              ),
                              onChanged: busy
                                  ? null
                                  : (on) => ref
                                        .read(exportPermissionProvider.notifier)
                                        .set(on),
                            ),
                          ),
                          if (ref.watch(exportPermissionProvider).value ??
                              false)
                            TextButton(
                              onPressed: () => context.push(Routes.export),
                              child: Text(context.tr('Export my stats')),
                            ),
                          if (value.pendingAssets > 0)
                            SecondaryButton(
                              context.tr('Retry photo cleanup'),
                              onPressed: busy
                                  ? null
                                  : controller.retryPhotoCleanup,
                            ),
                          const SizedBox(height: 7),
                          if (!demo)
                            Text(
                              context.tr(
                                'Unconfirmed photos are eligible for cleanup after 24 hours. Raw recordings are processed in memory. Provider logs and backups follow their retention policies.',
                              ),
                            ),
                          const SizedBox(height: 9),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => erase(
                                    context,
                                    ref,
                                    account: false,
                                    demo: demo,
                                    pending: false,
                                  ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PlateColors.red,
                            ),
                            child: Text(
                              demo
                                  ? context.tr('Clear demo data')
                                  : context.tr('Delete app data'),
                            ),
                          ),
                          if (!demo)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => erase(
                                      context,
                                      ref,
                                      account: true,
                                      demo: false,
                                      pending: false,
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: PlateColors.red,
                              ),
                              child: Text(context.tr('Delete account')),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr('Credits and licenses')),
                          subtitle: Text(
                            context.tr(
                              'Team, datasets and open-source libraries',
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(Routes.credits),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
    );
  }
}
