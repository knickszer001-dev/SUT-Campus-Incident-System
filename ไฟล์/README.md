# 📱 SUT Campus Incident System — Mobile User App

> ระบบแจ้งเหตุภายในมหาวิทยาลัยเทคโนโลยีสุรนารี (มทส.)  
> พัฒนาด้วย Flutter + Firebase | รองรับทั้ง Android, iOS และ Web

---

## 🎯 โปรเจกต์นี้คืออะไร?

แอปพลิเคชันมือถือ (และ Web) สำหรับบริหารจัดการเหตุฉุกเฉินภายใน มทส. ครบวงจร —  
ตั้งแต่การแจ้งเหตุโดยนักศึกษา ไปจนถึงการมอบหมายงานและติดตามผลโดยเจ้าหน้าที่

---

## 👥 Role ในระบบ

ระบบนี้มีผู้ใช้ **4 ประเภท** แต่ละประเภทเห็นหน้าจอที่ต่างกัน:

| Role | หน้าจอหลัก | หน้าที่ |
|------|-----------|---------|
| `user` | `HomeScreen` | นักศึกษา/บุคลากร — แจ้งเหตุ, ดูสถานะ, แชท |
| `dispatcher` | `DispatcherScreen` | เจ้าหน้าที่ศูนย์ — รับเรื่อง, มอบหมายงาน, ดูแผนที่ |
| `responder` | `ResponderDashboard` | เจ้าหน้าที่ภาคสนาม — รับงาน, อัปเดตสถานะ, นำทาง |
| `admin` | `AdminDashboard` | ผู้ดูแลระบบ — จัดการผู้ใช้, ดูสถิติ |

การ redirect เกิดขึ้นอัตโนมัติใน `RoleRedirect` ตามฟิลด์ `role` ใน Firestore

---

## 🛠️ Tech Stack

| ชั้น | เทคโนโลยี | เวอร์ชัน |
|------|-----------|---------|
| Framework | Flutter (Dart) | SDK ^3.10.1 |
| State Management | **Flutter Riverpod** | ^2.5.1 |
| Authentication | Firebase Auth | ^6.2.0 |
| Database | Cloud Firestore | ^6.1.3 |
| File Storage | Firebase Storage | ^13.1.0 |
| Push Notification | Firebase Messaging (FCM) | ^16.1.2 |
| Server-side Logic | Cloud Functions | ^6.2.0 |
| Crash Reporting | Firebase Crashlytics | ^5.0.8 |
| Remote Config | Firebase Remote Config | ^6.2.0 |
| Maps | Google Maps + Flutter Map | ^2.6.1 / ^7.0.2 |
| Charts | fl_chart | ^0.68.0 |
| Localization | flutter_localizations (ภาษาไทย) | built-in |

---

## 📂 โครงสร้างโปรเจกต์

```
lib/
├── main.dart                         # จุดเริ่มต้น: Firebase init, Riverpod, Splash, i18n
├── firebase_options.dart             # Auto-generated โดย FlutterFire CLI
│
├── core/                             # ของกลางที่ทุก feature ใช้ร่วมกัน
│   ├── providers.dart                # Riverpod Providers ทั้งหมด (Firebase, Repository)
│   ├── theme.dart                    # AppTheme: Light/Dark, สี primary orange
│   ├── constants.dart                # ค่าคงที่ต่างๆ
│   ├── helpers.dart                  # Utility functions
│   ├── app_localizations.dart        # ระบบภาษาไทย (i18n)
│   ├── remote_config_service.dart    # Firebase Remote Config
│   ├── session_timeout.dart          # จัดการ session หมดอายุ
│   ├── version_check.dart            # เช็ค app version
│   └── adaptive_map_widget.dart      # Map widget รองรับทั้ง Mobile/Web
│
├── models/                           # โครงสร้างข้อมูล
│   ├── incident_model.dart           # Incident (มี fromFirestore / toFirestore)
│   ├── user_model.dart               # User
│   └── chat_message_model.dart       # ChatMessage
│
└── features/                         # แบ่งตาม feature (Feature-based Architecture)
    ├── auth/
    │   ├── data/auth_repository.dart           # Login, Register, Reset Password
    │   └── presentation/
    │       ├── login_screen.dart
    │       ├── register_screen.dart
    │       └── role_redirect.dart              # ดึง role แล้ว route ไปหน้าที่ถูกต้อง
    ├── home/
    │   └── home_screen.dart                    # หน้าหลัก role: user
    ├── incident/
    │   ├── data/incident_repository.dart       # CRUD + Notification + Audit Log
    │   ├── domain/responder_logic.dart         # Business logic: state machine
    │   └── presentation/
    │       ├── choose_report_type_screen.dart
    │       ├── report_incident_screen.dart
    │       ├── incident_list_screen.dart
    │       └── incident_detail_screen.dart
    ├── dispatcher/
    │   ├── dispatcher_screen.dart
    │   ├── map_dashboard_screen.dart
    │   ├── incident_panel.dart
    │   ├── responders_panel.dart
    │   ├── resolved_incidents_panel.dart
    │   ├── dispatcher_stats_widget.dart
    │   ├── sound_alert_service.dart            # เสียงเตือนเมื่อมีเหตุใหม่
    │   └── line_share_helper.dart
    ├── responder/
    │   ├── responder_dashboard.dart
    │   └── navigator_screen.dart               # นำทางไปยังจุดเกิดเหตุ
    ├── chat/
    │   ├── data/
    │   │   ├── chat_repository.dart            # แชทในเหตุ (group)
    │   │   └── direct_chat_repository.dart     # แชทตรง (1:1)
    │   └── presentation/
    │       ├── chat_screen.dart
    │       ├── direct_chat_screen.dart
    │       └── chat_history_screen.dart
    ├── admin/
    │   ├── admin_dashboard.dart
    │   └── user_management_screen.dart
    ├── notification/
    │   ├── notification_service.dart           # FCM + Local Notification
    │   ├── notification_router.dart            # Deep link จาก notification
    │   └── web_notification_watcher.dart       # Notification บน Web
    ├── map/
    │   └── heatmap_screen.dart                 # Heatmap แสดงจุดเกิดเหตุ
    ├── announcement/
    │   └── announcement_screen.dart
    ├── profile/
    │   └── profile_screen.dart
    ├── safety/
    │   └── safety_tips_screen.dart
    └── onboarding/
        └── onboarding_screen.dart              # หน้าแนะนำสำหรับผู้ใช้ใหม่
```

---

## 🚀 วิธีรันโปรเจกต์

### ความต้องการเบื้องต้น
- Flutter SDK `>= 3.10.1`
- Firebase Project (พร้อม Firestore, Auth, Storage, Functions เปิดใช้งาน)
- `google-services.json` วางไว้ที่ `android/app/`

```bash
# 1. ติดตั้ง dependencies
flutter pub get

# 2. รันบน Android/iOS
flutter run

# 3. รันบน Web
flutter run -d chrome
```

> ⚠️ ต้องมีไฟล์ `lib/firebase_options.dart` ซึ่งสร้างจาก FlutterFire CLI  
> รันด้วย: `flutterfire configure`

---

## 📄 เอกสารเพิ่มเติม

- **[Architecture.md](./Architecture.md)** — สถาปัตยกรรมระบบ, Data Flow, Firestore Schema, Role System
- **[Implementation_Plan.md](./Implementation_Plan.md)** — รายละเอียดการ implement แต่ละ feature พร้อมโค้ดอธิบาย
