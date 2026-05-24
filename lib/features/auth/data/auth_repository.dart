import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// AuthRepository — v3: เปลี่ยนจาก email เป็น studentId พร้อมเชื่อมโยง GSuite มทส. (@g.sut.ac.th)
/// - register: รับ studentId, สร้าง email จริง $studentId@g.sut.ac.th
/// - login: รับ studentId + password, แปลงเป็น email ก่อนเรียก Firebase Auth
/// - checkStudentIdExists: ตรวจสอบ studentId ซ้ำก่อน register
/// - resetPasswordByPhone: ยืนยันตัวตนด้วยเบอร์โทร แล้วเปลี่ยนรหัสผ่านโดยตรงผ่าน Cloud Function
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  /// ตรวจสอบว่ารหัสนักศึกษา/บุคลากรนี้ถูกใช้ไปแล้วหรือยัง
  Future<bool> checkStudentIdExists(String studentId) async {
    final query = await _firestore
        .collection('users')
        .where('studentId', isEqualTo: studentId.toUpperCase())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// REGISTER — v4: ใช้ studentId + สร้าง email สมมติ @campus.local ตามรูปแบบดั้งเดิม
  Future<User?> register(
    String studentId,
    String firstName,
    String lastName,
    String phoneNumber,
    String password,
  ) async {
    final normalizedId = studentId.toUpperCase();
    final studentEmail = '$normalizedId@campus.local';

    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: studentEmail,
      password: password,
    );

    User? user = result.user;

    if (user != null) {
      await _firestore.collection("users").doc(user.uid).set({
        "studentId": normalizedId,
        "firstName": firstName,
        "lastName": lastName,
        "phoneNumber": phoneNumber,
        "email": studentEmail,
        "role": "user",
        "department": null,
        "fcmToken": null,
        "volunteerPoints": 0,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    return user;
  }

  /// LOGIN — v4: รับ studentId + password, แปลงเป็น email สมมติ @campus.local
  Future<User?> login(String studentId, String password) async {
    final normalizedId = studentId.toUpperCase();
    final studentEmail = '$normalizedId@campus.local';

    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: studentEmail,
      password: password,
    );
    return result.user;
  }

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// สร้างข้อมูลเริ่มต้นให้ user เก่าที่ยังไม่มี document ใน Firestore
  Future<void> ensureUserProfile(User user) async {
    final doc = await _firestore.collection("users").doc(user.uid).get();
    if (!doc.exists) {
      await _firestore.collection("users").doc(user.uid).set({
        "studentId": "",
        "firstName": "",
        "lastName": "",
        "phoneNumber": "",
        "email": user.email ?? "",
        "role": "user",
        "department": null,
        "fcmToken": null,
        "volunteerPoints": 0,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  /// ดึงชื่อผู้ใช้ปัจจุบัน (สำหรับเก็บ reporterName ตอนแจ้งเหตุ)
  Future<String> getCurrentUserName() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final doc = await _firestore.collection("users").doc(user.uid).get();
    if (!doc.exists) return user.email ?? '';
    final data = doc.data()!;
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    return name.isNotEmpty ? name : (data['studentId'] ?? user.email ?? '');
  }

  /// #3: เปลี่ยนรหัสผ่านของตัวเอง (ต้อง login อยู่)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    // Re-authenticate ก่อนเปลี่ยน
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// F3 Step 1: ยืนยันตัวตนด้วยรหัสนักศึกษา + เบอร์โทร (ไม่เปลี่ยนรหัสผ่าน)
  Future<void> verifyStudentByPhone(String studentId, String phoneNumber) async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('verifyStudentByPhone');

    try {
      await callable.call({
        'studentId': studentId.trim().toUpperCase(),
        'phoneNumber': phoneNumber.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'not-found':
          throw Exception('ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ');
        case 'permission-denied':
          throw Exception('เบอร์โทรศัพท์ไม่ตรงกับที่ลงทะเบียนไว้');
        default:
          throw Exception('เกิดข้อผิดพลาด กรุณาลองใหม่');
      }
    }
  }

  /// F3 Step 2: เปลี่ยนรหัสผ่านผ่าน Cloud Function (หลังยืนยันตัวตนแล้ว)
  Future<void> resetPasswordByPhone(String studentId, String phoneNumber, String newPassword) async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('resetPasswordByPhone');

    try {
      await callable.call({
        'studentId': studentId.trim().toUpperCase(),
        'phoneNumber': phoneNumber.trim(),
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'not-found':
          throw Exception('ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ');
        case 'permission-denied':
          throw Exception('เบอร์โทรศัพท์ไม่ตรงกับที่ลงทะเบียนไว้');
        case 'invalid-argument':
          throw Exception(e.message ?? 'ข้อมูลไม่ถูกต้อง');
        default:
          throw Exception('เกิดข้อผิดพลาด กรุณาลองใหม่');
      }
    }
  }
}