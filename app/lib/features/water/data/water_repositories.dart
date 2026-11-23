import '../../../core/data/api/api_client.dart';
import '../../../core/data/demo/demo_store.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/domain/domain.dart';
import '../domain/water_repository.dart';

class LiveWaterRepository implements WaterRepository {
  LiveWaterRepository(this._api);

  final ApiClient _api;

  @override
  Future<WaterEntry> save(String id, int amount, {String? revision}) async =>
      waterEntryFromJson(
        await _api.call(revision == null ? 'log_water' : 'edit_water', {
          'id': id,
          'amount_ml': amount,
          'expected_updated_at': ?revision,
        }),
      );

  @override
  Future<void> remove(String id) async {
    await _api.call('delete_water', {'id': id});
  }
}

class DemoWaterRepository implements WaterRepository {
  DemoWaterRepository(this._store);

  final DemoStore _store;

  /// Entries removed in this session. Saving one again is refused, as the
  /// service does, so an undone entry cannot come back from a late retry.
  final _removed = <String>{};

  @override
  Future<WaterEntry> save(String id, int amount, {String? revision}) async {
    if (amount < 1 || amount > maxWaterEntryMl) {
      throw const Failure('Use a water amount between 1 and 2,000 ml.');
    }
    WaterEntry? stored;
    await _store.update((state) {
      final entry = state.water.where((w) => w.id == id).firstOrNull;
      if (revision == null && entry != null) {
        stored = entry;
        return state;
      }
      if (_removed.contains(id) ||
          (revision != null && entry?.revision != revision)) {
        throw const Failure('That water entry changed. Open it again.');
      }
      final now = DateTime.now().toUtc();
      final next = WaterEntry(
        id,
        entry?.at ?? now,
        amount,
        now.toIso8601String(),
      );
      stored = next;
      return state.copyWith(
        water: [...state.water.where((w) => w.id != id), next],
      );
    });
    return stored!;
  }

  @override
  Future<void> remove(String id) => _store.update((state) {
    if (state.water.any((w) => w.id == id)) _removed.add(id);
    return state.copyWith(water: state.water.where((w) => w.id != id).toList());
  });
}
