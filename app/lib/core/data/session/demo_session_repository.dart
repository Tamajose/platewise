import '../../domain/session_repository.dart';
import '../demo/demo_store.dart';

class DemoSessionRepository implements SessionRepository {
  DemoSessionRepository(this._store);

  final DemoStore _store;

  @override
  bool get isDemo => true;

  @override
  Future<void> bootstrap() => _store.read();

  @override
  Future<Capabilities> capabilities() async =>
      (liveAi: false, banglaText: false, banglaSpeech: false);
}
