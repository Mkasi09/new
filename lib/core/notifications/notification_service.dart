import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:huawei_push/huawei_push.dart' as hms;

class NotificationRegistrationStatus {
  const NotificationRegistrationStatus({
    required this.permission,
    required this.tokenSaved,
    this.token,
    this.error,
  });

  final NotificationSettings permission;
  final bool tokenSaved;
  final String? token;
  final Object? error;

  bool get enabled =>
      tokenSaved &&
      (permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional);
}

class TestNotificationResult {
  const TestNotificationResult({
    required this.successCount,
    required this.failureCount,
  });

  final int successCount;
  final int failureCount;

  bool get sent => successCount > 0;
}

class NotificationService {
  const NotificationService._();

  static const MethodChannel _deviceServices = MethodChannel(
    'za.co.phephamv.isdp/device_services',
  );
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final Set<String> _registeredUsers = {};
  static bool _localNotificationsReady = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<hms.RemoteMessage>? _huaweiForegroundSubscription;
  static StreamSubscription<String>? _huaweiTokenSubscription;
  static String? _huaweiTokenUserId;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'isdp_work_updates',
        'ISDP Work Updates',
        description: 'Job assignments, submissions, approvals, and issues.',
        importance: Importance.high,
      );

  static Future<NotificationRegistrationStatus> registerCurrentDevice(
    String userId, {
    bool force = false,
  }) async {
    if (await _canUseFirebaseMessaging()) {
      return _registerFirebaseDevice(userId, force: force);
    }
    if (await _canUseHuaweiPush()) {
      return _registerHuaweiDevice(userId, force: force);
    }
    return NotificationRegistrationStatus(
      permission: _notificationSettingsUnavailable,
      tokenSaved: false,
      error: const PushMessagingUnavailableException(),
    );
  }

  static Future<NotificationRegistrationStatus> _registerFirebaseDevice(
    String userId, {
    required bool force,
  }) async {
    final registrationKey = 'fcm:$userId';
    if (!force && !_registeredUsers.add(registrationKey)) {
      final permission = await _messaging.getNotificationSettings();
      return NotificationRegistrationStatus(
        permission: permission,
        tokenSaved: true,
      );
    }
    _registeredUsers.add(registrationKey);
    try {
      await _initializeLocalNotifications();
      final permission = await _messaging.requestPermission();
      await _requestPlatformNotificationPermission();
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _registeredUsers.remove(registrationKey);
        return NotificationRegistrationStatus(
          permission: permission,
          tokenSaved: false,
        );
      }
      await _saveFirebaseToken(userId, token);
      _messaging.onTokenRefresh.listen((token) {
        unawaited(_saveFirebaseToken(userId, token));
      });
      return NotificationRegistrationStatus(
        permission: permission,
        tokenSaved: true,
        token: token,
      );
    } catch (error) {
      _registeredUsers.remove(registrationKey);
      // Notifications are helpful, but app access must not fail if FCM is unavailable.
      return NotificationRegistrationStatus(
        permission: await _safeNotificationSettings(),
        tokenSaved: false,
        error: error,
      );
    }
  }

  static Future<NotificationRegistrationStatus> _registerHuaweiDevice(
    String userId, {
    required bool force,
  }) async {
    final registrationKey = 'hms:$userId';
    if (!force && !_registeredUsers.add(registrationKey)) {
      return const NotificationRegistrationStatus(
        permission: _huaweiNotificationSettings,
        tokenSaved: true,
      );
    }
    _registeredUsers.add(registrationKey);
    try {
      await _initializeLocalNotifications();
      await _requestPlatformNotificationPermission();
      await _initializeHuaweiPush(userId);
      final token = await _requestHuaweiToken();
      await _saveHuaweiToken(userId, token);
      return NotificationRegistrationStatus(
        permission: _huaweiNotificationSettings,
        tokenSaved: true,
        token: token,
      );
    } catch (error) {
      _registeredUsers.remove(registrationKey);
      return NotificationRegistrationStatus(
        permission: _huaweiNotificationSettings,
        tokenSaved: false,
        error: error,
      );
    }
  }

  static Future<void> _saveFirebaseToken(String userId, String token) {
    return _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastNotificationToken': token,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _saveHuaweiToken(String userId, String token) {
    return _firestore.collection('users').doc(userId).set({
      'hmsTokens': FieldValue.arrayUnion([token]),
      'lastHuaweiNotificationToken': token,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<TestNotificationResult> sendTestNotification() async {
    final response = await _functions
        .httpsCallable('sendTestNotification')
        .call();
    final data = response.data;
    if (data is Map) {
      return TestNotificationResult(
        successCount: (data['successCount'] as num?)?.toInt() ?? 0,
        failureCount: (data['failureCount'] as num?)?.toInt() ?? 0,
      );
    }
    return const TestNotificationResult(successCount: 0, failureCount: 0);
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(settings: initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _localNotificationsReady = true;
  }

  static Future<void> _requestPlatformNotificationPermission() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'isdp_work_updates',
          'ISDP Work Updates',
          channelDescription:
              'Job assignments, submissions, approvals, and issues.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['workOrderId'] as String?,
    );
  }

  static Future<void> _initializeHuaweiPush(String userId) async {
    await hms.Push.setAutoInitEnabled(true);
    await hms.Push.turnOnPush();

    if (_huaweiTokenUserId != userId) {
      await _huaweiTokenSubscription?.cancel();
      _huaweiTokenUserId = userId;
      _huaweiTokenSubscription = hms.Push.getTokenStream.listen((token) {
        if (token.isNotEmpty) {
          unawaited(_saveHuaweiToken(userId, token));
        }
      });
    }

    _huaweiForegroundSubscription ??= hms.Push.onMessageReceivedStream.listen(
      _showHuaweiForegroundNotification,
    );
  }

  static Future<String> _requestHuaweiToken() async {
    final tokenFuture = hms.Push.getTokenStream
        .firstWhere((token) => token.isNotEmpty)
        .timeout(const Duration(seconds: 20));
    hms.Push.getToken(hms.RemoteMessage.INSTANCE_ID_SCOPE);
    return tokenFuture;
  }

  static Future<void> _showHuaweiForegroundNotification(
    hms.RemoteMessage message,
  ) async {
    final data = message.dataOfMap ?? <String, String>{};
    final notification = message.notification;
    final title = notification?.title ?? data['title'];
    final body = notification?.body ?? data['body'] ?? message.data;
    if (title == null && body == null) return;

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'isdp_work_updates',
          'ISDP Work Updates',
          channelDescription:
              'Job assignments, submissions, approvals, and issues.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: data['workOrderId'],
    );
  }

  static Future<bool> _canUseFirebaseMessaging() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      return await _deviceServices.invokeMethod<bool>(
            'isGooglePlayServicesAvailable',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _canUseHuaweiPush() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _deviceServices.invokeMethod<bool>(
            'isHuaweiMobileServicesAvailable',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<NotificationSettings> _safeNotificationSettings() async {
    try {
      return await _messaging.getNotificationSettings();
    } catch (_) {
      return _notificationSettingsUnavailable;
    }
  }
}

class PushMessagingUnavailableException implements Exception {
  const PushMessagingUnavailableException();

  @override
  String toString() =>
      'Push messaging is unavailable because Google Play services and Huawei '
      'Mobile Services are missing or disabled on this device.';
}

const NotificationSettings _huaweiNotificationSettings = NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  authorizationStatus: AuthorizationStatus.authorized,
  badge: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.notSupported,
  notificationCenter: AppleNotificationSetting.notSupported,
  showPreviews: AppleShowPreviewSetting.notSupported,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

const NotificationSettings _notificationSettingsUnavailable =
    NotificationSettings(
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: AuthorizationStatus.denied,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );
