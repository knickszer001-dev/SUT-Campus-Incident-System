# QA Cheatsheet: SUT Campus Incident System

## ถาม: แอปนี้ทำอะไร

ตอบ: เป็นระบบแจ้งเหตุและประสานงานเหตุฉุกเฉินในมหาวิทยาลัย ผู้ใช้แจ้งเหตุ Dispatcher รับเรื่องและมอบหมาย Responder จากนั้น Responder อัปเดตสถานะจนปิดเคส

## ถาม: ใช้เทคโนโลยีอะไร

ตอบ: ใช้ Flutter/Dart ทำแอป และใช้ Firebase เป็น backend ได้แก่ Auth, Firestore, Storage, Cloud Messaging, Cloud Functions และ Remote Config

## ถาม: ทำไมใช้ Firebase

ตอบ: เพราะต้องการ real-time database, authentication, push notification และ backend function โดยไม่ต้องสร้าง server เองทั้งหมด ทำให้เหมาะกับโปรเจกต์ที่ต้องการพัฒนาเร็วและมีระบบครบ

## ถาม: ข้อมูล incident เก็บอะไรบ้าง

ตอบ: เก็บชื่อเหตุ รายละเอียด ประเภท ความเร่งด่วน สถานะ พิกัด รูปภาพ ผู้แจ้ง ผู้รับผิดชอบ และเวลาสร้าง/อัปเดต/ปิดเคส

## ถาม: status กับ timelineStatus ต่างกันยังไง

ตอบ: `status` คือสถานะหลักของเคส เช่น NEW, IN_PROGRESS, RESOLVED ส่วน `timelineStatus` คือขั้นตอนย่อย เช่น REPORTED, ACCEPTED, EN_ROUTE, ARRIVED, RESOLVED

## ถาม: ผู้ใช้แต่ละ role เข้าไปหน้าไหน

ตอบ: หลัง login ระบบอ่าน role จาก Firestore ถ้าเป็น user ไป HomeScreen ถ้า dispatcher ไป DispatcherScreen ถ้า responder ไป ResponderDashboard ถ้า admin ไป AdminDashboard

## ถาม: Dispatcher ทำอะไร

ตอบ: ดูเหตุใหม่แบบ real-time ตรวจรายละเอียดและพิกัด จากนั้นมอบหมาย responder ที่เหมาะสมให้รับเคส

## ถาม: Responder ทำอะไร

ตอบ: รับเคสที่ถูกมอบหมาย ดูรายละเอียด/พิกัด ติดต่อผู้แจ้ง อัปเดตสถานะการเดินทางและการช่วยเหลือ แล้วปิดเคสเมื่อจบงาน

## ถาม: Notification ทำงานยังไง

ตอบ: แอปเก็บ FCM token ของผู้ใช้ไว้ เมื่อมีเหตุใหม่หรือสถานะเปลี่ยน ระบบเรียก Cloud Functions เพื่อส่ง push notification ไปยัง role หรือ user ที่เกี่ยวข้อง

## ถาม: ถ้าอาจารย์ถามว่าทำไมต้องแยก repository

ตอบ: เพื่อให้หน้าจอไม่ต้องเขียน logic ติดต่อฐานข้อมูลโดยตรง Repository เป็นตัวกลางที่รวมการอ่าน/เขียน Firestore และ business logic สำคัญไว้ในที่เดียว ทำให้ดูแลง่ายกว่า

## ถาม: จุดเด่นของระบบคืออะไร

ตอบ: จุดเด่นคือ role-based workflow, real-time incident dashboard, push notification, แผนที่พิกัดเหตุ, timeline การช่วยเหลือ, audit log และรองรับหลายแพลตฟอร์มด้วย Flutter

## ถาม: ถ้าจะพัฒนาต่อควรเพิ่มอะไร

ตอบ: เพิ่มระบบคัดเลือก responder อัตโนมัติจากระยะทาง/ความพร้อม, dashboard สถิติ SLA, offline mode, รายงาน PDF, และระบบทดสอบอัตโนมัติที่ครอบคลุม flow สำคัญ

