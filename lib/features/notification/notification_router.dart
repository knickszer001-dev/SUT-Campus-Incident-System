import 'package:flutter/material.dart';

import '../incident/presentation/incident_detail_screen.dart';
import '../chat/presentation/chat_screen.dart';
import '../chat/presentation/direct_chat_screen.dart';
import 'notification_service.dart';

/// Notification Router — Deep link navigation เมื่อกด notification
/// รองรับ type: incident / chat / dm / status
class NotificationRouter {

  /// จัดการ navigation เมื่อกด notification
  static void handleNotificationTap(Map<String, dynamic> data) {
    final navigator = NotificationService.navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('[NotificationRouter] Navigator not ready');
      return;
    }

    final type = data['type'] ?? '';
    debugPrint('[NotificationRouter] Handling tap: type=$type, data=$data');

    switch (type) {
      // เหตุการณ์ → เปิดหน้ารายละเอียดเหตุ
      case 'incident':
      case 'incident_new':
      case 'incident_assigned':
      case 'status':
        final incidentId = data['incidentId'] as String?;
        if (incidentId != null && incidentId.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incidentId),
            ),
          );
        }
        break;

      // แชทเหตุ → เปิดหน้าแชท
      case 'chat':
        final incidentId = data['incidentId'] as String?;
        final incidentTitle = data['incidentTitle'] as String? ?? 'แชท';
        final userRole = data['userRole'] as String? ?? 'user';
        if (incidentId != null && incidentId.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                incidentId: incidentId,
                incidentTitle: incidentTitle,
                userRole: userRole,
              ),
            ),
          );
        }
        break;

      // DM → เปิดหน้าแชทตรง
      case 'dm':
        final otherUserId = data['senderId'] as String?;
        final otherUserName = data['senderName'] as String? ?? 'ผู้ส่ง';
        final currentRole = data['receiverRole'] as String? ?? 'responder';
        if (otherUserId != null && otherUserId.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => DirectChatScreen(
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                currentUserRole: currentRole,
              ),
            ),
          );
        }
        break;

      default:
        debugPrint('[NotificationRouter] Unknown type: $type');
    }
  }
}
