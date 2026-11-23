import 'dart:typed_data';

import '../../domain/media_storage.dart';

/// Demo mode keeps no photos, so there is nothing to store or clean up.
class DemoMediaStorage implements MediaStorage {
  const DemoMediaStorage();

  @override
  Future<String?> upload(Uint8List bytes) async => null;

  @override
  Future<void> discard(String? path) async {}

  @override
  Future<void> retryCleanup() async {}
}
