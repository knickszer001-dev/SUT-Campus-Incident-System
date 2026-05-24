import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../core/web_notification.dart' as web_noti;

/// F10: Sound Alert Service สำหรับ Dispatcher
/// v2: รองรับ Web ด้วย — ใช้ audioplayers (รองรับ HTML5 Audio) + Web Audio API fallback
class SoundAlertService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isInitialized = false;

  /// เริ่มต้น — ตั้งค่า volume (รองรับทั้ง Web + Mobile)
  static Future<void> initialize() async {
    try {
      await _player.setVolume(0.8);
      _isInitialized = true;
      debugPrint('[SoundAlert] initialized (kIsWeb=$kIsWeb)');
    } catch (e) {
      debugPrint('[SoundAlert] init error: $e');
      // บน Web ถ้า audioplayers init ไม่ได้ก็ยัง fallback ได้
      if (kIsWeb) _isInitialized = true;
    }
  }

  /// เล่นเสียงแจ้งเตือน
  static Future<void> playAlert() async {
    if (!_isInitialized) return;
    try {
      // ลองเล่นจาก asset ก่อน
      await _player.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      debugPrint('[SoundAlert] play error: $e');
      if (kIsWeb) {
        // Web fallback: ใช้ Web Audio API โดยตรง
        try {
          web_noti.playWebAlertSound();
        } catch (_) {}
      } else {
        // Mobile fallback: เล่นจาก URL
        try {
          await _player.play(
            UrlSource('https://actions.google.com/sounds/v1/alarms/beep_short.ogg'),
          );
        } catch (_) {}
      }
    }
  }

  /// หยุดเสียง
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// ปล่อย resource
  static Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
