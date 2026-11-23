import '../../domain/overview.dart';
import '../../domain/overview_repository.dart';
import '../api/api_client.dart';
import '../mappers/overview_mapper.dart';

class LiveOverviewRepository implements OverviewRepository {
  LiveOverviewRepository(this._api);

  final ApiClient _api;

  @override
  Future<Overview> overview() async =>
      overviewFromJson(await _api.call('dashboard'));
}
