import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int maxOrderPhotoBytes = 200 * 1024;

class OptimizedOrderPhoto {
  const OptimizedOrderPhoto({required this.bytes, required this.originalSize});

  final Uint8List bytes;
  final int originalSize;
}

class OrderPhotoOptimizer {
  static OptimizedOrderPhoto optimize(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);

    if (decoded == null) {
      throw const FormatException('Selected image could not be decoded.');
    }

    var working = decoded;

    const maxDimension = 1600;

    if (working.width > maxDimension || working.height > maxDimension) {
      if (working.width >= working.height) {
        working = img.copyResize(working, width: maxDimension);
      } else {
        working = img.copyResize(working, height: maxDimension);
      }
    }

    for (var scalePass = 0; scalePass < 5; scalePass++) {
      for (final quality in <int>[82, 74, 66, 58, 50, 42, 34]) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(working, quality: quality),
        );

        if (encoded.length <= maxOrderPhotoBytes) {
          return OptimizedOrderPhoto(
            bytes: encoded,
            originalSize: sourceBytes.length,
          );
        }
      }

      final nextWidth = (working.width * 0.82).round();

      final nextHeight = (working.height * 0.82).round();

      if (nextWidth < 480 || nextHeight < 480) {
        break;
      }

      working = img.copyResize(working, width: nextWidth, height: nextHeight);
    }

    throw StateError('Photo could not be compressed below 200KB.');
  }
}
