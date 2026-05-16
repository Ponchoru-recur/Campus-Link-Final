import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_screen.dart';

/// Singleton service managing FCM push notification lifecycle.
///
/// Responsibilities:
/// 1. FCM token registration and refresh, stored in Firestore users/{uid}/fcmTokens
/// 2. Foreground message handling via flutter_local_notifications
/// 3. Background message handling (top-level handler registered in main.dart)
/// 4. Notification tap navigation to correct chat screen
/// 5. Android notification channel creation (high_importance_channel, silent_channel)
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const String _workerUrl = 'https://dawn-rice-bc73.sam-varela.workers.dev';

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Global navigator key for notification-tap navigation without BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Initialize FCM lifecycle: channels, permissions, token, listeners.
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Create Android notification channels
    const highChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Important Notifications',
      description: 'For @mentions, DMs, and task notifications',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highChannel);

    const silentChannel = AndroidNotificationChannel(
      'silent_channel',
      'Silent Notifications',
      description: 'For badge-only updates',
      importance: Importance.min,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(silentChannel);

    // 2. Initialize flutter_local_notifications with Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: initSettings);

    // 3. Request notification permissions (iOS only, no-op on Android)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Get initial FCM token and store it
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM token obtained: ${token.substring(0, 40)}...');
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('FCM token init skipped (emulator/unsupported device): $e');
    }

    // 5. Listen for token refresh
    try {
      _firebaseMessaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('FCM token refresh listener skipped: $e');
    }

    // 6. Handle foreground messages (show local notification)
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('FCM onMessage listener skipped: $e');
    }

    // 7. Handle notification tap (app opened from background via notification)
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } catch (e) {
      debugPrint('FCM onMessageOpenedApp listener skipped: $e');
    }

    // 8. Check if app was opened from a terminated notification (cold start)
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('FCM getInitialMessage skipped: $e');
    }
  }

  /// Store the FCM token in Firestore under users/{uid}/fcmTokens.
  ///
  /// Uses FieldValue.arrayUnion so multiple device tokens can accumulate.
  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle a foreground FCM message by showing a local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Campus Link';
    final body = message.notification?.body ?? 'New message';

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Important Notifications',
        channelDescription: 'For @mentions, DMs, and task notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    _localNotifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: message.data['chatId'] as String?,
    );
  }

  /// Handle notification tap by navigating to the relevant chat screen.
  ///
  /// Parses chatId and chatType from the FCM data payload, clears the
  /// navigation stack to ChatsScreen, then pushes GroupChatScreen.
  void _handleNotificationTap(RemoteMessage message) {
    final chatId = message.data['chatId'] as String?;
    if (chatId == null || chatId.isEmpty) return;

    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) return;

    navigatorState.pushNamedAndRemoveUntil('/chatScreen', (route) => false);

    // Push the GroupChatScreen with the correct ChatItem
    navigatorState.push(
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          chat: ChatItem(
            id: chatId,
            name: message.data['chatName'] as String? ?? 'Chat',
            lastMessage: '',
            time: '',
            type: ChatType.groupChat,
          ),
        ),
      ),
    );
  }

  /// Send raw message data to Cloudflare Worker for tiered FCM dispatch.
  ///
  /// Fire-and-forget: never awaits, never throws up to caller. Worker handles
  /// all server-side logic: querying member strategies + FCM tokens via
  /// Firestore REST API, applying tier logic (D-16), fanning out FCM calls.
  ///
  /// Per D-20: Flutter sends ONE POST with raw data, NOT pre-built targets.
  Future<void> sendTieredNotification({
    required String chatId,
    required String messageId,
    required String senderId,
    required String senderName,
    required String chatName,
    required String text,
    required List<String> mentionedUids,
    required bool isEveryone,
    required bool isTask,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'messageId': messageId,
          'senderId': senderId,
          'senderName': senderName,
          'chatName': chatName,
          'text': text,
          'mentionedUids': mentionedUids,
          'isEveryone': isEveryone,
          'isTask': isTask,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Notification Worker returned ${response.statusCode}: ${response.body}');
      } else {
        debugPrint('Notification Worker success: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to send notification to Worker: $e');
    }
  }
}