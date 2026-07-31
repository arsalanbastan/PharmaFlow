import '../settings/connection_profile.dart';
import 'app_environment.dart';

class AppConfig {
  const AppConfig({required this.currentEnvironment, required this.settings});

  factory AppConfig.defaults({
    AppEnvironment environment = AppEnvironment.development,
  }) {
    return AppConfig(
      currentEnvironment: environment,
      settings: ConnectionSettingsDefaults.defaultSettings,
    );
  }

  final AppEnvironment currentEnvironment;
  final ConnectionSettings settings;

  ConnectionProfile get activeProfile => settings.activeProfile;

  String get host => activeProfile.host;

  int get port => activeProfile.port;

  String get apiVersion => activeProfile.apiVersion;

  bool get useHttps => activeProfile.useHttps;

  int get connectTimeout => activeProfile.connectTimeout;

  int get receiveTimeout => activeProfile.receiveTimeout;

  String get baseUrl {
    final scheme = useHttps ? 'https' : 'http';
    final version = apiVersion.startsWith('v') ? apiVersion : 'v$apiVersion';
    return '$scheme://$host:$port/api/$version';
  }
}
