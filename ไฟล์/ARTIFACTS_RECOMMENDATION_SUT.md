# Artifacts Recommendation

ชุดไฟล์ที่ควรมีสำหรับส่งให้เพื่อนอ่านและใช้ประกอบการตอบคำถาม

## ควรมีแน่นอน

1. `README.md`
   - ใช้อธิบายภาพรวมโปรเจกต์ วิธีติดตั้ง วิธีรัน และฟีเจอร์หลัก

2. `ARCHITECTURE.md`
   - ใช้อธิบายโครงสร้างระบบ Flutter + Firebase + role workflow

3. `TEAM_BRIEF_SUT.md`
   - ให้เพื่อนอ่านเร็ว ๆ เพื่อเข้าใจภาพรวมและพูดไปในทางเดียวกัน

4. `CODE_GUIDE_FOR_TEAM.md`
   - บอกว่าไฟล์ไหนสำคัญ ดูอะไรก่อน และแต่ละไฟล์ทำหน้าที่อะไร

5. `QA_CHEATSHEET_SUT.md`
   - รวมคำถามที่อาจารย์น่าจะถาม พร้อมแนวคำตอบ

6. `PRESENTATION_SCRIPT_SUT.md`
   - สคริปต์ลำดับการพูดตอนนำเสนอ

## ควรเพิ่มถ้ามีเวลา

1. `DATABASE_SCHEMA.md`
   - อธิบาย collections เช่น `users`, `incidents`, `messages`, `logs`
   - อธิบาย field สำคัญและสิทธิ์การเข้าถึง

2. `USER_FLOW.md`
   - ทำ flow แยกตาม role: user, dispatcher, responder, admin

3. `TEST_CASES.md`
   - ลิสต์เคสทดสอบ เช่น สมัครสมาชิก แจ้งเหตุ มอบหมาย responder ปิดเคส ส่ง notification

4. `DEPLOYMENT.md`
   - วิธี deploy Firebase Hosting/Functions และสิ่งที่ต้องตั้งค่า

5. `KNOWN_LIMITATIONS.md`
   - ข้อจำกัดที่รู้ เช่น ต้องมี internet, notification ต้องขอ permission, map ต้องมี location permission

## วิธีแบ่งให้เพื่อน

- เพื่อนที่พูดภาพรวม: อ่าน `TEAM_BRIEF_SUT.md`
- เพื่อนที่พูด demo: อ่าน `PRESENTATION_SCRIPT_SUT.md`
- เพื่อนที่พูดโค้ด: อ่าน `CODE_GUIDE_FOR_TEAM.md`
- เพื่อนที่ตอบคำถาม: อ่าน `QA_CHEATSHEET_SUT.md`
- คนที่รับมือคำถามเชิงลึก: อ่าน `ARCHITECTURE.md` และ `README.md`

