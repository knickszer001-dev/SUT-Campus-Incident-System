import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notification/notification_service.dart';

/// Direct Chat Repository — DM ระหว่าง Dispatcher ↔ Responder
/// Collection: direct_messages/{chatId}/messages
class DirectChatRepository {
  final FirebaseFirestore _firestore;

  DirectChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  /// สร้าง chatId จาก uid ของ 2 ฝ่าย (เรียง alphabetical ให้ unique)
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'dm_${sorted[0]}_${sorted[1]}';
  }

  /// Reference ไปยัง messages sub-collection
  CollectionReference _messagesRef(String chatId) {
    return _firestore
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages');
  }

  /// Stream ข้อความ real-time (เรียงตามเวลา)
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _messagesRef(chatId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// ส่งข้อความ + อัปเดต metadata ของ chat doc
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageUrl,
    required List<String> participantIds,
  }) async {
    await _messagesRef(chatId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // อัปเดต chat doc metadata
    await _firestore.collection('direct_messages').doc(chatId).set({
      'participants': participantIds,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': text,
      'lastMessage': text, // Write both lastMessageText and lastMessage to prevent field mismatch
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Trigger push notification to the other participant
    try {
      final otherUid = participantIds.firstWhere((id) => id != senderId, orElse: () => '');
      if (otherUid.isNotEmpty) {
        // Fetch receiver's role to send appropriate deep link data
        final userDoc = await _firestore.collection('users').doc(otherUid).get();
        final receiverRole = userDoc.exists ? (userDoc.data()?['role'] ?? 'responder') : 'responder';

        NotificationService.sendPushNotification(
          targetUid: otherUid,
          title: '📩 ข้อความส่วนตัวจาก $senderName',
          body: text.isNotEmpty ? text : 'ส่งรูปภาพ',
          payload: {
            'type': 'dm',
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
            'receiverRole': receiverRole,
          },
          channelId: 'chat_messages',
        );
      }
    } catch (e) {
      // Ignore errors so chat doesn't break
    }
  }

  /// Mark as read — ใช้ update() เพื่อให้ dot notation ทำงานเป็น nested path ถูกต้อง
  Future<void> markAsRead(String chatId, String uid) async {
    try {
      await _firestore.collection('direct_messages').doc(chatId).update({
        'lastReadBy.$uid': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ถ้า doc ยังไม่มี (update จะ fail) → ใช้ set + merge แบบ nested map แทน
      try {
        await _firestore.collection('direct_messages').doc(chatId).set({
          'lastReadBy': {uid: FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      } catch (_) {
        // ไม่ให้ read marker fail ทำให้ chat พัง
      }
    }
  }

  /// ดึง chat list ที่ user เป็นผู้เข้าร่วม
  Stream<QuerySnapshot> getMyChats(String uid) {
    return _firestore
        .collection('direct_messages')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }
}
