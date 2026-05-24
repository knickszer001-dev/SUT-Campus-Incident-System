import 'package:cloud_firestore/cloud_firestore.dart';

/// UserModel — v3: เพิ่ม lastLocation field สำหรับ F5/F6
/// รองรับทั้ง camelCase (ใหม่) และ snake_case (เก่า) จาก Firestore
class UserModel {
  final String uid;
  final String email;
  final String studentId;       // 🆕 v2: รหัสนักศึกษา/บุคลากร
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String role;            // user / dispatcher / responder / admin
  final String? department;     // security / rescue / hospital
  final String? fcmToken;       // สำหรับ push notification
  final int volunteerPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? lastLocation;  // F6: { lat, lng, updatedAt }
  final String? profileImageUrl;  // UX: รูปโปรไฟล์ผู้ใช้

  const UserModel({
    required this.uid,
    required this.email,
    this.studentId = '',
    this.firstName = '',
    this.lastName = '',
    this.phoneNumber = '',
    this.role = 'user',
    this.department,
    this.fcmToken,
    this.volunteerPoints = 0,
    this.createdAt,
    this.updatedAt,
    this.lastLocation,
    this.profileImageUrl,
  });

  /// สร้าง UserModel จาก Firestore — รองรับทั้ง camelCase และ snake_case
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // F6: Parse lastLocation
    Map<String, dynamic>? locData;
    if (data['lastLocation'] is Map) {
      locData = Map<String, dynamic>.from(data['lastLocation']);
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      studentId: data['studentId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'user',
      department: data['department'],
      fcmToken: data['fcmToken'],
      // รองรับทั้ง camelCase (volunteerPoints) และ snake_case (volunteer_points)
      volunteerPoints: data['volunteerPoints'] ?? data['volunteer_points'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate()
                 ?? (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLocation: locData,
      profileImageUrl: data['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
      'studentId': studentId,
      'role': role,
      'department': department,
      'fcmToken': fcmToken,
      'volunteerPoints': volunteerPoints,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  /// F6: ดึงค่า lat/lng จาก lastLocation
  double? get lastLat => (lastLocation?['lat'] as num?)?.toDouble();
  double? get lastLng => (lastLocation?['lng'] as num?)?.toDouble();
}
