import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/web_notification.dart' as web_noti;
import 'notification_router.dart';

// Conditional import: flutter_local_notifications only on non-web
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background handler — ต้องเป็น top-level function (mobile only)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  if (!kIsWeb) {
    await NotificationService._showLocalNotification(message);
  }
}

/// Notification Service — v3: รองรับ Web + Mobile
/// - Mobile: FCM + flutter_local_notifications + channels
/// - Web: FCM + Browser Notification API + in-app overlay + sound + vibration
class NotificationService {

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// flutter_local_notifications — ใช้เฉพาะ mobile
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Navigator key สำหรับ deep link — set จาก main.dart
  static GlobalKey<NavigatorState>? navigatorKey;

  // =============================================
  // Notification Channels (Android only)
  // =============================================

  static const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_incidents',
    'เหตุด่วน',
    description: 'แจ้งเตือนเมื่อมีเหตุด่วนใหม่หรือเหตุฉุกเฉิน',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages',
    'ข้อความแชท',
    description: 'แจ้งเตือนเมื่อมีข้อความแชทใหม่',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const AndroidNotificationChannel statusChannel = AndroidNotificationChannel(
    'status_updates',
    'อัปเดตสถานะ',
    description: 'แจ้งเตือนเมื่อสถานะเหตุการณ์เปลี่ยนแปลง',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: true,
  );

  // =============================================
  // Initialize — v3: รองรับทั้ง Web + Mobile
  // =============================================

  static Future<void> initialize() async {
    try {
      // 1. ขอ permission (ทำงานทั้ง Web + Mobile)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: !kIsWeb, // criticalAlert ไม่มีบน Web
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[FCM] Permission denied: ${settings.authorizationStatus}');
        // ถ้า denied ก็ยังพยายามขอ Browser Notification permission
        if (kIsWeb) {
          await web_noti.requestBrowserNotificationPermission();
        }
        return;
      }
      debugPrint('[FCM] Permission granted');

      if (kIsWeb) {
        // === Web-specific initialization ===
        await _initializeWeb();
      } else {
        // === Mobile-specific initialization ===
        await _initializeMobile();
      }

      // 2. บันทึก FCM Token
      await _saveToken();

      // 3. Listen token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // 4. Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground: ${message.notification?.title}');
        if (kIsWeb) {
          _showWebNotification(message);
        } else {
          _showLocalNotification(message);
        }
      });

      // 5. Background message handler (mobile only)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      // 6. Handle notification tap from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Opened from background: ${message.data}');
        NotificationRouter.handleNotificationTap(message.data);
      });

    } catch (e) {
      debugPrint('[FCM] initialize error: $e');
      // ถ้า FCM ล้มเหลวบน Web ก็ยังพยายามขอ Browser Notification permission
      if (kIsWeb) {
        try {
          await web_noti.requestBrowserNotificationPermission();
        } catch (_) {}
      }
    }
  }

  /// Web-specific initialization
  static Future<void> _initializeWeb() async {
    // ขอ Browser Notification permission (เพิ่มจาก FCM)
    await web_noti.requestBrowserNotificationPermission();
    debugPrint('[FCM-Web] Browser notification permission requested');
  }

  /// Mobile-specific initialization
  static Future<void> _initializeMobile() async {
    // สร้าง Notification Channels (Android)
    await _createNotificationChannels();
    // Initialize flutter_local_notifications
    await _initLocalNotifications();
  }

  /// Handle initial message — เมื่อเปิดแอพจาก notification
  static Future<void> handleInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        debugPrint('[FCM] Initial message: ${message.data}');
        Future.delayed(const Duration(milliseconds: 500), () {
          NotificationRouter.handleNotificationTap(message.data);
        });
      }
    } catch (e) {
      debugPrint('[FCM] handleInitialMessage error: $e');
    }
  }

  // =============================================
  // Web Notification — In-app overlay + Browser API + Sound + Vibration
  // =============================================

  /// แสดง notification บน Web — ใช้ in-app overlay + Browser Notification API
  static void _showWebNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    if (notification == null && data.isEmpty) return;

    // Skip if the current user is the sender of the notification event
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final senderId = data['senderId'] as String?;
    if (senderId != null && currentUserId != null && senderId == currentUserId) {
      debugPrint('[FCM-Web] Suppressing notification triggered by self');
      return;
    }

    final title = notification?.title ?? data['title'] ?? 'ระบบแจ้งเหตุ';
    final body = notification?.body ?? data['body'] ?? '';
    final type = data['type'] ?? 'status';

    // 1. เล่นเสียง
    web_noti.playWebAlertSound();

    // 2. สั่น device (mobile browser)
    if (type == 'incident_new' || type == 'incident_assigned') {
      web_noti.vibrateDevice([300, 100, 300, 100, 300]);
    } else {
      web_noti.vibrateDevice([200, 100, 200]);
    }

    // 3. แสดง Browser Notification (ทำงานแม้ tab ไม่ active)
    web_noti.showBrowserNotification(title, body);

    // 4. แสดง in-app overlay banner
    _showInAppBanner(title, body, type, data);
  }

  /// แสดง in-app notification banner (overlay) สำหรับ Web
  static void _showInAppBanner(String title, String body, String type, Map<String, dynamic> data) {
    final overlay = navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    // เลือกสี icon ตาม type
    Color bannerColor;
    IconData bannerIcon;
    switch (type) {
      case 'incident_new':
        bannerColor = Colors.red;
        bannerIcon = Icons.warning_amber;
        break;
      case 'incident_assigned':
        bannerColor = Colors.teal;
        bannerIcon = Icons.person_add;
        break;
      case 'chat':
      case 'dm':
        bannerColor = Colors.blue;
        bannerIcon = Icons.chat_bubble;
        break;
      default:
        bannerColor = Colors.orange;
        bannerIcon = Icons.notifications;
    }

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              entry.remove();
              NotificationRouter.handleNotificationTap(data);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bannerColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: bannerColor,
                    radius: 20,
                    child: Icon(bannerIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: bannerColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (body.isNotEmpty)
                          Text(
                            body,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => entry.remove(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss หลัง 6 วินาที
    Future.delayed(const Duration(seconds: 6), () {
      try {
        entry.remove();
      } catch (_) {
        // อาจถูก remove ไปแล้ว
      }
    });
  }

  // =============================================
  // Mobile Local Notifications
  // =============================================

  static Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(urgentChannel);
      await androidPlugin.createNotificationChannel(chatChannel);
      await androidPlugin.createNotificationChannel(statusChannel);
      debugPrint('[Noti] Created 3 notification channels');
    }
  }

  static Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = json.decode(response.payload!) as Map<String, dynamic>;
            NotificationRouter.handleNotificationTap(data);
          } catch (e) {
            debugPrint('[Noti] Error parsing payload: $e');
          }
        }
      },
    );
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return; // ใช้ _showWebNotification แทน

    final notification = message.notification;
    final data = message.data;

    if (notification == null && data.isEmpty) return;

    // Skip if the current user is the sender of the notification event
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final senderId = data['senderId'] as String?;
    if (senderId != null && currentUserId != null && senderId == currentUserId) {
      debugPrint('[FCM-Mobile] Suppressing notification triggered by self');
      return;
    }

    final title = notification?.title ?? data['title'] ?? 'ระบบแจ้งเหตุ';
    final body = notification?.body ?? data['body'] ?? '';
    final type = data['type'] ?? 'status';

    AndroidNotificationChannel channel;
    int notificationId;

    switch (type) {
      case 'incident':
      case 'incident_new':
      case 'incident_assigned':
        channel = urgentChannel;
        notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        break;
      case 'chat':
      case 'dm':
        channel = chatChannel;
        notificationId = (data['incidentId'] ?? data['chatId'] ?? '').hashCode;
        break;
      default:
        channel = statusChannel;
        notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: channel.importance == Importance.high ? Priority.high : Priority.defaultPriority,
      playSound: channel.playSound,
      enableVibration: channel.enableVibration,
      showWhen: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      fullScreenIntent: type == 'incident_new',
      ticker: title,
    );

    final details = NotificationDetails(android: androidDetails);
    final payload = json.encode(data);

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Noti] Error showing notification: $e');
    }
  }

  // =============================================
  // Trigger Server-Side Push Notification via Callable
  // =============================================

  /// v3: ทำงานทั้ง Web + Mobile — Web ก็ trigger Cloud Function ได้
  static Future<void> sendPushNotification({
    String? targetUid,
    List<String>? targetRoles,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? channelId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('sendPushNotification');
      
      await callable.call({
        if (targetUid != null) 'targetUid': targetUid,
        if (targetRoles != null) 'targetRoles': targetRoles,
        'title': title,
        'body': body,
        if (payload != null) 'payload': payload,
        if (channelId != null) 'channelId': channelId,
      });
      debugPrint('[Noti] Successfully triggered server push notification');
    } catch (e) {
      debugPrint('[Noti] Failed to trigger server push notification: $e');
    }
  }

  // =============================================
  // FCM Token Management — v3: รองรับ Web
  // =============================================

  /// บันทึก FCM Token ด้วยตนเองจากภายนอก
  static Future<void> saveToken() async {
    await _saveToken();
  }

  static Future<void> _saveToken() async {
    try {
      String? token;
      if (kIsWeb) {
        // Web: ลองดึง token (อาจต้อง VAPID key)
        try {
          token = await _messaging.getToken(
            vapidKey: null, // Firebase auto-detect — ถ้าไม่ได้ให้ set จาก Console
          );
        } catch (e) {
          debugPrint('[FCM-Web] getToken error (VAPID key อาจต้องตั้งค่า): $e');
        }
      } else {
        token = await _messaging.getToken();
      }

      if (token != null) {
        await _saveTokenToFirestore(token);
      } else {
        debugPrint('[FCM] Token is null — Web Push จะไม่ทำงาน (ต้องตั้งค่า VAPID key)');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('[FCM] Token saved for ${user.uid}');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// ลบ token เมื่อ logout
  static Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': null}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FCM] Error clearing token: $e');
    }
  }
}
