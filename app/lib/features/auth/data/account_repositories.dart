import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/domain/failure.dart';
import '../domain/account_info.dart';
import '../domain/account_repository.dart';
import 'auth_backend.dart';

/// Turns whatever the auth service threw into a message a person can act on.
Failure authFailure(Object error) {
  if (error is Failure) return error;
  final code = error is AuthException ? error.code : null;
  return switch (code) {
    'email_exists' ||
    'user_already_exists' ||
    'identity_already_exists' => const Failure(
      'That email already belongs to an account. Your guest log is still here. Use a different email to keep it, or sign in to the existing account separately.',
      code: 'ACCOUNT_EXISTS',
    ),
    'invalid_credentials' => const Failure(
      'The email or password did not match. Check both and try again.',
    ),
    'email_not_confirmed' => const Failure(
      'Verify your email before signing in.',
    ),
    'weak_password' => const Failure(
      'Choose a stronger password for this account.',
    ),
    'over_email_send_rate_limit' || 'over_request_rate_limit' => const Failure(
      'Please wait before requesting another email.',
      retryable: true,
    ),
    _ => const Failure(
      'Could not complete the account request. Check your connection and try again.',
      retryable: true,
    ),
  };
}

class LiveAccountRepository implements AccountRepository {
  LiveAccountRepository(this._backend);

  final AuthBackend _backend;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw authFailure(e);
    }
  }

  @override
  Future<AccountInfo> account() => _guard(() async {
    final user = await _backend.user();
    return (
      guest: user.anonymous,
      email: user.email,
      emailConfirmed: user.emailConfirmed,
      pendingEmail: user.pendingEmail,
    );
  });

  @override
  Future<void> linkEmail(String email) =>
      _guard(() => _backend.setEmail(email));

  @override
  Future<void> setPassword(String password) => _guard(() async {
    final user = await _backend.user();
    if (!user.emailConfirmed || user.email == null) {
      throw const Failure('Verify your email first.');
    }
    await _backend.setPassword(password);
  });

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => _backend.signIn(email, password));

  @override
  Future<void> signOut() => _guard(_backend.signOut);
}

/// Demo mode has no accounts. The data stays on this device.
class DemoAccountRepository implements AccountRepository {
  const DemoAccountRepository();

  static const _unavailable = Failure('Accounts are unavailable in demo mode.');

  @override
  Future<AccountInfo> account() async =>
      (guest: true, email: null, emailConfirmed: false, pendingEmail: null);

  @override
  Future<void> linkEmail(String email) async => throw _unavailable;

  @override
  Future<void> setPassword(String password) async => throw _unavailable;

  @override
  Future<void> signIn(String email, String password) async =>
      throw _unavailable;

  @override
  Future<void> signOut() async {}
}
