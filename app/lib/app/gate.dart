import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/presentation/failure_message.dart';
import '../core/presentation/session_state.dart';
import '../core/widgets/widgets.dart';
import 'entry_route.dart';

/// The first screen: opens a private session, then sends the person to where
/// they belong. Shows why when the session cannot open.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overviewProvider);
    if (state.hasValue && !state.isLoading && !state.hasError) {
      final route = entryRoute(state.requireValue);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(route);
      });
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
            const LoadingState('Opening PlateWise…'),
        ],
      ),
    );
  }
}
