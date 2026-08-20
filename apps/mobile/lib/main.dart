import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/manager_app_auth_gate.dart';
import 'core/database/database_service.dart';
import 'core/notifications/fcm_dev_probe_service.dart';
import 'core/notifications/manager_push_device_registration_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'features/cash_payments/presentation/pages/cash_payment_form_page.dart';
import 'features/cheques/presentation/pages/cheque_form_page.dart';
import 'features/orders/data/manager_orders_repository.dart';
import 'features/orders/presentation/pages/order_details_page.dart';
import 'shared/quick_actions/quick_actions_edge_panel.dart';
import 'core/update/app_update_service.dart';
import 'features/settings/presentation/pages/software_update_settings_page.dart';
import 'features/settings/presentation/providers/communication_settings_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await DatabaseService.instance.initialize();

  runApp(const ProviderScope(child: _AppBootstrap()));
}

class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _startupUpdateCheckStarted = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() => ref.read(syncServiceProvider).start());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupUpdateCheck();
      FcmDevProbeService.initialize(
        onOrderOpened: _openOrderFromPush,
        onChequeOpened: _openChequeFromPush,
        onCashPaymentOpened: _openCashPaymentFromPush,
        onTokenAvailable: _registerPushToken,
      );
    });
  }

  Future<void> _registerPushToken(String token) async {
    try {
      await ManagerPushDeviceRegistrationService(
        apiClient: ref.read(apiClientProvider),
      ).registerToken(token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_PUSH_DEVICE_REGISTER_FAILED=${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _openOrderFromPush(String orderId) async {
    if (!mounted) {
      return;
    }

    NavigatorState? navigator;

    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) {
        return;
      }

      navigator = AppRouter.rootNavigatorKey.currentState;

      if (navigator != null) {
        break;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted || navigator == null) {
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'push-order-details/$orderId'),
        builder: (_) => OrderDetailsPage(
          orderId: orderId,
          repository: ManagerOrdersRepository(ref.read(apiClientProvider)),
        ),
      ),
    );
  }

  Future<NavigatorState?> _waitForRootNavigator() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) {
        return null;
      }

      final navigator = AppRouter.rootNavigatorKey.currentState;

      if (navigator != null) {
        return navigator;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    return null;
  }

  Future<int?> _waitForLocalEntityId({
    required String table,
    required String serverUuid,
  }) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      return null;
    }

    await ref.read(syncServiceProvider).start();

    for (var attempt = 0; attempt < 40; attempt++) {
      if (!mounted) {
        return null;
      }

      final rows = DatabaseService.instance.database.select(
        'SELECT id FROM $table WHERE server_uuid = ? '
        'AND deleted_at IS NULL LIMIT 1',
        <Object?>[normalized],
      );

      if (rows.isNotEmpty) {
        final value = rows.first['id'];

        if (value is int) {
          return value;
        }

        if (value is num) {
          return value.toInt();
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return null;
  }

  Future<void> _openChequeFromPush(String chequeId) async {
    final navigator = await _waitForRootNavigator();

    if (!mounted || navigator == null) {
      return;
    }

    final localId = await _waitForLocalEntityId(
      table: 'cheques',
      serverUuid: chequeId,
    );

    if (!mounted) {
      return;
    }

    if (localId == null) {
      final context = AppRouter.rootNavigatorKey.currentContext;

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'چک هنوز روی این دستگاه همگام نشده است. چند لحظه دیگر دوباره اعلان را باز کنید.',
            ),
          ),
        );
      }

      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'push-cheque-details/$chequeId'),
        builder: (_) =>
            ChequeFormPage(chequeId: localId, pageTitle: 'جزئیات چک'),
      ),
    );
  }

  Future<void> _openCashPaymentFromPush(String cashPaymentId) async {
    final navigator = await _waitForRootNavigator();

    if (!mounted || navigator == null) {
      return;
    }

    final localId = await _waitForLocalEntityId(
      table: 'cash_payments',
      serverUuid: cashPaymentId,
    );

    if (!mounted) {
      return;
    }

    if (localId == null) {
      final context = AppRouter.rootNavigatorKey.currentContext;

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'واریزی هنوز روی این دستگاه همگام نشده است. چند لحظه دیگر دوباره اعلان را باز کنید.',
            ),
          ),
        );
      }

      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: 'push-cash-payment-details/$cashPaymentId',
        ),
        builder: (_) => CashPaymentFormPage(paymentId: localId),
      ),
    );
  }

  Future<void> _runStartupUpdateCheck() async {
    if (_startupUpdateCheckStarted) {
      return;
    }

    _startupUpdateCheckStarted = true;

    try {
      final service = AppUpdateService(apiClient: ref.read(apiClientProvider));

      final result = await service.check();

      if (!mounted || !result.decision.updateAvailable) {
        return;
      }

      final navigatorContext = AppRouter.rootNavigatorKey.currentContext;

      if (navigatorContext == null || !navigatorContext.mounted) {
        return;
      }

      await _showStartupUpdateDialog(navigatorContext, result);
    } catch (_) {
      // Startup update failure must never block the app.
      // Manual update checking remains available in Settings.
    }
  }

  Future<void> _showStartupUpdateDialog(
    BuildContext rootContext,
    AppUpdateCheckResult result,
  ) async {
    final mandatory = result.decision.mandatory;

    final versionName = result.manifest.latestVersionName ?? '-';

    final releaseNotes = result.manifest.releaseNotes?.trim() ?? '';

    await showDialog<void>(
      context: rootContext,
      barrierDismissible: !mandatory,
      useRootNavigator: true,
      builder: (dialogContext) {
        return PopScope<void>(
          canPop: !mandatory,
          child: AlertDialog(
            title: Text(mandatory ? 'بروزرسانی الزامی' : 'بروزرسانی جدید'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mandatory
                      ? 'نسخه $versionName برای ادامه استفاده از PharmaFlow باید نصب شود.'
                      : 'نسخه جدید $versionName برای PharmaFlow آماده است.',
                  textAlign: TextAlign.right,
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'تغییرات نسخه:',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(releaseNotes, textAlign: TextAlign.right),
                ],
              ],
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  },
                  child: const Text('بعداً'),
                ),
              FilledButton(
                onPressed: () {
                  _openSoftwareUpdatePage(
                    dialogContext: dialogContext,
                    mandatory: mandatory,
                  );
                },
                child: const Text('بروزرسانی'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSoftwareUpdatePage({
    required BuildContext dialogContext,
    required bool mandatory,
  }) {
    final rootNavigator = Navigator.of(dialogContext, rootNavigator: true);

    if (mandatory) {
      rootNavigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SoftwareUpdateSettingsPage(),
        ),
      );

      return;
    }

    rootNavigator.pop();

    final rootContext = AppRouter.rootNavigatorKey.currentContext;

    if (rootContext == null || !rootContext.mounted) {
      return;
    }

    Navigator.of(rootContext, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SoftwareUpdateSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PharmaFlowApp();
  }
}

class PharmaFlowApp extends StatelessWidget {
  const PharmaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PharmaFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return ManagerAppAuthGate(
          childBuilder: (authContext, user) {
            void showDenied(String message) {
              ScaffoldMessenger.maybeOf(
                authContext,
              )?.showSnackBar(SnackBar(content: Text(message)));
            }

            return QuickActionsEdgePanel(
              child: child ?? const SizedBox.shrink(),
              onAddCheque: ({required bool replaceCurrent}) async {
                if (!user.permissions.canCreateCheques) {
                  showDenied('برای ثبت چک دسترسی ندارید.');
                  return;
                }

                final navigator = AppRouter.rootNavigatorKey.currentState;

                if (navigator == null) {
                  return;
                }

                final route = MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'quick-action-cheque'),
                  builder: (_) => const ChequeFormPage(),
                );

                if (replaceCurrent) {
                  await navigator.pushReplacement<void, void>(route);
                } else {
                  await navigator.push<void>(route);
                }
              },
              onAddCashPayment: ({required bool replaceCurrent}) async {
                if (!user.permissions.canCreateCashPayments) {
                  showDenied('برای ثبت واریزی دسترسی ندارید.');
                  return;
                }

                final navigator = AppRouter.rootNavigatorKey.currentState;

                if (navigator == null) {
                  return;
                }

                final route = MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: 'quick-action-cash-payment',
                  ),
                  builder: (_) => const CashPaymentFormPage(),
                );

                if (replaceCurrent) {
                  await navigator.pushReplacement<void, void>(route);
                } else {
                  await navigator.push<void>(route);
                }
              },
            );
          },
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fa'), Locale('en')],
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: AppTextStyles.fontFamily,
        scaffoldBackgroundColor: AppColors.scaffold,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        dividerColor: AppColors.divider,
      ),
    );
  }
}
