import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/presentation/failure_message.dart';
import '../core/presentation/session_state.dart';
import '../core/widgets/widgets.dart';
import 'entry_route.dart';
import '../core/l10n/l10n.dart';

/// The first screen: opens a private session, then sends the person to where
/// they belong. Shows why when the session cannot open.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overviewProvider);
    if (state.hasValue && !state.isLoading && !state.hasError) {
      _goWhenSettled(context, entryRoute(state.requireValue));
    }
    return Scaffold(
      appBar: AppBar(title: const Wordmark()),
      body: PageScroll(
        children: [
          if (state.hasError)
            ErrorState(
              failureMessage(state.error!),
              retry: () => ref.invalidate(overviewProvider),
            )
          else
            LoadingState(context.tr('Opening PlateWise…')),
        ],
      ),
    );
  }

  /// Redirects once this page has finished sliding in. Leaving earlier would
  /// build the next screen while the previous one is still on its way out,
  /// and two copies of the shell cannot exist at once.
  void _goWhenSettled(BuildContext context, String route) {
    final animation = ModalRoute.of(context)?.animation;
    void go() {
      if (context.mounted) context.go(route);
    }

    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
      return;
    }
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      go();
    }

    animation.addStatusListener(listener);
  }
}
