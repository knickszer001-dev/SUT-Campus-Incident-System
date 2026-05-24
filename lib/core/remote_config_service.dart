import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// F35: Remote Config Service — ดึง config จาก Firebase Remote Config
/// ใช้ควบคุม feature flags, ข้อความ, และค่าต่างๆ โดยไม่ต้อง deploy ใหม่
class RemoteConfigService {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  static bool _isInitialized = false;

  /// Initialize + set defaults + fetch
  static Future<void> initialize() async {
    if (kIsWeb) return; // ข้าม Web
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Default values
      await _remoteConfig.setDefaults({
        'max_incidents_per_hour': 5,
        'sos_enabled': true,
        'maintenance_mode': false,
        'maintenance_message': 'ระบบอยู่ระหว่างปรับปรุง กรุณาลองใหม่ภายหลัง',
        'sound_alert_enabled': true,
        'location_update_interval_seconds': 30,
        'max_image_upload_count': 3,
        'announcement_banner': '',
      });

      await _remoteConfig.fetchAndActivate();
      _isInitialized = true;
      debugPrint('[RemoteConfig] Initialized successfully');
    } catch (e) {
      debugPrint('[RemoteConfig] Init error: $e');
    }
  }

  /// ดึงค่า int
  static int getInt(String key) {
    if (!_isInitialized) return _getDefaultInt(key);
    return _remoteConfig.getInt(key);
  }

  /// ดึงค่า bool
  static bool getBool(String key) {
    if (!_isInitialized) return _getDefaultBool(key);
    return _remoteConfig.getBool(key);
  }

  /// ดึงค่า String
  static String getString(String key) {
    if (!_isInitialized) return '';
    return _remoteConfig.getString(key);
  }

  // Default fallbacks
  static int _getDefaultInt(String key) {
    switch (key) {
      case 'max_incidents_per_hour': return 5;
      case 'location_update_interval_seconds': return 30;
      case 'max_image_upload_count': return 3;
      default: return 0;
    }
  }

  static bool _getDefaultBool(String key) {
    switch (key) {
      case 'sos_enabled': return true;
      case 'sound_alert_enabled': return true;
      case 'maintenance_mode': return false;
      default: return false;
    }
  }

  /// Convenience getters
  static int get maxIncidentsPerHour => getInt('max_incidents_per_hour');
  static bool get sosEnabled => getBool('sos_enabled');
  static bool get maintenanceMode => getBool('maintenance_mode');
  static String get maintenanceMessage => getString('maintenance_message');
  static bool get soundAlertEnabled => getBool('sound_alert_enabled');
  static int get locationUpdateIntervalSeconds => getInt('location_update_interval_seconds');
  static int get maxImageUploadCount => getInt('max_image_upload_count');
  static String get announcementBanner => getString('announcement_banner');
}
