# 📋 Implementation Plan — SUT Campus Incident System

> เอกสารนี้อธิบาย **รายละเอียดการ implement จริง** แต่ละ feature  
> โค้ดที่แสดงคือโค้ดจริงจากโปรเจกต์ (ตัดย่อ) ไม่ใช่ตัวอย่างสมมติ  
> อ่านร่วมกับ [Architecture.md](./Architecture.md) เพื่อเข้าใจภาพรวมก่อน

---

## Feature 1: Authentication (Login / Register / Reset Password)

### ไฟล์: `features/auth/data/auth_repository.dart`

ระบบ login **ไม่ใช้ email จริง** แต่แปลง studentId เป็น email สมมติ:

```dart
// studentId "B6512345" → email "B6512345@campus.local"
final studentEmail = '$normalizedId@campus.local';

UserCredential result = await _auth.signInWithEmailAndPassword(
  email: studentEmail,
  password: password,
);
```

**ทำไม?** เพราะ Firebase Auth ต้องการ email — แต่เราอยากให้ผู้ใช้ login ด้วยรหัสนักศึกษาแทน  
จึงสร้าง email สมมติขึ้นมาในรูปแบบ `{studentId}@campus.local`

### เมื่อ Register สำเร็จ สร้าง user document ใน Firestore ทันที:
```dart
await _firestore.collection("users").doc(user.uid).set({
  "studentId": normalizedId,
  "firstName": firstName,
  "lastName": lastName,
  "phoneNumber": phoneNumber,
  "role": "user",           // role เริ่มต้นคือ user เสมอ
  "volunteerPoints": 0,
  "createdAt": FieldValue.serverTimestamp(),
});
```

### Reset Password — ผ่าน Cloud Functions:
ไม่ใช้ Firebase Email Reset ทั่วไป เพราะ user ไม่มี email จริง  
แต่ยืนยันตัวตนด้วย **studentId + เบอร์โทร** แล้วเรียก Cloud Function โดยตรง:

```dart
// Step 1: ยืนยันตัวตน
await callable('verifyStudentByPhone').call({
  'studentId': studentId,
  'phoneNumber': phoneNumber,
});

// Step 2: เปลี่ยนรหัสผ่าน (ถ้ายืนยันผ่าน)
await callable('resetPasswordByPhone').call({
  'studentId': studentId,
  'phoneNumber': phoneNumber,
  'newPassword': newPassword,
});
```

---

## Feature 2: Role Redirect

### ไฟล์: `features/auth/presentation/role_redirect.dart`

หลัง login สำเร็จ แอปต้อง route ไปหน้าที่ถูกต้องตาม role  
ใช้ `ConsumerStatefulWidget` + `initState` (ไม่ใช้ `FutureBuilder` ใน `build` เพื่อป้องกัน re-call ทุกครั้ง rebuild)

```dart
Future<void> _loadUserRole() async {
  // 1. ดึง user จาก Firebase Auth
  final user = ref.read(authStateProvider).value;

  // 2. ensureUserProfile: สร้าง document ถ้ายังไม่มี (กันกรณี user เก่า)
  await ref.read(authRepositoryProvider).ensureUserProfile(user)
      .timeout(const Duration(seconds: 10)); // timeout 10 วิ

  // 3. ดึง role จาก Firestore
  final doc = await firestore.collection('users').doc(user.uid).get();
  final role = doc.data()?['role'] ?? 'user';
  
  setState(() { _role = role; });
}
```

จากนั้น route ด้วย switch:
```dart
switch (_role) {
  case 'dispatcher': return DispatcherScreen();
  case 'responder':  return ResponderDashboard();
  case 'admin':      return AdminDashboard();
  default:           return HomeScreen(); // role: user
}
```

---

## Feature 3: Incident Model

### ไฟล์: `models/incident_model.dart`

Model มี 2 ชั้น status:

```dart
final String status;          // "NEW" | "IN_PROGRESS" | "RESOLVED" | "CANCELLED"
final String? timelineStatus; // "REPORTED" | "ACCEPTED" | "EN_ROUTE" | "ARRIVED" | "RESOLVED"
```

`timelineStatus` เป็น status ย่อยสำหรับ Responder เพื่อแสดงความคืบหน้าละเอียดกว่า `status` หลัก

Model มี **helper methods** สำหรับ UI โดยตรง:
```dart
incident.typeText     // "อุบัติเหตุ", "ความปลอดภัย" ฯลฯ
incident.priorityText // "🔴 เร่งด่วน", "🟠 ปานกลาง" ฯลฯ
incident.statusText   // "เหตุใหม่", "กำลังดำเนินการ" ฯลฯ
incident.hasUnreadMessages(uid) // true/false สำหรับ badge แจ้งเตือน
```

### fromFirestore / toFirestore:
```dart
// Firestore → Object (ใช้ตอน read)
factory Incident.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>? ?? {};
  return Incident(
    id: doc.id,
    title: data['title'] ?? '',
    priority: data['priority'] ?? 'LOW',
    // ... parse ทุก field รวมถึง lastReadBy map
  );
}

// Object → Map (ใช้ตอน write)
Map<String, dynamic> toFirestore() {
  return { 'title': title, 'status': status, ... };
}
```

---

## Feature 4: Incident Repository (CRUD)

### ไฟล์: `features/incident/data/incident_repository.dart`

### แจ้งเหตุใหม่ (submitIncident)
```dart
Future<String> submitIncident(Map<String, dynamic> data) async {
  // 1. บันทึกลง Firestore
  final docRef = await _firestore.collection("incidents").add(data);
  
  // 2. ส่ง push notification ไปหา dispatcher ทุกคนทันที
  NotificationService.sendPushNotification(
    targetRoles: const ['dispatcher'],
    title: '🚨 เหตุด่วนใหม่!',
    body: '$title (ระดับ: $priorityText)',
    payload: { 'type': 'incident_new', 'incidentId': docRef.id },
    channelId: 'urgent_incidents',
  );
  
  return docRef.id;
}
```

### อัปเดต Status — ใช้ Transaction (ป้องกัน race condition)
```dart
Future<bool> updateIncidentStatus(String incidentId, String newStatus) async {
  return await _firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final currentStatus = snapshot.data()?['status'];
    
    // ตรวจสอบว่า transition นี้ถูกกฎ state machine ไหม
    if (!ResponderLogic.canTransition(currentStatus, newStatus)) {
      throw Exception("Invalid state transition");
    }
    
    transaction.update(docRef, { "status": newStatus });
    return true;
  });
  
  // บันทึก Audit Log หลัง transaction สำเร็จ
  await addAuditLog(incidentId, 'STATUS_CHANGE', extra: {'newStatus': newStatus});
}
```

> **Transaction คืออะไร?** เหมือนการล็อกไฟล์ก่อนแก้ไข ถ้ามีคนอื่นแก้พร้อมกัน Firestore จะ retry ให้อัตโนมัติ ป้องกันข้อมูลชน

### Audit Log (#29)
ทุก action สำคัญ (assign, status change, cancel) บันทึกลง subcollection `logs`:
```dart
await addAuditLog(incidentId, 'ASSIGN', extra: {
  'responderId': responderId,
  'responderName': responderName,
});
```

### Rate Limiting (#4) — ป้องกัน spam แจ้งเหตุ
```dart
Future<int> countRecentIncidents(String uid, Duration duration) async {
  final since = DateTime.now().subtract(duration);
  final query = await _firestore.collection('incidents')
      .where('reporterId', isEqualTo: uid)
      .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
      .get();
  return query.docs.length;
}
```

---

## Feature 5: Smart Responder Suggestion (F5)

### ไฟล์: `incident_repository.dart` (method: `getRespondersWithStats`)

ระบบแนะนำ Responder อัตโนมัติโดยคำนวณ Score:

```
Score = department_match × 3
      + low_workload × 2
      + nearby × 1
```

```dart
// department match ตาม incident type
static const Map<String, String> typeToDepartment = {
  'security':   'security',
  'medical':    'hospital',
  'accident':   'rescue',
  'facility':   'security',
  'assistance': '_all',     // ทุกหน่วย
};

// คำนวณระยะทางด้วย Haversine Formula
double _haversineDistance(lat1, lng1, lat2, lng2) {
  // ระยะทางบนพื้นโลก (หน่วย km) จากพิกัด 2 จุด
  const R = 6371.0;
  // ... สูตร Haversine ...
}
```

ผล: List ของ Responder เรียงจาก Score มากไปน้อย พร้อม `activeCases` และ `distanceKm`

**Note สำคัญ:** ใช้ query เดียวดึง active incidents ทั้งหมดมาก่อน แล้วนับใน memory แทนการ query N+1 ครั้ง (ป้องกัน Firestore reads ระเบิด)

---

## Feature 6: Real-time Location Tracking (F6)

Responder อัปเดต GPS ลง Firestore:
```dart
await _firestore.collection('users').doc(uid).update({
  'lastLocation': {
    'lat': lat,
    'lng': lng,
    'updatedAt': FieldValue.serverTimestamp(),
  },
});
```

Dispatcher เห็น marker ทุกคนแบบ real-time:
```dart
Stream<QuerySnapshot> getRespondersLocationStream() {
  return _firestore.collection('users')
      .where('role', isEqualTo: 'responder')
      .snapshots(); // Stream → rebuild map อัตโนมัติเมื่อ location เปลี่ยน
}
```

---

## Feature 7: Chat System (F8)

มี 2 ประเภท:
- **Group Chat** (`chat_repository.dart`) — แชทในเหตุการณ์ ผู้แจ้ง + dispatcher + responder
- **Direct Chat** (`direct_chat_repository.dart`) — แชท 1:1 ระหว่าง 2 คน

### ระบบ Unread Badge
Incident model เก็บ `lastReadBy: { uid: timestamp }`:
```dart
bool hasUnreadMessages(String uid) {
  if (lastMessageAt == null) return false;
  if (lastMessageSenderId == uid) return false; // ข้อความตัวเองไม่นับ
  final lastRead = lastReadBy[uid];
  if (lastRead == null) return true;           // ยังไม่เคยอ่านเลย
  return lastMessageAt!.isAfter(lastRead);     // มีข้อความใหม่หลังที่อ่านล่าสุด
}
```

---

## Feature 8: Push Notification

### ไฟล์: `features/notification/notification_service.dart`

ส่ง notification ได้ 2 แบบ:
```dart
// แบบ 1: ส่งตาม role (เช่น ส่งหา dispatcher ทุกคน)
NotificationService.sendPushNotification(
  targetRoles: ['dispatcher'],
  title: '🚨 เหตุด่วนใหม่!',
  body: 'อุบัติเหตุ (ระดับ: สูง)',
);

// แบบ 2: ส่งหาคนเฉพาะตาม uid
NotificationService.sendPushNotification(
  targetUid: reporterId,
  title: '🔄 อัปเดตสถานะเหตุการณ์',
  body: 'เหตุ "..." เปลี่ยนสถานะเป็น: เสร็จสิ้น',
);
```

Deep link: เมื่อผู้ใช้กด notification จะ navigate ไปหน้า incident นั้นโดยตรง ผ่าน `notification_router.dart`

---

## Feature 9: Startup Flow (main.dart + _AuthGate)

```
Firebase.initializeApp()
  ↓
NotificationService.initialize()
  ↓
RemoteConfigService.initialize()
  ↓
runApp(ProviderScope(CampusIncidentApp))
  ↓
authState == null → _AuthGate
  ↓
Splash Screen 2.2 วินาที (fade + scale animation)
  ↓
เช็ค SharedPreferences: เคยเห็น Onboarding ไหม?
  ├── ยัง → OnboardingScreen
  └── แล้ว → LoginScreen
```

---

## คำถามที่อาจารย์มักถาม

| คำถาม | คำตอบจากโค้ดจริง |
|-------|----------------|
| ทำไม login ด้วยรหัสนักศึกษาได้? | แปลง studentId → `{id}@campus.local` แล้วส่งให้ Firebase Auth |
| Role-based access ทำยังไง? | อ่าน `role` จาก Firestore ใน `RoleRedirect` แล้ว route ไปหน้าจอที่ถูกต้อง |
| Real-time update ทำงานยังไง? | Firestore `.snapshots()` คืน Stream → `StreamBuilder` / Riverpod `StreamProvider` rebuild UI อัตโนมัติ |
| ป้องกัน race condition ยังไง? | ใช้ Firestore Transaction ใน `updateIncidentStatus` |
| Smart assignment ทำยังไง? | คำนวณ Score จาก department + workload + distance (Haversine) |
| Reset password ทำยังไง? | ยืนยันตัวตนด้วยรหัสนักศึกษา + เบอร์โทร แล้วเรียก Cloud Function |
| Notification ส่งยังไง? | FCM ผ่าน `NotificationService` ส่งได้ทั้ง by role และ by uid |
| บน Web ต่างจาก Mobile ยังไง? | ปิด Firestore offline persistence, ใช้ `WebNotificationWatcher` แทน FCM background |

---

*เอกสารนี้เป็นส่วนหนึ่งของ [README.md](./README.md) และ [Architecture.md](./Architecture.md)*
