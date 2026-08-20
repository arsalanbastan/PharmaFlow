import 'dart:convert';
import 'dart:io';

import 'staff_android_update_manifest.dart';

class StaffUpdateService {
  StaffUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  static const String _baseUrl = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );

  static final Uri manifestUri = Uri.parse(
    '$_baseUrl/app-update/staff/android',
  );

  final HttpClient _httpClient;

  Future<StaffAndroidUpdateManifest> check() async {
    final request = await _httpClient
        .getUrl(manifestUri)
        .timeout(const Duration(seconds: 15));

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 20));

    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Update server returned HTTP ${response.statusCode}.',
        uri: manifestUri,
      );
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Update manifest response is not a JSON object.',
      );
    }

    return StaffAndroidUpdateManifest.fromJson(decoded);
  }

  void close() {
    _httpClient.close(force: true);
  }
}
