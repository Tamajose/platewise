import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// The longest side of an uploaded photo, in pixels.
const maxPhotoSide = 1500;

/// Straightens, shrinks and re-encodes a photo as JPEG. Re-encoding drops any
/// embedded location and device metadata. Returns null when [source] is not an
/// image.
Uint8List? preparePhoto(Uint8List source) {
  var image = im.decodeImage(source);
  if (image == null) return null;
  image = im.bakeOrientation(image);
  if (image.width > maxPhotoSide || image.height > maxPhotoSide) {
    image = image.width >= image.height
        ? im.copyResize(image, width: maxPhotoSide)
        : im.copyResize(image, height: maxPhotoSide);
  }
  final clean = im.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  im.compositeImage(clean, image);
  return im.encodeJpg(clean, quality: 84);
}
