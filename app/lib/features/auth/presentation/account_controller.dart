import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../data/account_providers.dart';
import '../domain/account_rules.dart';

class AccountState {
  const AccountState({
    this.signingIn = false,
    this.busy = false,
    this.passwordSaved = false,
    this.error,
    this.notice,
  });

  /// Showing the sign-in form instead of the upgrade options.
  final bool signingIn;
  final bool busy, passwordSaved;
  final String? error, notice;

  AccountState copyWith({
    bool? signingIn,
    bool? busy,
    bool? passwordSaved,
    String? error,
    String? notice,
    bool clearMessages = false,
  }) => AccountState(
    signingIn: signingIn ?? this.signingIn,
    busy: busy ?? this.busy,
    passwordSaved: passwordSaved ?? this.passwordSaved,
    error: clearMessages ? null : error ?? this.error,
    notice: clearMessages ? null : notice ?? this.notice,
  );
}

/// State of the account screen: guest upgrade, sign in and sign out.
class AccountController extends Notifier<AccountState> {
  AccountController(this.startSigningIn);

  final bool startSigningIn;

  @override
  AccountState build() => AccountState(signingIn: startSigningIn);

  void showSignIn(bool value) =>
      state = state.copyWith(signingIn: value, clearMessages: true);

  void fail(String message) =>
      state = state.copyWith(error: message, clearMessages: false);

  Future<bool> linkEmail(String email) {
    if (!isValidEmail(email)) {
      fail(emailMessage);
      return Future.value(false);
    }
    return _run(
      () => ref.read(accountRepositoryProvider).linkEmail(email.trim()),
      notice: 'Email link requested. If verification is enabled, check your inbox before setting a password.',
    );
  }

  Future<bool> setPassword(String password) {
    if (password.length < minPasswordLength) {
      fail(passwordLengthMessage);
      return Future.value(false);
    }
    return _run(
      () async {
        await ref.read(accountRepositoryProvider).setPassword(password);
        state = state.copyWith(passwordSaved: true);
      },
      notice: 'Password saved. You can sign in with this email and access the same log.',
    );
  }

  /// Signs in. On success the app starts again with the other account's data,
  /// so the caller leaves the screen.
  Future<bool> signIn(String email, String password) {
    if (!isValidEmail(email) || password.isEmpty) {
      fail(signInInputMessage);
      return Future.value(false);
    }
    return _run(
      () => ref.read(accountRepositoryProvider).signIn(email.trim(), password),
      reload: true,
    );
  }

  Future<bool> signOut() =>
      _run(() => ref.read(accountRepositoryProvider).signOut(), reload: true);

  Future<bool> _run(
    Future<void> Function() action, {
    String? notice,
    bool reload = false,
  }) async {
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      await action();
      if (!ref.mounted) return true;
      if (reload) {
        ref.invalidate(overviewProvider);
        ref.invalidate(capabilitiesProvider);
      } else {
        ref.invalidate(accountProvider);
      }
      state = state.copyWith(busy: false, notice: notice);
      return true;
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
      return false;
    }
  }
}

final accountControllerProvider = NotifierProvider.autoDispose
    .family<AccountController, AccountState, bool>(AccountController.new);
