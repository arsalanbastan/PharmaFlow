import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/update/app_update_downloader.dart';

void main() {
  late Directory tempDirectory;
  late HttpServer server;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'pharmaflow_update_test_',
    );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('downloads and verifies exact APK bytes', () async {
    final bytes = List<int>.generate(8192, (index) => index % 251);

    final expectedSha = sha256.convert(bytes).toString();

    unawaited(
      server.first.then((request) async {
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      }),
    );

    final url = 'http://${server.address.host}:${server.port}/app.apk';

    final downloader = AppUpdateDownloader(
      directoryProvider: () async => tempDirectory,
    );

    var latestReceived = 0;

    final result = await downloader.downloadAndVerify(
      url: url,
      versionCode: 2,
      expectedSizeBytes: bytes.length,
      expectedSha256: expectedSha,
      onProgress: (received, total) {
        latestReceived = received;
      },
    );

    expect(await result.file.exists(), isTrue);
    expect(await result.file.readAsBytes(), bytes);
    expect(result.sizeBytes, bytes.length);
    expect(result.sha256, expectedSha);
    expect(latestReceived, bytes.length);
  });

  test('deletes file when SHA-256 does not match', () async {
    final bytes = <int>[1, 2, 3, 4, 5];

    unawaited(
      server.first.then((request) async {
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      }),
    );

    final url = 'http://${server.address.host}:${server.port}/app.apk';

    final downloader = AppUpdateDownloader(
      directoryProvider: () async => tempDirectory,
    );

    await expectLater(
      downloader.downloadAndVerify(
        url: url,
        versionCode: 3,
        expectedSizeBytes: bytes.length,
        expectedSha256: 'a' * 64,
      ),
      throwsA(isA<AppUpdateDownloadException>()),
    );

    final file = File(
      '${tempDirectory.path}'
      '${Platform.pathSeparator}'
      'pharmaflow_updates'
      '${Platform.pathSeparator}'
      'pharmaflow-3.apk',
    );

    expect(await file.exists(), isFalse);
  });

  test('deletes file when size does not match', () async {
    final bytes = <int>[10, 20, 30];

    unawaited(
      server.first.then((request) async {
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      }),
    );

    final url = 'http://${server.address.host}:${server.port}/app.apk';

    final downloader = AppUpdateDownloader(
      directoryProvider: () async => tempDirectory,
    );

    await expectLater(
      downloader.downloadAndVerify(
        url: url,
        versionCode: 4,
        expectedSizeBytes: 999,
        expectedSha256: sha256.convert(bytes).toString(),
      ),
      throwsA(isA<AppUpdateDownloadException>()),
    );

    final file = File(
      '${tempDirectory.path}'
      '${Platform.pathSeparator}'
      'pharmaflow_updates'
      '${Platform.pathSeparator}'
      'pharmaflow-4.apk',
    );

    expect(await file.exists(), isFalse);
  });
}

void unawaited(Future<void> future) {}
