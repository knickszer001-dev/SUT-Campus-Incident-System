import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/web_notification.dart' as web_noti;
import '../dispatcher/sound_alert_service.dart';

/// Web Notification Watcher — v3
/// ตรวจจับเหตุการณ์ + แชท + DM จาก Firestore แบบ real-time
/// เสียงแยกประเภท: เหตุใหม่ = 3 ติ๊ด, แชท/DM = 1 ติ๊ด
class WebNotificationWatcher extends StatefulWidget {
  final Widget child;
  const WebNotificationWatcher({super.key, required this.child});

  /// Track ว่าผู้ใช้กำลังอยู่ในห้องแชทไหน (ใช้สำหรับ suppress notification)
  static String? activeIncidentChatId;
  static String? activeDmChatId;

  @override
  State<WebNotificationWatcher> createState() => _WebNotificationWatcherState();
}

class _WebNotificationWatcherState extends State<WebNotificationWatcher> {
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  String? _userRole;
  String? _userId;
  int _prevIncidentCount = -1;
  bool _firstAssignedLoad = true;
  final Map<String, Timestamp?> _lastMessageTimestamps = {};
  final Map<String, Timestamp?> _lastDmTimestamps = {};
  final Map<String, String> _lastIncidentStatus = {};
  final Map<String, String> _lastIncidentTimelineStatus = {};

  void _cleanupWatcher() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _prevIncidentCount = -1;
    _firstAssignedLoad = true;
    _lastMessageTimestamps.clear();
    _lastDmTimestamps.clear();
    _lastIncidentStatus.clear();
    _lastIncidentTimelineStatus.clear();
    _userRole = null;
    _userId = null;
  }

  @override
  void initState() {
    super.initState();
    // ทำงานทุกแพลตฟอร์ม (Web, Windows, Mobile)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _cleanupWatcher();
      if (user != null) {
        _initWatcher(user);
      }
    });
  }

  Future<void> _initWatcher(User user) async {
    _userId = user.uid;

    // เริ่มต้น SoundAlertService สำหรับเล่นเสียงบน Windows/Mobile/Web
    await SoundAlertService.initialize();

    // ดึง role ของ user
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      _userRole = doc.data()?['role'] as String? ?? 'user';
    } catch (e) {
      _userRole = 'user';
    }

    if (!mounted) return;
    debugPrint('[WebNotiWatcher] Starting for role=$_userRole, uid=$_userId');

    // ขอ browser notification permission (เฉพาะ Web)
    try {
      await web_noti.requestBrowserNotificationPermission();
    } catch (_) {}

    if (!mounted) return;

    // === Watch ตาม role ===
    if (_userRole == 'dispatcher') {
      _watchNewIncidents();
      _watchDispatcherChats();
    } else if (_userRole == 'responder') {
      _watchAssignedIncidents();
    }

    // ทุก role: watch การอัปเดตสถานะ (Status / Timeline)
    _watchStatusUpdates();

    // ทุก role: watch chat messages สำหรับ incidents ที่เกี่ยวข้อง
    _watchChatMessages();

    // เฉพาะ dispatcher, admin, responder: watch DM (ป้องกัน permission-denied สำหรับ user ทั่วไป)
    if (_userRole == 'dispatcher' || _userRole == 'admin' || _userRole == 'responder') {
      _watchDirectMessages();
    }
  }

  // ================================================================
  // Incident Watchers
  // ================================================================

  /// Dispatcher: watch เหตุใหม่ที่สถานะ NEW
  void _watchNewIncidents() {
    final sub = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isEqualTo: 'NEW')
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      if (_prevIncidentCount >= 0 && count > _prevIncidentCount) {
        final diff = count - _prevIncidentCount;
        _showAlert(
          '🚨 เหตุด่วนใหม่ ($diff รายการ)',
          'มีเหตุการณ์ใหม่รอดำเนินการ กรุณาตรวจสอบ',
          type: 'incident',
        );
      }
      _prevIncidentCount = count;
    });
    _subscriptions.add(sub);
  }

  /// Dispatcher: watch แชทจาก Responder ในเหตุที่กำลังดำเนินการ
  void _watchDispatcherChats() {
    final sub = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isEqualTo: 'IN_PROGRESS')
        .snapshots()
        .listen((snapshot) => _checkNewMessages(snapshot));
    _subscriptions.add(sub);
  }

  /// Responder: watch เหตุที่ถูก assign ให้ตัวเอง
  void _watchAssignedIncidents() {
    final sub = FirebaseFirestore.instance
        .collection('incidents')
        .where('responderId', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) {
      if (_firstAssignedLoad) {
        _firstAssignedLoad = false;
        _prevIncidentCount = snapshot.docs.length;
        return;
      }
      final count = snapshot.docs.length;
      if (count > _prevIncidentCount) {
        _showAlert(
          '📋 งานมอบหมายใหม่',
          'คุณได้รับมอบหมายเหตุการณ์ใหม่ กรุณาตรวจสอบ',
          type: 'incident',
        );
      }
      _prevIncidentCount = count;
    });
    _subscriptions.add(sub);
  }

  // ================================================================
  // Incident Chat Watcher
  // ================================================================

  void _watchChatMessages() {
    if (_userId == null) return;

    // Watch เหตุที่ user เป็นผู้แจ้ง
    final sub1 = FirebaseFirestore.instance
        .collection('incidents')
        .where('reporterId', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) => _checkNewMessages(snapshot));
    _subscriptions.add(sub1);
    
    // Watch เหตุที่ user เป็น responder (dispatcher ใช้ _watchDispatcherChats แทน)
    if (_userRole != 'dispatcher') {
      final sub2 = FirebaseFirestore.instance
          .collection('incidents')
          .where('responderId', isEqualTo: _userId)
          .snapshots()
          .listen((snapshot) => _checkNewMessages(snapshot));
      _subscriptions.add(sub2);
    }
  }

  void _checkNewMessages(QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastMsg = data['lastMessageAt'] as Timestamp?;
      final lastSenderId = data['lastMessageSenderId'] as String?;
      final title = data['title'] as String? ?? 'เหตุการณ์';
      final prevTimestamp = _lastMessageTimestamps[doc.id];
      
      if (lastMsg != null && lastSenderId != _userId) {
        if (prevTimestamp != null && lastMsg.compareTo(prevTimestamp) > 0) {
          // Issue #6: Suppress ถ้าผู้ใช้อยู่ในห้องแชทนั้นอยู่แล้ว
          if (WebNotificationWatcher.activeIncidentChatId == doc.id) {
            debugPrint('[WebNotiWatcher] Suppressed chat noti — user in chat ${doc.id}');
          } else {
            _showAlert(
              '💬 ข้อความใหม่',
              'มีข้อความใหม่ในเหตุ: $title',
              type: 'chat',
            );
          }
        }
      }
      _lastMessageTimestamps[doc.id] = lastMsg;
    }
  }

  // ================================================================
  // Direct Message Watcher (Fix #3)
  // ================================================================

  void _watchDirectMessages() {
    if (_userId == null) return;

    final sub = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('participants', arrayContains: _userId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastMsg = data['lastMessageAt'] as Timestamp?;
        final lastSenderId = data['lastMessageSenderId'] as String?;
        final lastText = (data['lastMessage'] ?? data['lastMessageText']) as String? ?? '';
        final prevTimestamp = _lastDmTimestamps[doc.id];

        if (lastMsg != null && lastSenderId != _userId) {
          if (prevTimestamp != null && lastMsg.compareTo(prevTimestamp) > 0) {
            // Issue #6: Suppress ถ้าผู้ใช้อยู่ใน DM นั้นอยู่แล้ว
            if (WebNotificationWatcher.activeDmChatId == doc.id) {
              debugPrint('[WebNotiWatcher] Suppressed DM noti — user in DM ${doc.id}');
            } else {
              _showAlert(
                '📩 ข้อความส่วนตัว',
                lastText.isNotEmpty ? lastText : 'ส่งรูปภาพ',
                type: 'chat',
              );
            }
          }
        }
        _lastDmTimestamps[doc.id] = lastMsg;
      }
    });
    _subscriptions.add(sub);
  }

  // ================================================================
  // Status Update Watcher
  // ================================================================

  /// Watch การอัปเดตสถานะหลัก และสถานะไทม์ไลน์ตาม Role ของผู้ใช้
  void _watchStatusUpdates() {
    if (_userId == null) return;

    Query query = FirebaseFirestore.instance.collection('incidents');

    // กรองเหตุการณ์ตาม Role เพื่อลดการเขียนอ่าน Firestore เกินจำเป็น
    if (_userRole == 'user') {
      // ผู้แจ้ง: ติดตามเฉพาะเหตุที่ตนเองแจ้ง
      query = query.where('reporterId', isEqualTo: _userId);
    } else if (_userRole == 'responder') {
      // ผู้รับเคส: ติดตามเฉพาะเหตุที่ตนเองได้รับมอบหมาย
      query = query.where('responderId', isEqualTo: _userId);
    } else if (_userRole == 'dispatcher' || _userRole == 'admin') {
      // Dispatcher/Admin: ติดตามเหตุทั้งหมดที่ยังดำเนินการอยู่
      query = query.where('status', whereIn: ['NEW', 'IN_PROGRESS']);
    } else {
      return;
    }

    bool firstLoad = true;
    final sub = query.snapshots().listen((snapshot) {
      if (firstLoad) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          _lastIncidentStatus[doc.id] = data['status'] as String? ?? 'NEW';
          _lastIncidentTimelineStatus[doc.id] = data['timelineStatus'] as String? ?? '';
        }
        firstLoad = false;
        return;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final incidentId = doc.id;
        final title = data['title'] as String? ?? 'เหตุการณ์';
        final newStatus = data['status'] as String? ?? 'NEW';
        final newTimeline = data['timelineStatus'] as String? ?? '';

        final oldStatus = _lastIncidentStatus[incidentId];
        final oldTimeline = _lastIncidentTimelineStatus[incidentId];

        // 1. ตรวจสอบสถานะหลักเปลี่ยน (เช่น NEW -> IN_PROGRESS หรือ IN_PROGRESS -> RESOLVED)
        if (oldStatus != null && oldStatus != newStatus) {
          String statusText = _getStatusTextThai(newStatus);
          _showAlert(
            '🔄 อัปเดตสถานะเหตุการณ์',
            'เหตุ "$title" เปลี่ยนสถานะเป็น: $statusText',
            type: 'status_update',
          );
        }
        // 2. ตรวจสอบสถานะไทม์ไลน์เปลี่ยน (เช่น ACCEPTED, EN_ROUTE, ARRIVED)
        else if (oldTimeline != null && oldTimeline != newTimeline && newTimeline.isNotEmpty) {
          String timelineText = _getTimelineTextThai(newTimeline);
          _showAlert(
            '📍 อัปเดตสถานะการปฏิบัติงาน',
            'เหตุ "$title": $timelineText',
            type: 'status_update',
          );
        }

        _lastIncidentStatus[incidentId] = newStatus;
        _lastIncidentTimelineStatus[incidentId] = newTimeline;
      }
    });

    _subscriptions.add(sub);
  }

  String _getStatusTextThai(String status) {
    switch (status) {
      case 'NEW': return 'เหตุใหม่';
      case 'IN_PROGRESS': return 'กำลังดำเนินการ';
      case 'RESOLVED': return 'เสร็จสิ้น';
      case 'CANCELLED': return 'ยกเลิก';
      default: return status;
    }
  }

  String _getTimelineTextThai(String timeline) {
    switch (timeline) {
      case 'REPORTED': return 'รายงานเหตุแล้ว';
      case 'ACCEPTED': return 'รับเคสแล้ว';
      case 'EN_ROUTE': return 'กำลังเดินทาง';
      case 'ARRIVED': return 'ถึงที่เกิดเหตุแล้ว';
      case 'RESOLVED': return 'เสร็จสิ้นภารกิจ';
      default: return timeline;
    }
  }

  // ================================================================
  // Alert Display
  // ================================================================

  void _showAlert(String title, String body, {String type = 'incident'}) {
    // 1. Browser notification (ทำงานเฉพาะ Web)
    if (kIsWeb) {
      web_noti.showBrowserNotification(title, body);
    }

    // 2. เสียงแยกประเภท และสั่นสะเทือนตามแต่ละแพลตฟอร์ม
    if (kIsWeb) {
      if (type == 'incident') {
        web_noti.playWebAlertSoundMultiple(3);
        web_noti.vibrateDevice([300, 100, 300, 100, 300]);
      } else if (type == 'chat') {
        web_noti.playWebAlertSound();
        web_noti.vibrateDevice([200, 100, 200]);
      } else {
        // status_update
        web_noti.playWebAlertSound();
        web_noti.vibrateDevice([150, 100, 150]);
      }
    } else {
      // Windows & Mobile: ใช้ SoundAlertService (audioplayers)
      if (type == 'incident') {
        SoundAlertService.playAlert();
      } else {
        SoundAlertService.playShortAlert();
      }

      // สั่นสะเทือนเฉพาะบน Mobile (Android / iOS)
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        if (type == 'incident') {
          HapticFeedback.vibrate();
          Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.vibrate());
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    }

    // In-app snackbar
    if (mounted) {
      Color color;
      IconData icon;
      if (type == 'incident') {
        color = Colors.red.shade700;
        icon = Icons.warning_amber;
      } else if (type == 'chat') {
        color = Colors.blue.shade700;
        icon = Icons.chat_bubble;
      } else {
        // status_update
        color = Colors.teal.shade700;
        icon = Icons.sync;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(body, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cleanupWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
