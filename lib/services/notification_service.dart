import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  final List<RemoteMessage> _notificationHistory = [];

  // Callbacks
  Function(RemoteMessage)? onMessageReceived;
  Function(RemoteMessage)? onMessageOpenedApp;
  Function(RemoteMessage)? onBackgroundMessage;

  /// Initialize notification service
  Future<void> initialize() async {
    // Initialize local notifications
    _initializeLocalNotifications();

    // Request permissions
    await _requestPermissions();

    // Get FCM token
    await _getFCMToken();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message (when app is opened from notification)
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  void _initializeLocalNotifications() {
    _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) {},
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _onLocalNotificationTapped(response.payload);
      },
    );
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permissions: ${settings.authorizationStatus}');
  }

  Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token Refreshed: $newToken');
        // Save new token to backend
        _saveFCMTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground Message Received: ${message.notification?.title}');

    _notificationHistory.add(message);

    // Show local notification
    _showLocalNotification(message);

    // Call callback
    onMessageReceived?.call(message);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background Message Received: ${message.notification?.title}');
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('Message opened from notification: ${message.notification?.title}');

    _notificationHistory.add(message);

    // Handle deep linking based on message data
    _handleNotificationNavigation(message);

    // Call callback
    onMessageOpenedApp?.call(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'roomix_channel',
      'Roomix Notifications',
      channelDescription: 'Notifications from Roomix app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotificationTapped(String? payload) {
    if (payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        _handleDeepLink(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    _handleDeepLink(message.data);
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? id = data['id'];

    // Route to appropriate screen based on notification type
    switch (type) {
      case 'room':
        // Navigate to room detail
        break;
      case 'message':
        // Navigate to chat
        break;
      case 'roommate':
        // Navigate to roommate profile
        break;
      case 'event':
        // Navigate to event detail
        break;
      default:
        // Navigate to home
        break;
    }
  }

  Future<void> _saveFCMTokenToBackend(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': Timestamp.now(),
        });
        debugPrint('FCM token saved to backend: $token');
      } catch (e) {
        debugPrint('Error saving FCM token to backend: $e');
      }
    } else {
      debugPrint('User not logged in, cannot save FCM token');
    }
  }

  /// Get notification history
  List<RemoteMessage> getNotificationHistory() {
    return _notificationHistory;
  }

  /// Clear notification history
  void clearNotificationHistory() {
    _notificationHistory.clear();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
}
