import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/update/app_update_decision.dart';
import '../../../../core/update/app_update_downloader.dart';
import '../../../../core/update/app_update_installer.dart';
import '../../../../core/update/app_update_service.dart';
import '../providers/communication_settings_provider.dart';
import '../widgets/settings_section_card.dart';

class SoftwareUpdateSettingsPage extends ConsumerStatefulWidget {
  const SoftwareUpdateSettingsPage({super.key});

  @override
  ConsumerState<SoftwareUpdateSettingsPage> createState() =>
      _SoftwareUpdateSettingsPageState();
}

class _SoftwareUpdateSettingsPageState
    extends ConsumerState<SoftwareUpdateSettingsPage> {
  bool _checking = false;
  bool _downloading = false;
  bool _installing = false;

  double? _downloadProgress;

  AppUpdateCheckResult? _result;
  VerifiedUpdateDownload? _verifiedDownload;

  String? _error;

  Future<void> _check() async {
    if (_checking) {
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final service = AppUpdateService(apiClient: ref.read(apiClientProvider));

      final result = await service.check();

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'بررسی بروزرسانی با خطا مواجه شد.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final result = _result;

    if (_downloading || result == null || !result.decision.updateAvailable) {
      return;
    }

    final manifest = result.manifest;

    final url = manifest.apkUrl;
    final versionCode = manifest.latestVersionCode;
    final fileSize = manifest.fileSize;
    final expectedSha256 = manifest.sha256;

    if (url == null ||
        versionCode == null ||
        fileSize == null ||
        expectedSha256 == null) {
      setState(() {
        _error = 'اطلاعات فایل بروزرسانی ناقص است.';
      });
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _verifiedDownload = null;
      _error = null;
    });

    try {
      final downloader = AppUpdateDownloader();

      final verified = await downloader.downloadAndVerify(
        url: url,
        versionCode: versionCode,
        expectedSizeBytes: fileSize,
        expectedSha256: expectedSha256,
        onProgress: (received, total) {
          if (!mounted || total <= 0) {
            return;
          }

          setState(() {
            _downloadProgress = (received / total).clamp(0.0, 1.0);
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verifiedDownload = verified;
        _downloadProgress = 1;
      });
    } on AppUpdateDownloadException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'دانلود بروزرسانی با خطا مواجه شد.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<void> _installUpdate() async {
    final verifiedDownload = _verifiedDownload;

    if (_installing || verifiedDownload == null) {
      return;
    }

    setState(() {
      _installing = true;
      _error = null;
    });

    try {
      const installer = AppUpdateInstaller();

      final allowed = await installer.canRequestPackageInstalls();

      if (!mounted) {
        return;
      }

      if (!allowed) {
        await installer.openInstallPermissionSettings();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برای نصب بروزرسانی، اجازه نصب برنامه از این منبع را برای PharmaFlow فعال کنید و سپس دوباره «نصب بروزرسانی» را بزنید.',
            ),
          ),
        );

        return;
      }

      await installer.installVerifiedApk(verifiedDownload.file.path);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست نصب بروزرسانی به اندروید ارسال شد.'),
        ),
      );
    } on AppUpdateInstallException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'آماده‌سازی نصب بروزرسانی با خطا مواجه شد.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  String _statusText(AppUpdateCheckResult result) {
    switch (result.decision.status) {
      case AppUpdateStatus.publishingDisabled:
        return 'در حال حاضر بروزرسانی جدیدی منتشر نشده است.';

      case AppUpdateStatus.upToDate:
        return 'نسخه فعلی آخرین نسخه منتشرشده است.';

      case AppUpdateStatus.updateAvailable:
        final version = result.manifest.latestVersionName ?? '-';

        return result.decision.mandatory
            ? 'نسخه $version آماده است و این بروزرسانی الزامی است.'
            : 'نسخه جدید $version آماده است.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بروزرسانی نرم‌افزار')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsSectionCard(
              title: 'نسخه نرم‌افزار',
              children: [
                if (result != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('نسخه نصب‌شده'),
                    subtitle: Text(
                      '${result.currentVersion.versionName} '
                      '(${result.currentVersion.versionCode})',
                    ),
                  ),
                  const Divider(),
                  Text(_statusText(result), textAlign: TextAlign.right),
                  if (result.decision.updateAvailable &&
                      (result.manifest.releaseNotes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'تغییرات نسخه:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.manifest.releaseNotes!,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ] else
                  const Text(
                    'برای بررسی نسخه جدید، دکمه زیر را بزنید.',
                    textAlign: TextAlign.right,
                  ),
                if (result != null && result.decision.updateAvailable) ...[
                  const SizedBox(height: 16),
                  if (_downloading) ...[
                    LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 8),
                    Text(
                      _downloadProgress == null
                          ? 'در حال دانلود...'
                          : 'در حال دانلود... '
                                '${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}٪',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_verifiedDownload != null) ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined),
                        SizedBox(width: 8),
                        Text('فایل بروزرسانی با موفقیت بررسی و تأیید شد.'),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_verifiedDownload != null) ...[
                    FilledButton.icon(
                      onPressed: _installing ? null : _installUpdate,
                      icon: _installing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.install_mobile_outlined),
                      label: Text(
                        _installing
                            ? 'در حال آماده‌سازی نصب...'
                            : 'نصب بروزرسانی',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: (_downloading || _installing)
                        ? null
                        : _downloadUpdate,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      _verifiedDownload == null
                          ? 'دانلود و بررسی فایل بروزرسانی'
                          : 'دانلود مجدد فایل بروزرسانی',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  label: Text(
                    _checking ? 'در حال بررسی...' : 'بررسی بروزرسانی',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
