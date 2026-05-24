import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AuthRepository — v2: เปลี่ยนจาก email เป็น studentId
/// - register: รับ studentId, สร้าง email สมมติ $studentId@campus.local
/// - login: รับ studentId + password, แปลงเป็น email สมมติก่อนเรียก Firebase Auth
/// - checkStudentIdExists: ตรวจสอบ studentId ซ้ำก่อน register
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

  /// REGISTER — v2: ใช้ studentId + สร้าง email สมมติ
  /// ไม่ต้อง pre-check studentId ซ้ำ เพราะ Firebase Auth จะ reject email ซ้ำให้อัตโนมัติ
  /// (email สมมติ = $studentId@campus.local → studentId ซ้ำ = email ซ้ำ)
  Future<User?> register(
    String studentId,
    String firstName,
    String lastName,
    String phoneNumber,
    String password,
  ) async {
    final normalizedId = studentId.toUpperCase();
    final fakeEmail = '$normalizedId@campus.local';

    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: fakeEmail,
      password: password,
    );

    User? user = result.user;

    if (user != null) {
      await _firestore.collection("users").doc(user.uid).set({
        "studentId": normalizedId,
        "firstName": firstName,
        "lastName": lastName,
        "phoneNumber": phoneNumber,
        "email": fakeEmail,
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

  /// LOGIN — v2: รับ studentId + password, แปลงเป็น email สมมติ
  Future<User?> login(String studentId, String password) async {
    final normalizedId = studentId.toUpperCase();
    final fakeEmail = '$normalizedId@campus.local';

    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: fakeEmail,
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

  /// F3: รีเซ็ตรหัสผ่าน — ส่ง email reset ไปยัง studentId@campus.local
  /// หมายเหตุ: เนื่องจากใช้ email สมมติ (campus.local) จึงไม่มี inbox จริง
  /// วิธีนี้จะใช้กับระบบที่มี mail server ภายใน หรือใช้ Admin SDK reset แทน
  /// สำหรับ production: ให้ admin reset ผ่าน Firebase Console หรือ Cloud Function
  Future<void> resetPassword(String studentId) async {
    final normalizedId = studentId.toUpperCase();

    // ตรวจว่ามี studentId นี้ในระบบ
    final exists = await checkStudentIdExists(normalizedId);
    if (!exists) {
      throw Exception('ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ');
    }

    final fakeEmail = '$normalizedId@campus.local';
    await _auth.sendPasswordResetEmail(email: fakeEmail);
  }
}