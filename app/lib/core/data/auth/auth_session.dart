import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/failure.dart';

/// The signed-in person's session, as far as data sources need to know it.
abstract interface class AuthSession {
  /// The user's ID, or null when no session exists.
  String? get userId;

  /// Opens an anonymous session when none exists.
  Future<void> ensureSession();

  /// A valid access token, refreshing an expired one.
  Future<String> bearer();
}

class SupabaseAuthSession implements AuthSession {
  SupabaseAuthSession(this.client);

  /// Exposed so account features can use the other auth operations.
  final SupabaseClient client;

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  Future<void> ensureSession() async {
    try {
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously().timeout(
          const Duration(seconds: 12),
        );
      }
    } on Object {
      throw const Failure(
        'Could not open a private session. Check the connection or try again.',
        retryable: true,
      );
    }
  }

  @override
  Future<String> bearer() async {
    final session = client.auth.currentSession;
    if (session != null && !session.isExpired) return session.accessToken;
    if (session != null) {
      try {
        final result = await client.auth.refreshSession().timeout(
          const Duration(seconds: 10),
        );
        if (result.session != null) return result.session!.accessToken;
      } on Object {
        throw const Failure(
          'Your private session could not be renewed. Check the connection and try again.',
          code: 'SESSION_REQUIRED',
          retryable: true,
        );
      }
    }
    throw const Failure(
      'Your private session expired. Open PlateWise to continue.',
      code: 'SESSION_REQUIRED',
      retryable: true,
    );
  }
}
