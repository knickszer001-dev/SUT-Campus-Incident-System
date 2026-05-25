# 🏗️ Architecture.md — SUT Campus Incident System

> อ่านไฟล์นี้เพื่อเข้าใจ **ว่าระบบทำงานยังไง** ก่อนลงโค้ด  
> อ่านร่วมกับ [Implementation_Plan.md](./Implementation_Plan.md) สำหรับรายละเอียด

---

## 1. ภาพรวมสถาปัตยกรรม

```
┌──────────────────────────────────────────────────────────────────┐
│                    📱 Flutter App                                 │
│                                                                   │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────────┐   │
│  │  Screens /  │───▶│  Riverpod    │───▶│   Repositories     │   │
│  │  Widgets    │    │  Providers   │    │  (data layer)      │   │
│  │(Presentation│◀───│  (State Mgmt)│◀───│                    │   │
│  │   Layer)    │    └──────────────┘    └────────┬───────────┘   │
│  └─────────────┘                                 │               │
│                                                  │ Firebase SDK  │
└──────────────────────────────────────────────────┼───────────────┘
                                                   │
                    ┌──────────────────────────────▼───────────────┐
                    │              ☁️ Firebase                      │
                    │                                               │
                    │  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
                    │  │  Auth    │ │Firestore │ │  Storage    │  │
                    │  └──────────┘ └──────────┘ └─────────────┘  │
                    │  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
                    │  │   FCM    │ │Functions │ │Remote Config│  │
                    │  └──────────┘ └──────────┘ └─────────────┘  │
                    └───────────────────────────────────────────────┘
```

---

## 2. Pattern ที่ใช้: Feature-based + Repository Pattern + Riverpod

โปรเจกต์นี้ **ไม่ได้ใช้ MVC หรือ MVVM แบบทั่วไป** แต่ใช้ pattern ที่เหมาะกับ Flutter มากกว่า:

```
features/
  auth/
    data/         ← Repository: คุยกับ Firebase โดยตรง
    domain/       ← Business Logic: กฎที่ไม่ขึ้นกับ Firebase
    presentation/ ← Screens + Widgets: แสดงผล UI
```

### ทำไมถึงแบ่งแบบนี้?

| ชั้น | ไฟล์ตัวอย่าง | หน้าที่ |
|------|-------------|---------|
| **presentation** | `login_screen.dart` | แสดง UI, รับ input จากผู้ใช้ |
| **data** | `auth_repository.dart` | คุยกับ Firebase Auth / Firestore โดยตรง |
| **domain** | `responder_logic.dart` | กฎ business เช่น state machine ของ incident |

> 💡 ถ้าอยากเปลี่ยนจาก Firebase ไปใช้ API อื่น → แก้แค่ `data/` ชั้นเดียว  
> ถ้าอยากเปลี่ยนหน้าตา → แก้แค่ `presentation/` ชั้นเดียว

---

## 3. Riverpod: ระบบ State Management

ทุก Provider อยู่รวมกันที่ `lib/core/providers.dart`

```dart
// ระดับ Infrastructure — ให้ Firebase instance
final firebaseAuthProvider = Provider<FirebaseAuth>(...);
final firestoreProvider    = Provider<FirebaseFirestore>(...);

// ระดับ Repository — ให้ object ที่ติดต่อ Firebase ได้
final authRepositoryProvider     = Provider<AuthRepository>(...);
final incidentRepositoryProvider = Provider<IncidentRepository>(...);
final chatRepositoryProvider     = Provider<ChatRepository>(...);

// ระดับ State — ข้อมูลที่ UI ใช้จริง
final authStateProvider    = StreamProvider<User?>(...);      // สถานะ login
final currentUserProvider  = StreamProvider<Map?>(...);       // ข้อมูล user จาก Firestore
final themeModeProvider    = StateProvider<ThemeMode>(...);   // Dark/Light mode

// ระดับ Data Stream — ดึงข้อมูลตาม uid
final myIncidentsStreamProvider       = StreamProvider.family<QuerySnapshot, String>(...);
final assignedToMeIncidentsStreamProvider = StreamProvider.family<QuerySnapshot, String>(...);
```

### วิธีที่ Screen ใช้ Provider

```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch = subscribe, rebuild อัตโนมัติเมื่อ data เปลี่ยน
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) => Text('สวัสดี ${user?['firstName']}'),
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Text('เกิดข้อผิดพลาด'),
    );
  }
}
```

---

## 4. Role System และ Navigation Flow

```
app เปิด
   │
   ▼
Firebase.initializeApp()
   │
   ▼
authStateProvider.watch(user)
   │
   ├── user == null ──▶ _AuthGate ──▶ Splash (2.2 วินาที)
   │                         │
   │                         ├── ยังไม่เคยเปิดแอป ──▶ OnboardingScreen
   │                         └── เคยเปิดแล้ว ──────▶ LoginScreen
   │
   └── user != null ──▶ SessionTimeoutWrapper
                              │
                              ▼
                         RoleRedirect
                         (อ่าน role จาก Firestore)
                              │
                    ┌─────────┼──────────┬──────────┐
                    ▼         ▼          ▼          ▼
               HomeScreen  Dispatcher  Responder  Admin
               (user)      Screen      Dashboard  Dashboard
```

---

## 5. Incident State Machine

เหตุการณ์แต่ละอันมี 2 ชั้น status:

### `status` — สถานะหลัก (3 ค่า)
```
NEW ──▶ IN_PROGRESS ──▶ RESOLVED
 │                          
 └──▶ CANCELLED (ได้จากทุก status ยกเว้น RESOLVED)
```

### `timelineStatus` — สถานะย่อยสำหรับ Responder (5 ค่า)
```
REPORTED ──▶ ACCEPTED ──▶ EN_ROUTE ──▶ ARRIVED ──▶ RESOLVED
```

กฎการ transition อยู่ใน `features/incident/domain/responder_logic.dart`  
การ transition ใช้ **Firestore Transaction** เพื่อป้องกัน race condition

---

## 6. โครงสร้างข้อมูลใน Firestore

### Collection: `users/{uid}`
```
uid (= Firebase Auth UID)
├── studentId       : String   — รหัสนักศึกษา เช่น "B6512345"
├── firstName       : String
├── lastName        : String
├── phoneNumber     : String
├── email           : String   — "{studentId}@campus.local"
├── role            : String   — "user" | "dispatcher" | "responder" | "admin"
├── department      : String?  — หน่วยงานของ responder
├── fcmToken        : String?  — token สำหรับส่ง push notification
├── volunteerPoints : int      — คะแนนสะสม
├── lastLocation    : Map?     — { lat, lng, updatedAt } (responder เท่านั้น)
├── createdAt       : Timestamp
└── updatedAt       : Timestamp
```

### Collection: `incidents/{incidentId}`
```
incidentId (auto-generated)
├── title           : String
├── description     : String
├── type            : String   — "accident"|"facility"|"assistance"|"security"|"medical"
├── priority        : String   — "CRITICAL"|"HIGH"|"MEDIUM"|"LOW"
├── status          : String   — "NEW"|"IN_PROGRESS"|"RESOLVED"|"CANCELLED"
├── timelineStatus  : String?  — "REPORTED"|"ACCEPTED"|"EN_ROUTE"|"ARRIVED"|"RESOLVED"
├── reporterId      : String   — uid ของผู้แจ้งเหตุ
├── reporterName    : String
├── responderId     : String?  — uid ของ responder ที่รับงาน
├── responderName   : String?
├── dispatcherId    : String?  — uid ของ dispatcher ที่มอบหมาย
├── department      : String?  — หน่วยงานที่รับผิดชอบ
├── latitude        : double?
├── longitude       : double?
├── imageUrls       : List<String>  — URL รูปจาก Firebase Storage
├── cancelReason    : String?
├── lastMessageAt   : Timestamp?   — สำหรับระบบ chat unread
├── lastMessageSenderId : String?
├── lastReadBy      : Map<uid, Timestamp>  — ใครอ่านล่าสุดเมื่อไหร่
├── createdAt       : Timestamp
├── updatedAt       : Timestamp
└── resolvedAt      : Timestamp?

  subcollection: messages/{messageId}   ← แชทในเหตุ
  subcollection: logs/{logId}           ← Audit Log ทุก action
```

---

## 7. ระบบ Notification

Push Notification ส่งใน 2 กรณีหลัก:

| เหตุการณ์ | ส่งถึงใคร | Channel |
|-----------|-----------|---------|
| มีเหตุใหม่ | Dispatcher ทุกคน | `urgent_incidents` |
| มอบหมายงาน | Responder ที่ได้รับ | `urgent_incidents` |
| สถานะเปลี่ยน | ผู้แจ้งเหตุ | `status_updates` |

บน **Web** ใช้ `WebNotificationWatcher` (wrapper widget) แทน FCM เพราะ service worker ทำงานต่างกัน

---

## 8. ฟีเจอร์พิเศษที่น่าสนใจ

### F5: Smart Responder Suggestion
เมื่อ Dispatcher จะมอบหมายงาน ระบบคำนวณ **Score** ให้แต่ละ Responder:
- `+3` ถ้า department ตรงกับประเภทเหตุ
- `+2` ถ้า active cases < 2 คน (ไม่ยุ่งมาก)
- `+1` ถ้าระยะห่างจากจุดเกิดเหตุ < 1 km

ใช้ **Haversine Formula** คำนวณระยะทางจาก GPS coordinates

### F6: Real-time Location Tracking
Responder อัปเดต GPS location ลง Firestore เรื่อยๆ  
Dispatcher เห็น marker ทุกคนบนแผนที่แบบ real-time ผ่าน Stream

### Audit Log (#29)
ทุก action บน incident (assign, status change, cancel) จะถูกบันทึกลง subcollection `logs` อัตโนมัติ

### Rate Limiting (#4)
ก่อนแจ้งเหตุ ระบบนับว่าผู้ใช้แจ้งเหตุไปกี่ครั้งใน duration ที่กำหนด ป้องกันการ spam

### Reset Password ผ่าน Cloud Functions
ไม่ได้ใช้ Firebase Email Reset แบบปกติ — แต่ยืนยันตัวตนด้วยรหัสนักศึกษา + เบอร์โทรศัพท์ แล้วเรียก Cloud Function `resetPasswordByPhone` โดยตรง

---

*อ่านต่อที่ [Implementation_Plan.md](./Implementation_Plan.md) สำหรับรายละเอียดโค้ดแต่ละส่วน*
