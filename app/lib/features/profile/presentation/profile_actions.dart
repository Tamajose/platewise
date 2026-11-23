import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/data/core_providers.dart';
import '../domain/profile_rules.dart';

/// Saves the profile form.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  /// Checks and saves [input], then reloads the overview. Returns null on
  /// success, or the message to show.
  Future<String?> save(ProfileInput input) async {
    final built = buildProfile(input);
    if (built.profile == null) return built.error;
    try {
      await _ref
          .read(profileRepositoryProvider)
          .save(built.profile!, targetConfirmed: input.targetConfirmed);
      _ref.invalidate(overviewProvider);
      await _ref.read(overviewProvider.future);
      return null;
    } on Object catch (e) {
      return failureMessage(e);
    }
  }
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
