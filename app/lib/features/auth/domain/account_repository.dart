import 'account_info.dart';

abstract interface class AccountRepository {
  /// Whether the person is a guest, and the state of any email link.
  Future<AccountInfo> account();

  /// Starts linking [email] to the guest account. Supabase sends a
  /// verification message when verification is enabled.
  Future<void> linkEmail(String email);

  /// Sets the password of an account whose email is verified.
  Future<void> setPassword(String password);

  /// Opens an existing account. The guest log stays behind.
  Future<void> signIn(String email, String password);

  /// Ends the session on this device.
  Future<void> signOut();
}
