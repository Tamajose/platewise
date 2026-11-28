import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import 'profile_form.dart';
import '../../../core/l10n/l10n.dart';

/// Edit the saved profile. Closes when saved.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Standalone(
    title: context.tr('Profile'),
    body: ref
        .watch(overviewProvider)
        .when(
          loading: () => PageScroll(
            children: [LoadingState(context.tr('Loading your profile…'))],
          ),
          error: (e, _) => PageScroll(
            children: [
              ErrorState(
                failureMessage(e),
                retry: () => ref.invalidate(overviewProvider),
              ),
            ],
          ),
          data: (overview) => ProfileForm(
            initial: overview.profile,
            onSaved: () => context.pop(),
          ),
        ),
  );
}
