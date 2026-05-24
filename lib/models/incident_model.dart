import 'package:cloud_firestore/cloud_firestore.dart';

/// Incident Model — v3: เพิ่ม F8 Chat Read System fields
class Incident {
  final String id;
  final String title;
  final String description;
  final String type;           // accident / facility / assistance / security / medical
  final String priority;       // HIGH / MEDIUM / LOW / CRITICAL
  final String status;         // v2: NEW / IN_PROGRESS / RESOLVED
  final String? timelineStatus; // REPORTED, ACCEPTED, EN_ROUTE, ARRIVED, RESOLVED

  final String? reporterId;
  final String? reporterName;

  final String? department;    // หน่วยงานที่รับผิดชอบ
  final String? dispatcherId;  // uid ของ dispatcher ที่จัดการ
  final String? responderId;
  final String? responderName;

  final double? latitude;
  final double? longitude;

  final List<String> imageUrls; // รูปจาก Firebase Storage

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;   // เวลาปิดเคส (สำหรับ SLA)

  // F8: Chat Read System
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, DateTime> lastReadBy;  // { uid: timestamp }

  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    this.timelineStatus,
    this.reporterId,
    this.reporterName,
    this.department,
    this.dispatcherId,
    this.responderId,
    this.responderName,
    this.latitude,
    this.longitude,
    this.imageUrls = const [],
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastReadBy = const {},
  });

  /// สร้าง Incident จาก Firestore DocumentSnapshot
  factory Incident.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // F8: Parse lastReadBy map
    final Map<String, DateTime> readByMap = {};
    if (data['lastReadBy'] is Map) {
      (data['lastReadBy'] as Map).forEach((key, value) {
        if (value is Timestamp) {
          readByMap[key.toString()] = value.toDate();
        }
      });
    }

    return Incident(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? '',
      priority: data['priority'] ?? 'LOW',
      status: data['status'] ?? 'NEW',
      timelineStatus: data['timelineStatus'],
      reporterId: data['reporterId'],
      reporterName: data['reporterName'],
      department: data['department'],
      dispatcherId: data['dispatcherId'],
      responderId: data['responderId'],
      responderName: data['responderName'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      lastReadBy: readByMap,
    );
  }

  /// แปลง Incident เป็น Map สำหรับเขียนลง Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      'status': status,
      'timelineStatus': timelineStatus,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'department': department,
      'dispatcherId': dispatcherId,
      'responderId': responderId,
      'responderName': responderName,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // === UI Helper Methods ===

  String get typeText {
    switch (type) {
      case 'accident':
        return 'อุบัติเหตุ';
      case 'facility':
        return 'ปัญหาสาธารณูปโภค';
      case 'assistance':
        return 'ขอความช่วยเหลือ';
      case 'security':
        return 'ความปลอดภัย';
      case 'medical':
        return 'การแพทย์';
      default:
        return 'อื่นๆ';
    }
  }

  String get priorityText {
    switch (priority) {
      case 'CRITICAL':
        return '🔴 ฉุกเฉินมาก';
      case 'HIGH':
        return '🔴 เร่งด่วน';
      case 'MEDIUM':
        return '🟠 ปานกลาง';
      case 'LOW':
        return '🟢 ทั่วไป';
      default:
        return '-';
    }
  }

  /// v2: ปรับ statusText เหลือ 3 สถานะ
  String get statusText {
    switch (status) {
      case 'NEW':
        return 'เหตุใหม่';
      case 'IN_PROGRESS':
        return 'กำลังดำเนินการ';
      case 'RESOLVED':
        return 'เสร็จสิ้น';
      default:
        return status;
    }
  }

  String get formattedTime {
    if (createdAt == null) return '';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year} '
           '${createdAt!.hour}:${createdAt!.minute.toString().padLeft(2, '0')}';
  }

  /// F8: ตรวจว่ามีข้อความที่ยังไม่อ่านสำหรับ uid นี้หรือไม่
  bool hasUnreadMessages(String uid) {
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId == uid) return false; // ข้อความล่าสุดเป็นของตัวเอง
    final lastRead = lastReadBy[uid];
    if (lastRead == null) return true; // ยังไม่เคยอ่าน
    return lastMessageAt!.isAfter(lastRead);
  }
}
