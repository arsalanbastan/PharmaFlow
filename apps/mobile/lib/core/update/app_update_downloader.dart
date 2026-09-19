import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

typedef UpdateDownloadProgressCallback =
    void Function(int receivedBytes, int totalBytes);

typedef UpdateDirectoryProvider = Future<Directory> Function();

class VerifiedUpdateDownload {
  const VerifiedUpdateDownload({
    required this.file,
    required this.sizeBytes,
    required this.sha256,
  });

  final File file;
  final int sizeBytes;
  final String sha256;
}

class AppUpdateDownloadException implements Exception {
  const AppUpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateDownloader {
  AppUpdateDownloader({Dio? dio, UpdateDirectoryProvider? directoryProvider})
    : _dio = dio ?? Dio(),
      _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  final Dio _dio;
  final UpdateDirectoryProvider _directoryProvider;

  Future<VerifiedUpdateDownload> downloadAndVerify({
    required String url,
    required int versionCode,
    required int expectedSizeBytes,
    required String expectedSha256,
    UpdateDownloadProgressCallback? onProgress,
  }) async {
    if (versionCode <= 0) {
      throw const AppUpdateDownloadException('Invalid update version code.');
    }

    if (expectedSizeBytes <= 0) {
      throw const AppUpdateDownloadException(
        'Invalid expected update file size.',
      );
    }

    final normalizedExpectedSha256 = expectedSha256.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalizedExpectedSha256)) {
      throw const AppUpdateDownloadException('Invalid expected SHA-256.');
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const AppUpdateDownloadException('Invalid APK download URL.');
    }

    final rootDirectory = await _directoryProvider();

    final updateDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}pharmaflow_updates',
    );

    if (!await updateDirectory.exists()) {
      await updateDirectory.create(recursive: true);
    }

    final file = File(
      '${updateDirectory.path}'
      '${Platform.pathSeparator}'
      'pharmaflow-$versionCode.apk',
    );

    if (await file.exists()) {
      await file.delete();
    }

    try {
      await _dio.download(
        url,
        file.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );

      if (!await file.exists()) {
        throw const AppUpdateDownloadException(
          'Downloaded APK file was not created.',
        );
      }

      final actualSize = await file.length();

      if (actualSize != expectedSizeBytes) {
        await _deleteIfExists(file);

        throw AppUpdateDownloadException(
          'APK file size mismatch. '
          'Expected $expectedSizeBytes bytes, '
          'received $actualSize bytes.',
        );
      }

      final digest = await sha256.bind(file.openRead()).first;
      final actualSha256 = digest.toString().toLowerCase();

      if (actualSha256 != normalizedExpectedSha256) {
        await _deleteIfExists(file);

        throw const AppUpdateDownloadException(
          'APK SHA-256 verification failed.',
        );
      }

      return VerifiedUpdateDownload(
        file: file,
        sizeBytes: actualSize,
        sha256: actualSha256,
      );
    } on DioException catch (error) {
      await _deleteIfExists(file);

      throw AppUpdateDownloadException(
        'APK download failed: ${error.message ?? error.type.name}',
      );
    } on AppUpdateDownloadException {
      rethrow;
    } catch (error) {
      await _deleteIfExists(file);

      throw AppUpdateDownloadException('Unexpected APK download error: $error');
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}
