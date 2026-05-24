import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notification/notification_service.dart';

/// Chat Repository — v2: F8 Chat Read System + F7 lastMessage tracking
/// CRUD สำหรับ incidents/{incidentId}/messages
class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  /// Reference ไปยัง messages sub-collection
  CollectionReference _messagesRef(String incidentId) {
    return _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('messages');
  }

  /// Stream ข้อความ real-time (เรียงตามเวลา)
  Stream<QuerySnapshot> getMessages(String incidentId) {
    return _messagesRef(incidentId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// ส่งข้อความ + F8: อัปเดต lastMessageAt, lastMessageSenderId
  Future<void> sendMessage({
    required String incidentId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageUrl,
  }) async {
    await _messagesRef(incidentId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // F8: อัปเดต incident doc เพื่อ track ข้อความล่าสุด
    await _firestore.collection('incidents').doc(incidentId).update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
    });

    // Trigger push notification to other participants (including dispatchers)
    try {
      final doc = await _firestore.collection('incidents').doc(incidentId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final reporterId = data['reporterId'] as String?;
        final responderId = data['responderId'] as String?;
        final title = data['title'] as String? ?? 'เหตุการณ์';

        final pushBody = text.isNotEmpty ? '$senderName: $text' : '$senderName ส่งรูปภาพ';
        final pushTitle = '💬 ข้อความใหม่ (เหตุ: $title)';

        final basePayload = {
          'type': 'chat',
          'incidentId': incidentId,
          'incidentTitle': title,
          'senderId': senderId,
        };

        // แจ้ง Reporter
        if (reporterId != null && senderId != reporterId) {
          NotificationService.sendPushNotification(
            targetUid: reporterId,
            title: pushTitle,
            body: pushBody,
            payload: {...basePayload, 'userRole': 'user'},
            channelId: 'chat_messages',
          );
        }
        // แจ้ง Responder
        if (responderId != null && senderId != responderId) {
          NotificationService.sendPushNotification(
            targetUid: responderId,
            title: pushTitle,
            body: pushBody,
            payload: {...basePayload, 'userRole': 'responder'},
            channelId: 'chat_messages',
          );
        }
        // แจ้ง Dispatchers ทั้งหมด (ยกเว้นถ้าผู้ส่งเป็น dispatcher เอง)
        NotificationService.sendPushNotification(
          targetRoles: const ['dispatcher'],
          title: pushTitle,
          body: pushBody,
          payload: {...basePayload, 'userRole': 'dispatcher'},
          channelId: 'chat_messages',
        );
      }
    } catch (e) {
      // Ignore push errors to not break chat flow
    }
  }

  /// F8: Mark as read — อัปเดต lastReadBy.{uid} = now
  /// เรียกเมื่อเปิดหน้า chat
  Future<void> markAsRead(String incidentId, String uid) async {
    try {
      await _firestore.collection('incidents').doc(incidentId).update({
        'lastReadBy.$uid': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ไม่ให้ read marker fail ทำให้ chat พัง
    }
  }
}
