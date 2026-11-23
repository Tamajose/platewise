import 'dart:typed_data';

/// Private storage for the photos a person analyses.
abstract interface class MediaStorage {
  /// Stores [bytes] and returns the storage path, or null when this build
  /// keeps no photos (demo mode).
  Future<String?> upload(Uint8List bytes);

  /// Deletes a photo that was uploaded but never attached to a saved meal.
  Future<void> discard(String? path);

  /// Asks the service to delete photos whose cleanup failed earlier.
  Future<void> retryCleanup();
}
