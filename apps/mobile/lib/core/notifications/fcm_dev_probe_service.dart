import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fcm_order_target.dart';

class FcmDevProbeService {
  static const MethodChannel _foregroundNotificationChannel = MethodChannel(
    'pharmaflow/foreground_notification',
  );
  FcmDevProbeService._();

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static Future<void> Function(String orderId)? _onOrderOpened;
  static Future<void> Function(String chequeId)? _onChequeOpened;
  static Future<void> Function(String cashPaymentId)? _onCashPaymentOpened;
  static Future<void> Function(String token)? _onTokenAvailable;
  static Future<void> Function(String deliveryId)? _onNotificationAcknowledged;
  static String? _lastOpenedMessageKey;

  static Future<void> initialize({
    required Future<void> Function(String orderId) onOrderOpened,
    Future<void> Function(String chequeId)? onChequeOpened,
    Future<void> Function(String cashPaymentId)? onCashPaymentOpened,
    Future<void> Function(String token)? onTokenAvailable,
    Future<void> Function(String deliveryId)? onNotificationAcknowledged,
  }) async {
    _onOrderOpened = onOrderOpened;
    _onChequeOpened = onChequeOpened;
    _onCashPaymentOpened = onCashPaymentOpened;
    _onTokenAvailable = onTokenAvailable;
    _onNotificationAcknowledged = onNotificationAcknowledged;

    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      await _configureForegroundNotificationChannel();

      final messaging = FirebaseMessaging.instance;

      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_FCM_PERMISSION=${permission.authorizationStatus.name}',
        );
      }

      final token = await messaging.getToken();

      if (token != null && token.trim().isNotEmpty) {
        if (kDebugMode) {
          debugPrint('PHARMAFLOW_FCM_TOKEN_AVAILABLE=1');
        }

        unawaited(_notifyTokenAvailable(token));
      }

      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) {
        if (token.trim().isEmpty) {
          return;
        }

        if (kDebugMode) {
          debugPrint('PHARMAFLOW_FCM_TOKEN_REFRESH_AVAILABLE=1');
        }

        unawaited(_notifyTokenAvailable(token));
      });

      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) {
        unawaited(_handleForegroundMessage(message));
      });

      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        unawaited(_handleOpenedMessage(message));
      });

      final initialMessage = await messaging.getInitialMessage();

      if (initialMessage != null) {
        await _handleOpenedMessage(initialMessage);
      }
    } catch (error) {
      _initialized = false;

      if (kDebugMode) {
        debugPrint('PHARMAFLOW_FCM_INIT_ERROR=$error');
      }
    }
  }

  static Future<void> _configureForegroundNotificationChannel() async {
    _foregroundNotificationChannel.setMethodCallHandler((call) async {
      if (call.method != 'orderNotificationTapped') {
        return null;
      }

      final target = FcmPushTarget.fromNative(call.arguments);

      if (target == null) {
        return null;
      }

      await _handleNativePushOpen(target);
      return null;
    });

    try {
      final pendingTarget = await _foregroundNotificationChannel
          .invokeMethod<Object?>('consumePendingOrderId');

      final target = FcmPushTarget.fromNative(pendingTarget);

      if (target != null) {
        await _handleNativePushOpen(target);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_FOREGROUND_NOTIFICATION_INIT_ERROR=${error.runtimeType}',
        );
      }
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final target = FcmPushTarget.fromData(message.data);

    if (target == null) {
      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_FCM_FOREGROUND_IGNORED=${message.messageId ?? '-'}',
        );
      }

      return;
    }

    final notification = message.notification;
    final rawTitle = notification?.title?.trim();
    final rawBody = notification?.body?.trim();

    final fallback = switch (target.kind) {
      FcmPushTargetKind.order => ('سفارش جدید', 'یک سفارش جدید ثبت شد.'),
      FcmPushTargetKind.cheque => ('چک جدید ثبت شد', 'یک چک جدید ثبت شد.'),
      FcmPushTargetKind.cashPayment => (
        'واریزی جدید ثبت شد',
        'یک واریزی جدید ثبت شد.',
      ),
    };

    final title = rawTitle == null || rawTitle.isEmpty ? fallback.$1 : rawTitle;
    final body = rawBody == null || rawBody.isEmpty ? fallback.$2 : rawBody;

    try {
      final isSilent = notification?.android?.channelId == 'pharmaflow_silent';

      final notificationCount =
          int.tryParse(message.data['notificationCount']?.toString() ?? '') ??
          1;

      await _foregroundNotificationChannel
          .invokeMethod<void>('showOrderNotification', <String, dynamic>{
            'title': title,
            'body': body,
            'orderId': target.id,
            'type': target.type,
            'silent': isSilent,
            'count': notificationCount < 1 ? 1 : notificationCount,
            'deliveryId': target.notificationDeliveryId,
          });

      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_FCM_FOREGROUND_NOTIFICATION_SHOWN='
          '${target.type}|${target.id}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PHARMAFLOW_FCM_FOREGROUND_NOTIFICATION_ERROR=${error.runtimeType}',
        );
      }
    }
  }

  static Future<void> _handleNativePushOpen(FcmPushTarget target) async {
    final messageKey = 'native:${target.type}:${target.id}';

    if (_lastOpenedMessageKey == messageKey) {
      return;
    }

    _lastOpenedMessageKey = messageKey;

    if (kDebugMode) {
      debugPrint(
        'PHARMAFLOW_NATIVE_NOTIFICATION_OPEN=${target.type}|${target.id}',
      );
    }

    await _dispatchTarget(target);
  }

  static Future<void> _notifyTokenAvailable(String token) async {
    final normalized = token.trim();
    final callback = _onTokenAvailable;

    if (normalized.isEmpty || callback == null) {
      return;
    }

    try {
      await callback(normalized);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PHARMAFLOW_FCM_TOKEN_CALLBACK_ERROR=${error.runtimeType}');
      }
    }
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final target = FcmPushTarget.fromData(message.data);

    if (target == null) {
      if (kDebugMode) {
        debugPrint('PHARMAFLOW_FCM_OPEN_IGNORED=${message.messageId ?? '-'}');
      }

      return;
    }

    final messageKey =
        message.messageId ??
        '${target.type}:${target.id}:${message.sentTime?.millisecondsSinceEpoch ?? 0}';

    if (_lastOpenedMessageKey == messageKey) {
      return;
    }

    _lastOpenedMessageKey = messageKey;

    if (kDebugMode) {
      debugPrint('PHARMAFLOW_FCM_OPEN=${target.type}|${target.id}');
    }

    await _dispatchTarget(target);
  }

  static Future<void> _acknowledgeTappedNotification(
    FcmPushTarget target,
  ) async {
    final deliveryId = target.notificationDeliveryId;
    final callback = _onNotificationAcknowledged;

    if (deliveryId == null || callback == null) {
      return;
    }

    try {
      await callback(deliveryId);

      if (kDebugMode) {
        debugPrint('PHARMAFLOW_NOTIFICATION_ACK=$deliveryId');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PHARMAFLOW_NOTIFICATION_ACK_ERROR=${error.runtimeType}');
      }
    }
  }

  static Future<void> _dispatchTarget(FcmPushTarget target) async {
    await _acknowledgeTappedNotification(target);

    switch (target.kind) {
      case FcmPushTargetKind.order:
        final callback = _onOrderOpened;
        if (callback != null) {
          await callback(target.id);
        }
      case FcmPushTargetKind.cheque:
        final callback = _onChequeOpened;
        if (callback != null) {
          await callback(target.id);
        }
      case FcmPushTargetKind.cashPayment:
        final callback = _onCashPaymentOpened;
        if (callback != null) {
          await callback(target.id);
        }
    }
  }
}
