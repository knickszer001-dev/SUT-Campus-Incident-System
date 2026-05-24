import 'package:flutter/material.dart';

/// #32: Safety Tips Screen — คำแนะนำความปลอดภัย
class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const List<Map<String, dynamic>> _tips = [
    {
      'icon': Icons.local_fire_department,
      'color': 0xFFE53935,
      'title': '🔥 เกิดเพลิงไหม้',
      'steps': [
        'กดปุ่ม SOS ในแอปทันที',
        'แจ้งเหตุ 191 / ดับเพลิง 199',
        'อพยพออกจากอาคารทางบันไดหนีไฟ',
        'อย่าใช้ลิฟต์',
        'ปิดจมูกด้วยผ้าชุบน้ำ ก้มต่ำหลีกเลี่ยงควัน',
        'ไปจุดรวมพลและรอเจ้าหน้าที่',
      ],
    },
    {
      'icon': Icons.water_drop,
      'color': 0xFF1E88E5,
      'title': '🌊 น้ำท่วม / น้ำหลาก',
      'steps': [
        'หลีกเลี่ยงการเดินหรือขับรถในน้ำ',
        'ขึ้นไปอยู่ที่สูง',
        'ตัดกระแสไฟฟ้าถ้าน้ำเริ่มเข้าบ้าน',
        'ติดตามข่าวสารจากหน่วยงาน',
        'เตรียมอาหารและน้ำดื่ม',
      ],
    },
    {
      'icon': Icons.bolt,
      'color': 0xFFFFC107,
      'title': '⚡ ไฟฟ้าดูด / ไฟรั่ว',
      'steps': [
        'อย่าสัมผัสผู้ประสบเหตุโดยตรง',
        'ตัดกระแสไฟที่เบรกเกอร์',
        'โทร 1669 เรียกรถพยาบาล',
        'ถ้าหยุดหายใจ ทำ CPR',
      ],
    },
    {
      'icon': Icons.car_crash,
      'color': 0xFFFF6F00,
      'title': '🚗 อุบัติเหตุจราจร',
      'steps': [
        'ตรวจสอบความปลอดภัย ไม่เข้าไปในจุดอันตราย',
        'โทร 1669 หรือ 191',
        'กดปุ่ม SOS ในแอป พร้อมส่ง GPS',
        'ปฐมพยาบาลเบื้องต้นถ้าทำได้',
        'ถ่ายรูปจุดเกิดเหตุเป็นหลักฐาน',
      ],
    },
    {
      'icon': Icons.medical_services,
      'color': 0xFFD32F2F,
      'title': '🏥 คนเจ็บ / หมดสติ',
      'steps': [
        'ตรวจสอบว่ายังหายใจหรือไม่',
        'โทร 1669 ทันที',
        'ถ้าหยุดหายใจ ทำ CPR',
        'อย่าเคลื่อนย้ายผู้บาดเจ็บ (ยกเว้นอันตราย)',
        'รอเจ้าหน้าที่มาถึง',
      ],
    },
    {
      'icon': Icons.warning,
      'color': 0xFF6D4C41,
      'title': '⚠️ สัตว์มีพิษ / สุนัขจรจัด',
      'steps': [
        'อย่าเข้าใกล้หรือยั่วยุ',
        'ถ้าถูกกัด ล้างแผลด้วยน้ำสบู่',
        'ไปพบแพทย์ทันที',
        'แจ้งเหตุผ่านแอปเพื่อให้เจ้าหน้าที่จัดการ',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛡️ คำแนะนำความปลอดภัย")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tips.length,
        itemBuilder: (context, index) {
          final tip = _tips[index];
          final color = Color(tip['color'] as int);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: Icon(tip['icon'] as IconData, color: Colors.white, size: 22),
              ),
              title: Text(
                tip['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (tip['steps'] as List<String>).asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
