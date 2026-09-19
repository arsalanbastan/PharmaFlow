import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ChequeImageDebugLogger {
  const ChequeImageDebugLogger._();

  static String describeBytes(Uint8List? bytes, {required String stage}) {
    if (bytes == null) {
      return '$stage: width=-, height=-, byteLength=0, estimatedKB=0';
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    final width = decoded?.width ?? -1;
    final height = decoded?.height ?? -1;
    final byteLength = bytes.lengthInBytes;
    final estimatedKilobytes = _estimatedKilobytes(byteLength);

    return '$stage: width=$width, height=$height, byteLength=$byteLength, estimatedKB=$estimatedKilobytes';
  }

  static String describeBase64Length(
    String? base64Value, {
    required String stage,
  }) {
    return '$stage: imageData: ${formatOmittedBase64(base64Value)}';
  }

  static String formatOmittedBase64(String? base64Value) {
    if (base64Value == null || base64Value.isEmpty) {
      return '<omitted, 0 KB>';
    }

    final estimatedBytes = (base64Value.length * 3) ~/ 4;
    final estimatedKilobytes = _estimatedKilobytes(estimatedBytes);
    return '<omitted, $estimatedKilobytes KB>';
  }

  static Map<String, dynamic> sanitizeSyncRequestBody(
    Map<String, dynamic> body,
  ) {
    return _sanitizeValue(body) as Map<String, dynamic>;
  }

  static String describeRequestBody(Map<String, dynamic> body) {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(sanitizeSyncRequestBody(body));
  }

  static int _estimatedKilobytes(int byteLength) {
    return (byteLength / 1024).ceil();
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key == 'imageData' && entry.value is String) {
          sanitized[entry.key] = formatOmittedBase64(entry.value as String);
        } else {
          sanitized[entry.key] = _sanitizeValue(entry.value);
        }
      }

      return sanitized;
    }

    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }

    return value;
  }
}
