import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class StaffUpdateDownload {
  const StaffUpdateDownload({
    required this.file,
    required this.sizeBytes,
    required this.sha256,
  });

  final File file;
  final int sizeBytes;
  final String sha256;
}

class StaffUpdateDownloader {
  Future<StaffUpdateDownload> download({
    required Uri url,
    required int expectedSize,
    required String expectedSha256,
    required int versionCode,
    void Function(double progress)? onProgress,
  }) async {
    final normalizedSha = expectedSha256.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalizedSha)) {
      throw const FormatException('Expected update SHA256 is invalid.');
    }

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'pharmaflow-staff-update-$versionCode.apk',
    );

    if (await file.exists()) {
      await file.delete();
    }

    final client = HttpClient();

    try {
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'APK download returned HTTP ${response.statusCode}.',
          uri: url,
        );
      }

      final sink = file.openWrite();
      var received = 0;

      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);

          if (expectedSize > 0 && onProgress != null) {
            onProgress((received / expectedSize).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.close();
      }

      final size = await file.length();

      if (size != expectedSize) {
        await file.delete();

        throw StateError(
          'Downloaded APK size mismatch. '
          'Expected $expectedSize, got $size.',
        );
      }

      final digest = await sha256.bind(file.openRead()).first;

      final actualSha = digest.toString().toLowerCase();

      if (actualSha != normalizedSha) {
        await file.delete();

        throw StateError('Downloaded APK SHA256 mismatch.');
      }

      return StaffUpdateDownload(
        file: file,
        sizeBytes: size,
        sha256: actualSha,
      );
    } finally {
      client.close(force: true);
    }
  }
}
