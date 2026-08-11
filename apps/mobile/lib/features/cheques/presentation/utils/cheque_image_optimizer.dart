import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ChequeImageOptimizer {
  const ChequeImageOptimizer._();

  static const int _maxBytes = 300 * 1024;
  static const int _maxWidth = 1200;
  static const int _startingQuality = 70;
  static const int _minQuality = 60;
  static const int _qualityStep = 5;

  static Uint8List optimize(Uint8List originalBytes) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw StateError('Unable to decode cheque image bytes.');
    }

    final needsResize = decoded.width > _maxWidth;
    final isJpeg = _looksLikeJpeg(originalBytes);

    if (!needsResize && isJpeg && originalBytes.lengthInBytes <= _maxBytes) {
      return originalBytes;
    }

    final resized = _resizeToMaxWidth(decoded, _maxWidth);
    return _encodeJpegWithinBudget(resized);
  }

  static Uint8List _encodeJpegWithinBudget(img.Image image) {
    Uint8List? last;

    for (
      var quality = _startingQuality;
      quality >= _minQuality;
      quality -= _qualityStep
    ) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(image, quality: quality),
      );
      last = encoded;

      if (encoded.lengthInBytes <= _maxBytes) {
        return encoded;
      }
    }

    return last ??
        Uint8List.fromList(img.encodeJpg(image, quality: _minQuality));
  }

  static img.Image _resizeToMaxWidth(img.Image source, int maxWidth) {
    if (source.width <= maxWidth) {
      return source;
    }

    final height = ((source.height * maxWidth) / source.width).round();
    return img.copyResize(
      source,
      width: maxWidth,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
  }

  static bool _looksLikeJpeg(Uint8List bytes) {
    if (bytes.lengthInBytes < 4) {
      return false;
    }

    return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }
}
