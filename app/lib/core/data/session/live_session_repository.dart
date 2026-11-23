import '../../domain/session_repository.dart';
import '../api/api_client.dart';
import '../auth/auth_session.dart';

class LiveSessionRepository implements SessionRepository {
  LiveSessionRepository(this._auth, this._api);

  final AuthSession _auth;
  final ApiClient _api;
  Future<void>? _boot;

  @override
  bool get isDemo => false;

  @override
  Future<void> bootstrap() =>
      _boot ??= _auth.ensureSession().whenComplete(() => _boot = null);

  @override
  Future<Capabilities> capabilities() async {
    final data = await _api.call('capabilities');
    return (
      liveAi: data['live_ai'] == true,
      banglaText: data['bangla_text'] == true,
      banglaSpeech: data['bangla_speech'] == true,
    );
  }
}
