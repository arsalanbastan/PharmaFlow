import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/config/app_config.dart';

void main() {
  test('compile-time API base URL overrides the persisted profile', () {
    const configuredBaseUrl = String.fromEnvironment('PHARMAFLOW_API_BASE_URL');

    final config = AppConfig.defaults();
    final expectedBaseUrl = configuredBaseUrl.trim().isEmpty
        ? 'https://naughty-haslett-zvtszb2yr.liara.run:443/api/v1'
        : configuredBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');

    expect(config.baseUrl, expectedBaseUrl);
  });
}
