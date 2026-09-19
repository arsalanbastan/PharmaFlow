class AppVersionInfo {
  const AppVersionInfo({required this.versionName, required this.versionCode});

  final String versionName;
  final int versionCode;

  @override
  String toString() => '$versionName ($versionCode)';
}
