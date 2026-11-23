import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/format/number_format.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'settings_controller.dart';

/// Profile summary, account, language, privacy and data deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

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
              ? 'Delete your account?'
              : demo
              ? 'Clear this demo?'
              : 'Delete your app data?',
          message: account
              ? 'This permanently removes your profile, logs, corrections, photos and sign-in identity.'
              : demo
              ? 'This removes the profile and all local demo logs on this device.'
              : 'This removes your profile, logs, corrections and photos. Your sign-in identity stays available.',
          action: account ? 'Delete account' : 'Delete data',
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
      SnackBar(content: Text(account ? 'Account deleted' : 'Data deleted')),
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
      title: 'Settings',
      body: ref
          .watch(overviewProvider)
          .when(
            loading: () =>
                const PageScroll(children: [LoadingState('Loading settings…')]),
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
                  const PageHeading('Profile & privacy'),
                  const SizedBox(height: 14),
                  if (state.error != null) ...[
                    ErrorState(state.error!),
                    const SizedBox(height: 10),
                  ],
                  if (busy) const LoadingState('Working on your request…'),
                  if (value.deletionPending) ...[
                    const ErrorState(
                      'Deletion is pending. Resume the request to remove any remaining data.',
                    ),
                    const SizedBox(height: 9),
                    PrimaryButton(
                      value.deletionAccount
                          ? 'Resume account deletion'
                          : 'Resume data deletion',
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
                            const SectionTitle('Profile'),
                            const SizedBox(height: 8),
                            Text(
                              'BMI ${profile.bmi.toStringAsFixed(1)} · ${profile.zone}',
                            ),
                            Text(
                              profile.target == null
                                  ? 'No calorie target'
                                  : 'Daily target ${number(profile.target!)} kcal',
                            ),
                            Text(
                              'Water goal ${number(profile.waterGoal)} ml · ${profile.units == 'us' ? 'US' : 'Metric'} units',
                            ),
                            const SizedBox(height: 9),
                            const DisclaimerNotice(
                              text: 'BMI is a screening measure. PlateWise does not give medical advice.',
                            ),
                            const SizedBox(height: 9),
                            SecondaryButton(
                              'Edit profile and goals',
                              onPressed: () => context.push(Routes.profile),
                            ),
                            TextButton(
                              onPressed: () => context.push(Routes.energy),
                              child: const Text('Estimate adult energy needs'),
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
                          const SectionTitle('Account'),
                          const SizedBox(height: 6),
                          Text(
                            demo ? 'Changes stay on this device in demo mode.' : 'Keep the same guest ID when adding a verified email and password.',
                          ),
                          if (!demo)
                            TextButton(
                              onPressed: () => context.push(Routes.account),
                              child: const Text('Manage account'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle('Language'),
                          const SizedBox(height: 5),
                          const Text('App interface: English'),
                          Text(
                            'Bangla text analysis: ${capability?.banglaText == true ? 'enabled by this deployment' : 'unavailable'}',
                          ),
                          Text(
                            'Bangla speech: ${capability?.banglaSpeech == true ? 'enabled by this deployment' : 'unavailable'}',
                          ),
                          const Text(
                            'You can type Bangla food names in manual entry.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle('Data and privacy'),
                          const SizedBox(height: 7),
                          Text(
                            demo
                                ? 'Demo data is stored locally in this app. Use sample information.'
                                : 'Meals and photos stay private to your account. Live analysis sends the selected input to the configured provider. Avoid personal information in photos, recordings and descriptions.',
                          ),
                          const SizedBox(height: 6),
                          if (!demo && profile != null) ...[
                            Material(
                              type: MaterialType.transparency,
                              child: SwitchListTile(
                                value: profile.correctionConsent,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Allow correction contributions',
                                ),
                                subtitle: const Text(
                                  'Opt in to submit a curated food, portion and range. Turning it off removes your queued contributions.',
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
                                child: const Text('Submit a food correction'),
                              ),
                          ],
                          if (value.pendingAssets > 0)
                            SecondaryButton(
                              'Retry photo cleanup',
                              onPressed: busy
                                  ? null
                                  : controller.retryPhotoCleanup,
                            ),
                          const SizedBox(height: 7),
                          if (!demo)
                            const Text(
                              'Unconfirmed photos are eligible for cleanup after 24 hours. Raw recordings are processed in memory. Provider logs and backups follow their retention policies.',
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
                              demo ? 'Clear demo data' : 'Delete app data',
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
                              child: const Text('Delete account'),
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
                          title: const Text('Credits and licenses'),
                          subtitle: const Text(
                            'Team, datasets and open-source libraries',
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
