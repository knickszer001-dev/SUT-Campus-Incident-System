/// Web Notification Helper — Web Implementation
/// ใช้ Browser Notification API, Vibration API, และ Web Audio
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as html;

/// ขอ permission สำหรับ Browser Notifications
Future<void> requestBrowserNotificationPermission() async {
  try {
    final permission = html.Notification.permission;
    if (permission == 'default') {
      await html.Notification.requestPermission().toDart;
    }
  } catch (e) {
    // Browser อาจไม่รองรับ Notification API
  }
}

/// แสดง Browser Notification (ทำงานแม้ tab ไม่ active)
void showBrowserNotification(String title, String body) {
  try {
    final permission = html.Notification.permission;
    if (permission == 'granted') {
      final options = html.NotificationOptions(
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        requireInteraction: true,
      );
      html.Notification(title, options);
    }
  } catch (e) {
    // Browser อาจไม่รองรับ
  }
}

/// สั่น device ผ่าน Vibration API (รองรับ mobile browser)
void vibrateDevice([List<int>? pattern]) {
  try {
    final p = pattern ?? [200, 100, 200, 100, 200];
    final jsPattern = p.map((e) => e.toJS).toList().toJS;
    html.window.navigator.vibrate(jsPattern);
  } catch (e) {
    // Browser อาจไม่รองรับ Vibration API
  }
}

/// เล่นเสียงแจ้งเตือน 1 ติ๊ด (สำหรับแชท)
void playWebAlertSound() {
  _playBeeps(1);
}

/// เล่นเสียงแจ้งเตือนหลายติ๊ด (สำหรับเหตุด่วน)
void playWebAlertSoundMultiple(int beeps) {
  _playBeeps(beeps);
}

/// เล่นเสียง beep ตามจำนวน beeps ที่ระบุ
void _playBeeps(int beeps) {
  try {
    int played = 0;
    void playOnce() {
      if (played >= beeps) return;
      final audio = html.HTMLAudioElement();
      audio.src = 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg';
      audio.volume = 0.8;
      audio.play().toDart.then((_) {
        played++;
        if (played < beeps) {
          // รอ 400ms แล้วเล่นติ๊ดถัดไป
          Timer(const Duration(milliseconds: 400), playOnce);
        }
      }).catchError((_) {
        // Fallback: ลองใช้เสียงจาก assets ท้องถิ่นหาก URL ภายนอกเข้าถึงไม่ได้
        try {
          final fallbackAudio = html.HTMLAudioElement();
          fallbackAudio.src = 'assets/assets/sounds/alert.mp3';
          fallbackAudio.volume = 0.8;
          fallbackAudio.play().toDart.then((_) {
            played++;
            if (played < beeps) {
              Timer(const Duration(milliseconds: 400), playOnce);
            }
          }).catchError((_) {
            // เส้นทางสำรองตัวที่สอง (เผื่อการแมพพาธต่างกัน)
            try {
              final fallbackAudio2 = html.HTMLAudioElement();
              fallbackAudio2.src = 'assets/sounds/alert.mp3';
              fallbackAudio2.volume = 0.8;
              fallbackAudio2.play().toDart.then((_) {
                played++;
                if (played < beeps) {
                  Timer(const Duration(milliseconds: 400), playOnce);
                }
              }).catchError((_) => null);
            } catch (_) {}
            return null;
          });
        } catch (_) {}
        return null;
      });
    }
    playOnce();
  } catch (e) {
    // เล่นไม่ได้ก็ไม่เป็นไร
  }
}
