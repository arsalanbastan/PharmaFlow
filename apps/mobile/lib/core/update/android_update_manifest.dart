class AndroidUpdateManifest {
  const AndroidUpdateManifest({
    required this.enabled,
    required this.platform,
    this.latestVersionName,
    this.latestVersionCode,
    this.minimumSupportedVersionCode,
    this.mandatory,
    this.apkUrl,
    this.sha256,
    this.fileSize,
    this.releaseNotes,
    this.publishedAt,
  });

  factory AndroidUpdateManifest.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];

    if (enabled is! bool) {
      throw const FormatException(
        'Update manifest field "enabled" must be a boolean.',
      );
    }

    final platform = json['platform'];

    if (platform is! String || platform != 'android') {
      throw const FormatException('Update manifest platform must be android.');
    }

    if (!enabled) {
      return const AndroidUpdateManifest(enabled: false, platform: 'android');
    }

    final latestVersionName = json['latestVersionName'];
    final latestVersionCode = json['latestVersionCode'];
    final minimumSupportedVersionCode = json['minimumSupportedVersionCode'];
    final mandatory = json['mandatory'];
    final apkUrl = json['apkUrl'];
    final sha256 = json['sha256'];
    final fileSize = json['fileSize'];

    if (latestVersionName is! String || latestVersionName.trim().isEmpty) {
      throw const FormatException(
        'Update manifest latestVersionName is invalid.',
      );
    }

    if (latestVersionCode is! int || latestVersionCode <= 0) {
      throw const FormatException(
        'Update manifest latestVersionCode is invalid.',
      );
    }

    if (minimumSupportedVersionCode is! int ||
        minimumSupportedVersionCode <= 0) {
      throw const FormatException(
        'Update manifest minimumSupportedVersionCode is invalid.',
      );
    }

    if (mandatory is! bool) {
      throw const FormatException('Update manifest mandatory is invalid.');
    }

    if (apkUrl is! String || apkUrl.trim().isEmpty) {
      throw const FormatException('Update manifest apkUrl is invalid.');
    }

    if (sha256 is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Update manifest sha256 is invalid.');
    }

    if (fileSize is! int || fileSize <= 0) {
      throw const FormatException('Update manifest fileSize is invalid.');
    }

    final releaseNotesValue = json['releaseNotes'];
    final publishedAtValue = json['publishedAt'];

    DateTime? publishedAt;

    if (publishedAtValue != null) {
      if (publishedAtValue is! String) {
        throw const FormatException('Update manifest publishedAt is invalid.');
      }

      publishedAt = DateTime.tryParse(publishedAtValue);

      if (publishedAt == null) {
        throw const FormatException('Update manifest publishedAt is invalid.');
      }
    }

    return AndroidUpdateManifest(
      enabled: true,
      platform: 'android',
      latestVersionName: latestVersionName.trim(),
      latestVersionCode: latestVersionCode,
      minimumSupportedVersionCode: minimumSupportedVersionCode,
      mandatory: mandatory,
      apkUrl: apkUrl.trim(),
      sha256: sha256.toLowerCase(),
      fileSize: fileSize,
      releaseNotes: releaseNotesValue is String ? releaseNotesValue.trim() : '',
      publishedAt: publishedAt,
    );
  }

  final bool enabled;
  final String platform;

  final String? latestVersionName;
  final int? latestVersionCode;
  final int? minimumSupportedVersionCode;
  final bool? mandatory;

  final String? apkUrl;
  final String? sha256;
  final int? fileSize;

  final String? releaseNotes;
  final DateTime? publishedAt;
}
