import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/format/number_format.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_providers.dart';
import '../domain/account_info.dart';
import 'account_controller.dart';

/// The person's own page: who they are, their body measures and goals, and the
/// way to manage the account or sign out.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  Future<void> signOut(
    BuildContext context,
    WidgetRef ref,
    AccountInfo account,
  ) async {
    final yes = await ConfirmationSheet.ask(
      context,
      title: 'Sign out?',
      message: account.guest
          ? 'This is a guest log. Without a linked email it cannot be reopened after you sign out. Link an email first to keep it.'
          : 'You can reopen this account by signing in again.',
      action: 'Sign out',
      danger: account.guest,
    );
    if (!yes || !context.mounted) return;
    final done = await ref
        .read(accountControllerProvider(false).notifier)
        .signOut();
    // Nothing of the old account is left to show, so go straight to the
    // welcome screen, which the gate would choose anyway.
    if (done && context.mounted) context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    return Standalone(
      title: 'Profile',
      body: ref
          .watch(overviewProvider)
          .when(
            loading: () =>
                const PageScroll(children: [LoadingState('Loading profile…')]),
            error: (e, _) => PageScroll(
              children: [
                ErrorState(
                  failureMessage(e),
                  retry: () => ref.invalidate(overviewProvider),
                ),
              ],
            ),
            data: (overview) => demo
                ? _body(context, ref, overview.profile, demo: true)
                : ref
                      .watch(accountProvider)
                      .when(
                        loading: () => const PageScroll(
                          children: [LoadingState('Loading profile…')],
                        ),
                        error: (e, _) => _body(
                          context,
                          ref,
                          overview.profile,
                          demo: false,
                          problem: failureMessage(e),
                        ),
                        data: (account) => _body(
                          context,
                          ref,
                          overview.profile,
                          demo: false,
                          account: account,
                        ),
                      ),
          ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    Profile? profile, {
    required bool demo,
    AccountInfo? account,
    String? problem,
  }) {
    final state = ref.watch(accountControllerProvider(false));
    final imperial = profile?.units == 'us';
    final identity = demo
        ? 'Demo on this device'
        : account == null
        ? 'Signed in'
        : account.guest
        ? 'Guest'
        : account.email ?? 'Signed in';
    return PageScroll(
      children: [
        _Identity(
          title: identity,
          detail: demo
              ? 'Sample data stays on this device.'
              : account == null
              ? 'Your account details could not be loaded.'
              : account.guest
              ? 'Add an email to keep this log on any device.'
              : 'Signed in',
        ),
        const SizedBox(height: 18),
        if (state.error != null || problem != null) ...[
          ErrorState(
            state.error ?? problem!,
            retry: problem == null
                ? null
                : () => ref.invalidate(accountProvider),
          ),
          const SizedBox(height: 12),
        ],
        if (profile != null) ...[
          Row(
            children: [
              Expanded(
                child: _Stat(
                  'Daily target',
                  profile.target == null
                      ? 'Not set'
                      : '${number(profile.target!)} kcal',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat('Water goal', '${number(profile.waterGoal)} ml'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Surface(
            child: Column(
              children: [
                _Row(
                  'Height',
                  imperial
                      ? '${profile.displayHeight.toStringAsFixed(1)} in'
                      : '${profile.displayHeight.toStringAsFixed(0)} cm',
                ),
                _Row(
                  'Weight',
                  imperial
                      ? '${profile.displayWeight.toStringAsFixed(1)} lb'
                      : '${profile.displayWeight.toStringAsFixed(1)} kg',
                ),
                _Row(
                  'BMI',
                  '${profile.bmi.toStringAsFixed(1)} · screening only',
                ),
                _Row('Units', imperial ? 'US' : 'Metric'),
                _Row('Time zone', profile.zone, last: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            'Edit profile and goals',
            icon: Icons.tune_rounded,
            onPressed: () => context.push(Routes.profile),
          ),
        ] else
          const Surface(
            child: Text(
              'Your profile is not set up yet. Open the app again to finish setup.',
            ),
          ),
        const SizedBox(height: 22),
        Surface(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                if (account != null)
                  _Link(
                    icon: Icons.manage_accounts_outlined,
                    title: account.guest ? 'Keep this log' : 'Account',
                    detail: account.guest
                        ? 'Link an email or sign in to another account'
                        : 'Email and password',
                    onTap: () async {
                      await context.push(Routes.account);
                      ref.invalidate(accountProvider);
                    },
                  ),
                _Link(
                  icon: Icons.file_download_outlined,
                  title: 'Export stats',
                  detail: 'Daily calories and water as a spreadsheet',
                  onTap: () => context.push(Routes.export),
                ),
                _Link(
                  icon: Icons.shield_outlined,
                  title: 'Settings and privacy',
                  detail: 'Language, data and deletion',
                  onTap: () => context.push(Routes.settings),
                ),
              ],
            ),
          ),
        ),
        if (account != null) ...[
          const SizedBox(height: 18),
          SecondaryButton(
            'Sign out',
            icon: Icons.logout_rounded,
            onPressed: state.busy ? null : () => signOut(context, ref, account),
          ),
        ],
        const SizedBox(height: 14),
        const DisclaimerNotice(
          text: 'BMI is a screening measure. PlateWise does not give medical advice.',
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.title, required this.detail});
  final String title, detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: PlateColors.deep,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: PlateColors.lime,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: t.bodyMedium?.copyWith(color: PlateColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: PlateColors.muted),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.last = false});
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12, top: 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: PlateColors.muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: PlateColors.forest),
    title: Text(title),
    subtitle: Text(detail),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
