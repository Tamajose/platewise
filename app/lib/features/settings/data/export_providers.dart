import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_export.dart'
    if (dart.library.io) 'save_export_native.dart'
    as files;

const _key = 'platewise.export_permission';

/// Whether this device may export the person's statistics. It is off until the
/// person turns it on under Data and privacy, and the choice stays on this
/// device, because the exported file leaves the app's protection on this device.
class ExportPermission extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await SharedPreferencesAsync().getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> set(bool allowed) async {
    state = AsyncData(allowed);
    try {
      await SharedPreferencesAsync().setBool(_key, allowed);
    } on Object {
      /* The choice still holds until the app closes. */
    }
  }
}

final exportPermissionProvider = AsyncNotifierProvider<ExportPermission, bool>(
  ExportPermission.new,
);

/// Saves export text as a file and says where it went. Replaced in tests.
final saveExportProvider = Provider<Future<String> Function(String, String)>(
  (ref) => files.saveExport,
);
