# Code Guide For Team

เอกสารนี้ช่วยให้เพื่อนเปิดโค้ดแล้วรู้ว่าควรดูไฟล์ไหนก่อน โดยไม่ต้องอ่านทั้งโปรเจกต์

## 1. เริ่มที่จุดเปิดแอป

ดูไฟล์ `lib/main.dart`

สิ่งที่ต้องเข้าใจ:

- แอปเริ่มด้วย `main()`
- เรียก `Firebase.initializeApp()`
- ตั้งค่า NotificationService
- ตั้งค่า Remote Config
- ครอบแอปด้วย `ProviderScope` ของ Riverpod
- ถ้าผู้ใช้ยังไม่ login จะไปหน้า onboarding/login
- ถ้า login แล้วจะไป `RoleRedirect`

อธิบายง่าย ๆ:

"ไฟล์ main.dart คือประตูหน้าแอป ทำหน้าที่เปิด Firebase ตั้งค่าระบบสำคัญ แล้วส่งผู้ใช้ไปหน้าที่ถูกต้อง"

## 2. ดูว่าผู้ใช้ไปหน้าไหนตาม role

ดูไฟล์ `lib/features/auth/presentation/role_redirect.dart`

สิ่งที่ต้องเข้าใจ:

- อ่านข้อมูลผู้ใช้จาก Firebase Auth
- ไปดูเอกสารผู้ใช้ใน `users`
- อ่าน field `role`
- ถ้า role เป็น `user` ไป `HomeScreen`
- ถ้า role เป็น `dispatcher` ไป `DispatcherScreen`
- ถ้า role เป็น `responder` ไป `ResponderDashboard`
- ถ้า role เป็น `admin` ไป `AdminDashboard`

อธิบายง่าย ๆ:

"หลัง login ระบบไม่ได้ส่งทุกคนไปหน้าเดียวกัน แต่เช็ค role ก่อน แล้วเปิดหน้าตามสิทธิ์"

## 3. ดูโครงสร้างข้อมูล incident

ดูไฟล์ `lib/models/incident_model.dart`

field สำคัญ:

- `title`: ชื่อเหตุ
- `description`: รายละเอียด
- `type`: ประเภทเหตุ เช่น accident, security, medical
- `priority`: ความเร่งด่วน เช่น LOW, MEDIUM, HIGH, CRITICAL
- `status`: สถานะหลัก เช่น NEW, IN_PROGRESS, RESOLVED
- `timelineStatus`: สถานะย่อย เช่น REPORTED, ACCEPTED, EN_ROUTE, ARRIVED, RESOLVED
- `reporterId`: คนแจ้งเหตุ
- `responderId`: เจ้าหน้าที่ที่รับผิดชอบ
- `latitude`, `longitude`: พิกัด
- `imageUrls`: รูปประกอบ

อธิบายง่าย ๆ:

"Incident คือกล่องข้อมูลของหนึ่งเหตุการณ์ มีทั้งรายละเอียด พิกัด รูป คนแจ้ง คนรับผิดชอบ และสถานะ"

## 4. ดูการสร้าง/อัปเดตเหตุ

ดูไฟล์ `lib/features/incident/data/incident_repository.dart`

ฟังก์ชันที่ควรรู้:

- `submitIncident`: บันทึกเหตุใหม่ลง Firestore และแจ้ง dispatcher
- `assignResponder`: dispatcher มอบหมายเคสให้ responder
- `updateIncidentStatus`: เปลี่ยนสถานะหลักของเคส
- `updateTimelineStatus`: เปลี่ยนสถานะย่อย เช่น กำลังเดินทาง/ถึงที่เกิดเหตุ
- `cancelIncident`: ยกเลิกเคส
- `addAuditLog`: เก็บประวัติว่าใครทำอะไรกับเคส
- `getIncidentsStream`: ดึงข้อมูลเหตุแบบ real-time

อธิบายง่าย ๆ:

"Repository เป็นตัวกลางคุยกับฐานข้อมูล หน้าจอไม่เขียน Firestore ตรง ๆ แต่เรียกผ่าน repository เพื่อให้ logic อยู่เป็นที่"

## 5. ดูระบบแจ้งเตือน

ดูไฟล์:

- `lib/features/notification/notification_service.dart`
- `functions/index.js`

สิ่งที่ต้องเข้าใจ:

- แอปเก็บ FCM token ของผู้ใช้
- เมื่อเกิดเหตุใหม่ ระบบส่งแจ้งเตือนไปยัง dispatcher
- เมื่อมอบหมายงาน ระบบส่งแจ้งเตือนไป responder
- เมื่อสถานะเปลี่ยน ระบบส่งแจ้งเตือนไป reporter
- Cloud Functions ใช้ส่ง notification ไปยัง user/role ที่กำหนด

อธิบายง่าย ๆ:

"Notification คือระบบสะกิดคนที่เกี่ยวข้องทันที ไม่ต้องคอยเปิดแอปดูเองตลอด"

## 6. ดู security/config

ไฟล์ที่เกี่ยวข้อง:

- `firestore.rules`: กฎว่าใครอ่าน/เขียนข้อมูลอะไรได้
- `storage.rules`: กฎการเข้าถึงไฟล์รูป
- `firebase.json`: config ของ Firebase hosting/functions
- `firestore.indexes.json`: index สำหรับ query ที่ซับซ้อน

อธิบายง่าย ๆ:

"นอกจากโค้ดหน้าจอ ยังมี rules ที่ป้องกันไม่ให้ user ทั่วไปแก้ role หรืออ่านข้อมูลที่ไม่ควรเห็น"

