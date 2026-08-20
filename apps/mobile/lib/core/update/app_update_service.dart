import '../network/api_client.dart';
import '../network/api_constants.dart';
import 'android_update_manifest.dart';
import 'app_update_decision.dart';
import 'app_version_info.dart';
import 'app_version_reader.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.manifest,
    required this.decision,
  });

  final AppVersionInfo currentVersion;
  final AndroidUpdateManifest manifest;
  final AppUpdateDecision decision;
}

class AppUpdateService {
  AppUpdateService({
    required this._apiClient,
    this._versionReader = const AppVersionReader(),
  });

  final ApiClient _apiClient;
  final AppVersionReader _versionReader;

  Future<AppUpdateCheckResult> check() async {
    final currentVersion = await _versionReader.read();

    final payload = await _apiClient.get(ApiConstants.androidAppUpdateEndpoint);

    if (payload is! Map) {
      throw const ApiDecodingException(
        'Expected a JSON object from Android app update endpoint.',
      );
    }

    final manifest = AndroidUpdateManifest.fromJson(
      Map<String, dynamic>.from(payload),
    );

    final decision = evaluateAppUpdate(
      manifest: manifest,
      currentVersionCode: currentVersion.versionCode,
    );

    return AppUpdateCheckResult(
      currentVersion: currentVersion,
      manifest: manifest,
      decision: decision,
    );
  }
}
