import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_providers.dart';
import '../domain/account_info.dart';
import 'account_controller.dart';

/// Keep a guest log by adding a verified email and password, sign in to an
/// existing account, or sign out.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.initialSignIn = false});

  final bool initialSignIn;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final email = TextEditingController(), password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  AccountController get controller =>
      ref.read(accountControllerProvider(widget.initialSignIn).notifier);

  Future<void> signIn(AccountInfo account) async {
    final hasGuestLog =
        account.guest && ref.read(overviewProvider).value?.profile != null;
    if (hasGuestLog) {
      final proceed = await ConfirmationSheet.ask(
        context,
        title: 'Open another account?',
        message: 'This device will leave the guest log and open the existing account. Guest entries stay separate and can become inaccessible. Use guest upgrade to keep this log.',
        action: 'Open existing account',
      );
      if (!proceed || !mounted) return;
    }
    final done = await controller.signIn(email.text, password.text);
    password.clear();
    if (done && mounted) context.go(Routes.home);
  }

  Future<void> signOut() async {
    final yes = await ConfirmationSheet.ask(
      context,
      title: 'Sign out?',
      message: 'You can reopen this account by signing in again.',
      action: 'Sign out',
    );
    if (!yes || !mounted) return;
    final done = await controller.signOut();
    if (done && mounted) context.go(Routes.home);
  }

  Widget emailField(bool busy) => TextField(
    controller: email,
    enabled: !busy,
    keyboardType: TextInputType.emailAddress,
    maxLength: 254,
    autofillHints: const [AutofillHints.email],
    decoration: const InputDecoration(
      labelText: 'Email address',
      counterText: '',
    ),
  );

  Widget passwordField(bool busy, {required bool isNew}) => TextField(
    controller: password,
    enabled: !busy,
    obscureText: true,
    maxLength: 128,
    autofillHints: [isNew ? AutofillHints.newPassword : AutofillHints.password],
    decoration: const InputDecoration(labelText: 'Password', counterText: ''),
  );

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final state = ref.watch(accountControllerProvider(widget.initialSignIn));
    return Standalone(
      title: 'Account',
      body: demo
          ? const PageScroll(
              children: [
                EmptyState(
                  'Local demo',
                  'Configure a live Supabase project to sign in or keep a guest log across devices.',
                  icon: Icons.person_outline,
                ),
              ],
            )
          : ref
                .watch(accountProvider)
                .when(
                  loading: () => const PageScroll(
                    children: [LoadingState('Checking your account…')],
                  ),
                  error: (e, _) => PageScroll(
                    children: [
                      ErrorState(
                        failureMessage(e),
                        retry: () => ref.invalidate(accountProvider),
                      ),
                    ],
                  ),
                  data: (account) => _body(account, state),
                ),
    );
  }

  Widget _body(AccountInfo account, AccountState state) {
    final busy = state.busy;
    final linkPending =
        account.pendingEmail != null && account.emailConfirmed == false;
    final canSetPassword = account.emailConfirmed && account.email != null;
    return PageScroll(
      children: [
        PageHeading(
          state.signingIn
              ? 'Sign in to PlateWise'
              : account.guest
              ? 'Keep your guest log'
              : 'Your account',
          detail: state.signingIn
              ? 'Open the log linked to your permanent account.'
              : account.guest
              ? 'Verify an email, then set a password to keep the same log.'
              : account.email,
        ),
        const SizedBox(height: 13),
        if (state.error != null) ...[
          ErrorState(state.error!),
          const SizedBox(height: 8),
        ],
        if (state.notice != null) ...[
          Surface(child: Text(state.notice!)),
          const SizedBox(height: 8),
        ],
        if (state.signingIn) ...[
          AutofillGroup(
            child: Column(
              children: [
                emailField(busy),
                const SizedBox(height: 8),
                passwordField(busy, isNew: false),
              ],
            ),
          ),
          const SizedBox(height: 11),
          PrimaryButton(
            'Sign in',
            busy: busy,
            onPressed: () => signIn(account),
          ),
          SecondaryButton(
            'Back to account options',
            onPressed: busy
                ? null
                : () {
                    password.clear();
                    controller.showSignIn(false);
                  },
          ),
        ] else ...[
          if (account.guest && !canSetPassword) ...[
            if (linkPending) ...[
              Surface(
                child: Text(
                  'Verification is pending for ${account.pendingEmail}. Check your email, then return here.',
                ),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                'Check verification',
                onPressed: () => ref.invalidate(accountProvider),
              ),
            ],
            emailField(busy),
            const SizedBox(height: 8),
            PrimaryButton(
              linkPending ? 'Resend verification' : 'Link my email',
              busy: busy,
              onPressed: () => controller.linkEmail(email.text),
            ),
          ],
          if (canSetPassword && !state.passwordSaved) ...[
            const SizedBox(height: 8),
            const Text(
              'Use at least 10 characters and choose a unique password.',
            ),
            const SizedBox(height: 8),
            passwordField(busy, isNew: true),
            const SizedBox(height: 8),
            PrimaryButton(
              'Set account password',
              busy: busy,
              onPressed: () async {
                final saved = await controller.setPassword(password.text);
                if (saved) password.clear();
              },
            ),
          ],
          const SizedBox(height: 9),
          if (account.guest)
            SecondaryButton(
              'Sign in to an existing account',
              onPressed: busy ? null : () => controller.showSignIn(true),
            )
          else
            SecondaryButton('Sign out', onPressed: busy ? null : signOut),
        ],
      ],
    );
  }
}
