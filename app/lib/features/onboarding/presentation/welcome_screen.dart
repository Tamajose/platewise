import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import '../data/onboarding_providers.dart';

/// Builds the profile form. The app supplies it, because the form belongs to
/// the profile feature and features cannot import each other.
typedef ProfileFormBuilder = Widget Function(VoidCallback onSaved);

/// The first screen for a new person: what PlateWise is for, and a way to set
/// up a profile or, in demo mode, explore a sample day.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, required this.profileForm});

  final ProfileFormBuilder profileForm;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool form = false, busy = false;
  String? error;

  Future<void> sample() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(onboardingRepositoryProvider).startSampleDay();
      ref.invalidate(overviewProvider);
      await ref.read(overviewProvider.future);
      if (mounted) context.go(Routes.today);
    } on Object catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching the overview opens the private session in the background, so
    // saving a profile works even right after the account was deleted.
    ref.watch(overviewProvider);
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final offersSample = ref
        .watch(onboardingRepositoryProvider)
        .offersSampleDay;
    const heading = PageHeading(
      'Decide before you eat',
      detail: 'Compare portions and calorie ranges. Review each estimate before saving it to your daily log.',
      prominent: true,
    );
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          ErrorState(error!, retry: sample),
          const SizedBox(height: 8),
        ],
        PrimaryButton(
          'Set up my profile',
          icon: Icons.arrow_forward_rounded,
          onPressed: busy ? null : () => setState(() => form = true),
        ),
        const SizedBox(height: 8),
        if (offersSample)
          SecondaryButton(
            'Explore a sample day',
            onPressed: busy ? null : sample,
          )
        else
          TextButton(
            onPressed: () => context.push(Routes.signIn),
            child: const Text('Sign in to an existing account'),
          ),
        if (busy) const LoadingState('Opening sample day…'),
        const SizedBox(height: 14),
        const DisclaimerNotice(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        actions: [
          if (demo)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: IndicatorTag('Demo mode')),
            ),
        ],
      ),
      body: form
          ? widget.profileForm(() => context.go(Routes.today))
          : PageScroll(
              maxWidth: 1080,
              children: [
                LayoutBuilder(
                  builder: (context, size) {
                    final wide =
                        size.maxWidth >= 745 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 20;
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 400,
                                    ),
                                    child: heading,
                                  ),
                                ),
                                const SizedBox(height: 25),
                                actions,
                              ],
                            ),
                          ),
                          const SizedBox(width: 42),
                          const Expanded(
                            flex: 5,
                            child: FoodPicture(editorial: true, height: 420),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const SizedBox(height: 18),
                        const FoodPicture(editorial: true, height: 203),
                        const SizedBox(height: 16),
                        actions,
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
