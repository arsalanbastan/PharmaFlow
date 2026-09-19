import 'android_update_manifest.dart';

enum AppUpdateStatus { publishingDisabled, upToDate, updateAvailable }

class AppUpdateDecision {
  const AppUpdateDecision({required this.status, required this.mandatory});

  final AppUpdateStatus status;
  final bool mandatory;

  bool get updateAvailable => status == AppUpdateStatus.updateAvailable;
}

AppUpdateDecision evaluateAppUpdate({
  required AndroidUpdateManifest manifest,
  required int currentVersionCode,
}) {
  if (!manifest.enabled) {
    return const AppUpdateDecision(
      status: AppUpdateStatus.publishingDisabled,
      mandatory: false,
    );
  }

  final latestVersionCode = manifest.latestVersionCode!;
  final minimumSupportedVersionCode = manifest.minimumSupportedVersionCode!;

  if (latestVersionCode <= currentVersionCode) {
    return const AppUpdateDecision(
      status: AppUpdateStatus.upToDate,
      mandatory: false,
    );
  }

  final mandatory =
      manifest.mandatory == true ||
      currentVersionCode < minimumSupportedVersionCode;

  return AppUpdateDecision(
    status: AppUpdateStatus.updateAvailable,
    mandatory: mandatory,
  );
}
