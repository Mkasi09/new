import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

class NotificationService {
  const NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final Set<String> _registeredUsers = {};
  static bool _localNotificationsReady = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

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
    if (!force && !_registeredUsers.add(userId)) {
      final permission = await _messaging.getNotificationSettings();
      return NotificationRegistrationStatus(
        permission: permission,
        tokenSaved: true,
      );
    }
    _registeredUsers.add(userId);
    try {
      await _initializeLocalNotifications();
      final permission = await _messaging.requestPermission();
      await _requestPlatformNotificationPermission();
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _registeredUsers.remove(userId);
        return NotificationRegistrationStatus(
          permission: permission,
          tokenSaved: false,
        );
      }
      await _saveToken(userId, token);
      _messaging.onTokenRefresh.listen((token) {
        unawaited(_saveToken(userId, token));
      });
      return NotificationRegistrationStatus(
        permission: permission,
        tokenSaved: true,
        token: token,
      );
    } catch (error) {
      _registeredUsers.remove(userId);
      // Notifications are helpful, but app access must not fail if FCM is unavailable.
      final permission = await _messaging.getNotificationSettings();
      return NotificationRegistrationStatus(
        permission: permission,
        tokenSaved: false,
        error: error,
      );
    }
  }

  static Future<void> _saveToken(String userId, String token) {
    return _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastNotificationToken': token,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendTestNotification() async {
    await _functions.httpsCallable('sendTestNotification').call();
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
}
