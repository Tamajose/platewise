import '../../../core/data/api/api_client.dart';
import '../../../core/data/demo/demo_store.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/profile_repository.dart';

class LiveProfileRepository implements ProfileRepository {
  LiveProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> save(Profile profile, {required bool targetConfirmed}) async {
    await _api.call(
      'update_profile',
      profileToJson(profile, confirmed: targetConfirmed),
    );
  }
}

class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this._store);

  final DemoStore _store;

  @override
  Future<void> save(Profile profile, {required bool targetConfirmed}) async {
    if (targetError(profile.target) case final String error) {
      throw Failure(error, code: 'TARGET_RANGE');
    }
    if (profile.target != null && !targetConfirmed) {
      throw const Failure('Confirm the adult target guidance to continue.');
    }
    final day = dayKey(localTime(DateTime.now(), profile.zone));
    await _store.update(
      (state) => state.copyWith(
        profile: profile,
        // A changed target applies from today. Earlier days keep the target
        // they had.
        targets:
            state.profile == null || state.profile?.target != profile.target
            ? ([
                ...state.targets.where((t) => t.day != day),
                TargetSnapshot(day, profile.target),
              ]..sort((a, b) => a.day.compareTo(b.day)))
            : state.targets,
      ),
    );
  }
}
