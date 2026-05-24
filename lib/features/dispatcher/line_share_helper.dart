import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/incident_model.dart';

/// LINE Share Helper — F4
/// สร้าง template ข้อความแจ้งเหตุ + เปิด LINE ส่งข้อความ
class LineShareHelper {

  /// สร้างข้อความ template สำหรับแชร์
  static String buildMessage(Incident incident, {String? reporterPhone}) {
    return '''🚨 แจ้งเหตุฉุกเฉิน
━━━━━━━━━━━━━━━━
📌 เหตุ: ${incident.title}
📝 รายละเอียด: ${incident.description}
🏷️ ประเภท: ${incident.typeText}
🔴 ระดับ: ${incident.priorityText}
👤 ผู้แจ้ง: ${incident.reporterName ?? '-'}
📞 เบอร์ติดต่อ: ${reporterPhone ?? '-'}
⏰ เวลาแจ้ง: ${incident.formattedTime}

📍 ตำแหน่ง:
https://www.google.com/maps?q=${incident.latitude},${incident.longitude}

━━━━━━━━━━━━━━━━
ระบบแจ้งเหตุมหาวิทยาลัย''';
  }

  /// เปิด LINE แชร์ข้อความ
  /// ถ้าเป็น PC Desktop (Windows/Mac/Linux) จะคัดลอกลง Clipboard และให้เปิดแอพ LINE ไปวางเอง
  /// เนื่องจาก LINE PC ไม่รองรับ URL Scheme สำหรับใส่ข้อความ
  static Future<bool> shareToLine(BuildContext context, Incident incident, {String? reporterPhone}) async {
    final message = buildMessage(incident, reporterPhone: reporterPhone);
    final encoded = Uri.encodeComponent(message);

    final isDesktop = (defaultTargetPlatform == TargetPlatform.windows || 
                       defaultTargetPlatform == TargetPlatform.macOS || 
                       defaultTargetPlatform == TargetPlatform.linux);

    if (isDesktop) {
      // สำหรับ Desktop PC
      await Clipboard.setData(ClipboardData(text: message));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 คัดลอกข้อความแล้ว! ระบบกำลังเปิดโปรแกรม LINE ให้คุณกดวาง (Ctrl+V) เพื่อส่งข้อความได้เลย"),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.teal,
          ),
        );
      }
      
      // ลองเปิดแอพ LINE
      final appUri = Uri.parse('line://');
      try {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      
      return true; 
    }

    // สำหรับ Mobile (Android/iOS)
    final appUri = Uri.parse('line://msg/text/$encoded');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // Fallback: ใช้ Universal Link
    final webUri = Uri.parse('https://line.me/R/msg/text/?$encoded');
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // Fallback: เปิด Google Maps link ธรรมดา
    final mapUri = Uri.parse(
      'https://www.google.com/maps?q=${incident.latitude},${incident.longitude}'
    );
    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    return false;
  }
}
