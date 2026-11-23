import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => throw StateError('Onboarding repository initialization required'),
);
