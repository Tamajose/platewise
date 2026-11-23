import 'dart:typed_data';

enum PhotoSource { camera, gallery }

/// Takes or chooses a food photo. Meal logging and menu scanning both use it.
abstract interface class PhotoPicker {
  /// A photo ready to upload, or null when the person cancels.
  ///
  /// Throws a `Failure` when the photo is too large, cannot be read or access
  /// is denied.
  Future<Uint8List?> pick(PhotoSource source);
}
