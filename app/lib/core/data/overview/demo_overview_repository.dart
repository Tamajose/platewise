import '../../domain/overview.dart';
import '../../domain/overview_repository.dart';
import '../demo/demo_store.dart';

class DemoOverviewRepository implements OverviewRepository {
  DemoOverviewRepository(this._store);

  final DemoStore _store;

  @override
  Future<Overview> overview() => _store.read();
}
