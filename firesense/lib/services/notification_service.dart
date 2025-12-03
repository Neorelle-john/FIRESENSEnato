import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service that handles local notifications and Firebase Cloud Messaging
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _isInitialized = false;
  bool _notificationsEnabled = true;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fire_alarm_channel',
      'Fire Alarms',
      description: 'Notifications for fire alarm alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request notification permissions
    await requestPermissions();

    // Request FCM token
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Load user's notification preference from Firestore
    await _loadNotificationPreference();

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Load notification preference from Firestore
  Future<void> _loadNotificationPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notificationsEnabled = true; // Default to enabled
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists && doc.data() != null) {
        _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
      } else {
        // Default to enabled if not set
        _notificationsEnabled = true;
        await _saveNotificationPreference(true);
      }
    } catch (e) {
      print('Error loading notification preference: $e');
      _notificationsEnabled = true; // Default to enabled on error
    }
  }

  /// Save notification preference to Firestore
  Future<void> _saveNotificationPreference(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'notificationsEnabled': enabled,
      }, SetOptions(merge: true));
      _notificationsEnabled = enabled;
    } catch (e) {
      print('Error saving notification preference: $e');
    }
  }

  /// Get current notification preference
  bool get areNotificationsEnabled => _notificationsEnabled;

  /// Enable or disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;

    await _saveNotificationPreference(enabled);

    if (!enabled) {
      // Cancel all pending notifications
      await _localNotifications.cancelAll();
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? deviceId,
    bool? isAdmin, // Optional parameter to explicitly indicate admin
  }) async {
    if (!_notificationsEnabled) {
      print('Notifications are disabled, skipping notification');
      return;
    }

    // Check if permission is granted
    final permissionStatus = await Permission.notification.status;
    if (!permissionStatus.isGranted) {
      print('Notification permission not granted');
      return;
    }

    // Determine if user is admin (check if not explicitly provided)
    bool userIsAdmin = isAdmin ?? false;
    if (!userIsAdmin) {
      final user = FirebaseAuth.instance.currentUser;
      userIsAdmin = user?.email == 'admin@gmail.com';
    }

    // Customize notification based on user type
    String finalTitle = title;
    String finalBody = body;

    if (userIsAdmin) {
      // Admin-specific notification
      finalTitle = 'Alert Detected';
      // Extract device name from body if available, otherwise use generic message
      if (body.contains('Fire detected by')) {
        final deviceNameMatch = RegExp(
          r'Fire detected by (.+?)\.',
        ).firstMatch(body);
        final deviceName = deviceNameMatch?.group(1) ?? 'device';
        finalBody = 'Alert from $deviceName. Tap to view details.';
      } else if (body.contains('detected by')) {
        final deviceNameMatch = RegExp(r'detected by (.+?)\.').firstMatch(body);
        final deviceName = deviceNameMatch?.group(1) ?? 'device';
        finalBody = 'Alert from $deviceName. Tap to view details.';
      } else {
        finalBody = 'New alert requires your attention. Tap to view details.';
      }
    }
    // For regular users, use the provided title and body as-is

    // Use BigTextStyleInformation for Android to show full message in expandable notifications
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'fire_alarm_channel',
          'Fire Alarms',
          channelDescription: 'Notifications for fire alarm alerts',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            finalBody,
            contentTitle: finalTitle,
            htmlFormatBigText: false,
          ),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        deviceId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        finalTitle,
        finalBody,
        details,
        payload: deviceId,
      );
    } catch (e) {
      print('Error showing notification: $e');
      // Don't rethrow - notifications are non-critical
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (!_notificationsEnabled) return;

    showNotification(
      title: message.notification?.title ?? 'Fire Alarm',
      body: message.notification?.body ?? 'A fire alarm has been triggered',
      deviceId: message.data['deviceId'],
    );
  }

  /// Handle background messages (when app is opened from notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    // Handle navigation or other actions when app is opened from notification
    print('App opened from notification: ${message.messageId}');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  /// Refresh notification preference from Firestore
  Future<void> refreshPreference() async {
    await _loadNotificationPreference();
  }
}
