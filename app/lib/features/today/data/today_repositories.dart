import '../../../core/data/api/api_client.dart';
import '../../../core/data/demo/demo_store.dart';
import '../domain/today_repository.dart';

class LiveTodayRepository implements TodayRepository {
  LiveTodayRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> deleteMeal(String id) async {
    await _api.call('delete_meal', {'id': id});
  }
}

class DemoTodayRepository implements TodayRepository {
  DemoTodayRepository(this._store);

  final DemoStore _store;

  @override
  Future<void> deleteMeal(String id) => _store.update(
    (state) =>
        state.copyWith(meals: state.meals.where((m) => m.id != id).toList()),
  );
}
