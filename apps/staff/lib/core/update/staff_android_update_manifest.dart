class StaffAndroidUpdateManifest {
  const StaffAndroidUpdateManifest({
    required this.enabled,
    required this.platform,
    this.latestVersionName,
    this.latestVersionCode,
    this.minimumSupportedVersionCode,
    this.mandatory = false,
    this.apkUrl,
    this.sha256,
    this.fileSize,
    this.releaseNotes,
  });

  final bool enabled;
  final String platform;
  final String? latestVersionName;
  final int? latestVersionCode;
  final int? minimumSupportedVersionCode;
  final bool mandatory;
  final String? apkUrl;
  final String? sha256;
  final int? fileSize;
  final String? releaseNotes;

  bool updateAvailableFor(int currentVersionCode) {
    if (!enabled || latestVersionCode == null) {
      return false;
    }

    return latestVersionCode! > currentVersionCode;
  }

  bool isMandatoryFor(int currentVersionCode) {
    if (!updateAvailableFor(currentVersionCode)) {
      return false;
    }

    final minimum = minimumSupportedVersionCode;

    return mandatory || (minimum != null && currentVersionCode < minimum);
  }

  factory StaffAndroidUpdateManifest.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];

    if (enabled is! bool) {
      throw const FormatException('Update manifest enabled is invalid.');
    }

    final platform = json['platform'];

    if (platform is! String || platform.trim() != 'android') {
      throw const FormatException('Update manifest platform is invalid.');
    }

    if (!enabled) {
      return const StaffAndroidUpdateManifest(
        enabled: false,
        platform: 'android',
      );
    }

    final versionName = json['latestVersionName'];
    final versionCode = json['latestVersionCode'];
    final minimumCode = json['minimumSupportedVersionCode'];
    final mandatory = json['mandatory'];
    final apkUrl = json['apkUrl'];
    final sha256 = json['sha256'];
    final fileSize = json['fileSize'];

    if (versionName is! String || versionName.trim().isEmpty) {
      throw const FormatException('Update manifest version name is invalid.');
    }

    if (versionCode is! int || versionCode <= 0) {
      throw const FormatException('Update manifest version code is invalid.');
    }

    if (minimumCode is! int || minimumCode <= 0) {
      throw const FormatException(
        'Update manifest minimum version code is invalid.',
      );
    }

    if (mandatory is! bool) {
      throw const FormatException('Update manifest mandatory flag is invalid.');
    }

    if (apkUrl is! String) {
      throw const FormatException('Update manifest APK URL is invalid.');
    }

    final parsedUrl = Uri.tryParse(apkUrl);

    if (parsedUrl == null ||
        !(parsedUrl.scheme == 'http' || parsedUrl.scheme == 'https') ||
        parsedUrl.host.isEmpty) {
      throw const FormatException('Update manifest APK URL is invalid.');
    }

    if (sha256 is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Update manifest SHA256 is invalid.');
    }

    if (fileSize is! int || fileSize <= 0) {
      throw const FormatException('Update manifest file size is invalid.');
    }

    return StaffAndroidUpdateManifest(
      enabled: true,
      platform: 'android',
      latestVersionName: versionName.trim(),
      latestVersionCode: versionCode,
      minimumSupportedVersionCode: minimumCode,
      mandatory: mandatory,
      apkUrl: apkUrl,
      sha256: sha256.toLowerCase(),
      fileSize: fileSize,
      releaseNotes: json['releaseNotes']?.toString(),
    );
  }
}
