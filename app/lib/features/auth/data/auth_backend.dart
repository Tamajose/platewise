import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/auth/auth_session.dart';

typedef BackendUser = ({
  bool anonymous,
  String? email,
  bool emailConfirmed,
  String? pendingEmail,
});

/// The account operations the repository needs from the auth service.
abstract interface class AuthBackend {
  Future<BackendUser> user();
  Future<void> setEmail(String email);
  Future<void> setPassword(String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}

/// Supabase Auth, with the timeouts the app waits for each call.
class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend(this._session);

  final SupabaseAuthSession _session;

  GoTrueClient get _auth => _session.client.auth;

  @override
  Future<BackendUser> user() async {
    final token = await _session.bearer();
    final user =
        (await _auth.getUser(token).timeout(const Duration(seconds: 10))).user!;
    String? blankToNull(String? value) =>
        value == null || value.isEmpty ? null : value;
    return (
      anonymous: user.isAnonymous,
      email: blankToNull(user.email),
      emailConfirmed: user.emailConfirmedAt != null,
      pendingEmail: blankToNull(user.newEmail),
    );
  }

  @override
  Future<void> setEmail(String email) async {
    await _auth
        .updateUser(UserAttributes(email: email))
        .timeout(const Duration(seconds: 12));
  }

  @override
  Future<void> setPassword(String password) async {
    await _auth
        .updateUser(UserAttributes(password: password))
        .timeout(const Duration(seconds: 12));
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth
        .signInWithPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> signOut() async {
    await _auth
        .signOut(scope: SignOutScope.local)
        .timeout(const Duration(seconds: 10));
  }
}
