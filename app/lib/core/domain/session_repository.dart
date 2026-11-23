/// What the connected service can do. Flags are false in demo mode.
typedef Capabilities = ({bool liveAi, bool banglaText, bool banglaSpeech});

/// Owns the private session every other repository relies on.
abstract interface class SessionRepository {
  /// True when running against local sample data instead of a backend.
  bool get isDemo;

  /// Opens the session. Safe to call repeatedly and concurrently.
  Future<void> bootstrap();

  Future<Capabilities> capabilities();
}
