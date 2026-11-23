import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/overview.dart';
import '../json.dart';
import '../mappers/overview_mapper.dart';

/// Holds the demo data: one [Overview] kept in local preferences. Every
/// feature's demo repository reads and changes it here, so changes made in one
/// feature show up in the others.
class DemoStore {
  DemoStore(this._preferences);

  /// The preferences key. It matches earlier builds, so existing browser
  /// profiles keep their demo data.
  static const key = 'platewise.demo.v1';

  final SharedPreferencesAsync _preferences;
  Overview _state = const Overview();
  Future<void>? _load;
  Future<void> _pending = Future.value();

  /// The current data. The first call loads it from preferences.
  Future<Overview> read() async {
    await (_load ??= _readFromPreferences());
    return _state;
  }

  /// Applies [transform] and saves the result. Updates run one at a time in
  /// the order they were requested.
  Future<void> update(Overview Function(Overview current) transform) async {
    await (_load ??= _readFromPreferences());
    final future = _pending.then((_) async {
      final state = transform(_state);
      await _preferences.setString(
        key,
        jsonEncode(overviewToStoredJson(state)),
      );
      _state = state;
    });
    _pending = future.catchError((Object _) {});
    return future;
  }

  Future<void> _readFromPreferences() async {
    final raw = await _preferences.getString(key);
    if (raw == null) return;
    try {
      _state = overviewFromJson(Json.from(jsonDecode(raw) as Map));
    } on FormatException {
      _state = const Overview();
    } on TypeError {
      _state = const Overview();
    }
  }
}
