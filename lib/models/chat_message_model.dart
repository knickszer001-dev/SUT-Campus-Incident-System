import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat Message Model — F7 / Phase 4
/// Sub-collection: incidents/{incidentId}/messages/{messageId}
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
