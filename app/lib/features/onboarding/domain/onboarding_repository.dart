abstract interface class OnboardingRepository {
  /// Whether this build can fill the log with a sample week to explore.
  bool get offersSampleDay;

  /// Replaces the log with a sample profile, meals and water. Only valid when
  /// [offersSampleDay] is true.
  Future<void> startSampleDay();
}
