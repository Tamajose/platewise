import '../../../core/data/api/api_client.dart';
import '../../../core/data/demo/demo_store.dart';
import '../domain/weekly_report.dart';
import '../domain/weekly_repository.dart';

class LiveWeeklyRepository implements WeeklyRepository {
  LiveWeeklyRepository(this._api);

  final ApiClient _api;

  @override
  Future<WeeklySummary> summary() async {
    final data = await _api.call('weekly_summary');
    return (
      state: data['state'] as String,
      sentences: (data['sentences'] as List).cast<String>(),
    );
  }
}

/// Demo mode has no AI summary, so it states the same facts the screen shows.
class DemoWeeklyRepository implements WeeklyRepository {
  DemoWeeklyRepository(this._store);

  final DemoStore _store;

  @override
  Future<WeeklySummary> summary() async {
    final facts = WeeklyReport((await _store.read()).week).facts;
    return (state: facts.isEmpty ? 'insufficient' : 'local', sentences: facts);
  }
}
