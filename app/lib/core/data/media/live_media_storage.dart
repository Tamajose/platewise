import 'dart:typed_data';

import '../../domain/failure.dart';
import '../../domain/media_storage.dart';
import '../api/api_client.dart';
import '../auth/auth_session.dart';
import '../ids.dart';

/// Writes one object to private storage. The composition root supplies the
/// Supabase implementation, which keeps this class free of the SDK.
typedef ObjectUpload = Future<void> Function(String path, Uint8List bytes);

/// Photos live in the person's own folder of the private `meal-media` bucket.
class LiveMediaStorage implements MediaStorage {
  LiveMediaStorage({
    required this._auth,
    required this._api,
    required this._upload,
    this._generateId = newId,
    this.timeout = const Duration(seconds: 20),
  });

  final AuthSession _auth;
  final ApiClient _api;
  final ObjectUpload _upload;
  final IdGenerator _generateId;
  final Duration timeout;

  @override
  Future<String?> upload(Uint8List bytes) async {
    final user = _auth.userId;
    if (user == null) {
      throw const Failure('Your session expired. Open PlateWise again.');
    }
    final path = '$user/${_generateId()}.jpg';
    try {
      await _upload(path, bytes).timeout(timeout);
      return path;
    } on Object {
      throw const Failure(
        'The photo could not be uploaded. Check your connection, choose a smaller photo, or enter the meal manually.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> discard(String? path) async {
    if (path != null) {
      await _api.call('discard_photo', {'image_storage_path': path});
    }
  }

  @override
  Future<void> retryCleanup() async {
    await _api.call('retry_media_cleanup');
  }
}
