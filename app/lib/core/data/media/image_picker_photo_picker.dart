import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/failure.dart';
import '../../domain/photo_picker.dart';
import 'photo_processing.dart';

const _maxSourceBytes = 14 * 1024 * 1024;
const _maxUploadBytes = 5 * 1024 * 1024;

/// Takes photos with the camera or gallery through the `image_picker` plugin.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (image == null) return null;
      if (await image.length() > _maxSourceBytes) {
        throw const Failure(
          'Choose a smaller photo up to 14 MB before compression.',
        );
      }
      final result = await compute(preparePhoto, await image.readAsBytes());
      if (result == null || result.length > _maxUploadBytes) {
        throw const Failure(
          'Could not prepare this photo. Try JPEG, PNG or WebP.',
        );
      }
      return result;
    } on Failure {
      rethrow;
    } on Object {
      throw const Failure(
        'Photo access is unavailable. Check camera or gallery permissions, or enter your meal as text.',
      );
    }
  }
}
