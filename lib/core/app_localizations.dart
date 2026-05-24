import 'package:flutter/material.dart';

/// F34: Multi-language (i18n) — โครงสร้าง localization
/// รองรับ Thai (th) และ English (en)
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('th'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// รองรับภาษา
  static const List<Locale> supportedLocales = [
    Locale('th'),
    Locale('en'),
  ];

  /// ตาราง string ทั้งหมด
  static final Map<String, Map<String, String>> _localizedValues = {
    'th': {
      // General
      'app_name': 'ระบบแจ้งเหตุมหาวิทยาลัย',
      'ok': 'ตกลง',
      'cancel': 'ยกเลิก',
      'confirm': 'ยืนยัน',
      'save': 'บันทึก',
      'delete': 'ลบ',
      'edit': 'แก้ไข',
      'close': 'ปิด',
      'retry': 'ลองใหม่',
      'loading': 'กำลังโหลด...',
      'error': 'เกิดข้อผิดพลาด',
      'success': 'สำเร็จ',
      'no_data': 'ไม่มีข้อมูล',

      // Auth
      'login': 'เข้าสู่ระบบ',
      'logout': 'ออกจากระบบ',
      'register': 'สมัครสมาชิก',
      'student_id': 'รหัสนักศึกษา/บุคลากร',
      'password': 'รหัสผ่าน',
      'forgot_password': 'ลืมรหัสผ่าน?',
      'reset_password': 'รีเซ็ตรหัสผ่าน',

      // Home
      'greeting': 'สวัสดีครับ / ค่ะ',
      'main_menu': 'เมนูหลัก',
      'report_incident': 'แจ้งเหตุ',
      'report_subtitle': 'แจ้งเหตุฉุกเฉินพร้อม GPS',
      'my_incidents': 'เหตุของฉัน',
      'my_incidents_subtitle': 'ติดตามสถานะเหตุที่แจ้ง',
      'safety_tips': 'คำแนะนำความปลอดภัย',
      'announcements': 'ประกาศจากระบบ',
      'sos_hold': 'กดค้าง 2 วินาที เพื่อ SOS',
      'emergency_notice': 'หากเกิดเหตุฉุกเฉินร้ายแรง กรุณาโทร 191 / 1669 ด้วย',

      // Incident
      'incident_title': 'หัวข้อ',
      'incident_description': 'รายละเอียด',
      'incident_type': 'ประเภท',
      'incident_priority': 'ระดับความเร่งด่วน',
      'submit': 'ส่งแจ้งเหตุ',
      'status_new': 'เหตุใหม่',
      'status_in_progress': 'กำลังดำเนินการ',
      'status_resolved': 'เสร็จสิ้น',
      'status_cancelled': 'ยกเลิก',

      // Chat
      'chat': 'แชท',
      'type_message': 'พิมพ์ข้อความ...',
      'no_messages': 'ยังไม่มีข้อความ — เริ่มพิมพ์เลย!',
      'read_only_mode': 'โหมดดูอย่างเดียว — ไม่สามารถส่งข้อความได้',

      // Dispatcher
      'dispatcher_title': 'ศูนย์รับเหตุ',
      'incident_list': 'รายการเหตุ',
      'assign': 'มอบหมายงาน',
      'suggest_tab': 'แนะนำ',
      'all_tab': 'ทั้งหมด',
      'view_chat': 'ดูแชท',
      'merge_cases': 'รวมเคส',

      // Responder
      'responder_title': 'ผู้ตอบสนอง',
      'assigned_incidents': 'เหตุที่ได้รับ',
      'completed': 'เสร็จสิ้น',
      'navigate': 'นำทาง',
      'mark_resolved': 'เสร็จสิ้น',

      // Profile
      'profile': 'โปรไฟล์',
      'dark_mode': 'โหมดมืด',

      // Rate Limit
      'rate_limit_warning': 'คุณแจ้งเหตุบ่อยเกินไป กรุณารอสักครู่',
    },

    'en': {
      // General
      'app_name': 'Campus Incident System',
      'ok': 'OK',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'retry': 'Retry',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'no_data': 'No data',

      // Auth
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'student_id': 'Student/Staff ID',
      'password': 'Password',
      'forgot_password': 'Forgot Password?',
      'reset_password': 'Reset Password',

      // Home
      'greeting': 'Hello',
      'main_menu': 'Main Menu',
      'report_incident': 'Report Incident',
      'report_subtitle': 'Report emergency with GPS',
      'my_incidents': 'My Incidents',
      'my_incidents_subtitle': 'Track reported incidents',
      'safety_tips': 'Safety Tips',
      'announcements': 'Announcements',
      'sos_hold': 'Hold 2 seconds for SOS',
      'emergency_notice': 'For serious emergencies, please also call 191 / 1669',

      // Incident
      'incident_title': 'Title',
      'incident_description': 'Description',
      'incident_type': 'Type',
      'incident_priority': 'Priority',
      'submit': 'Submit Report',
      'status_new': 'New',
      'status_in_progress': 'In Progress',
      'status_resolved': 'Resolved',
      'status_cancelled': 'Cancelled',

      // Chat
      'chat': 'Chat',
      'type_message': 'Type a message...',
      'no_messages': 'No messages yet — start typing!',
      'read_only_mode': 'Read-only mode — cannot send messages',

      // Dispatcher
      'dispatcher_title': 'Dispatch Center',
      'incident_list': 'Incident List',
      'assign': 'Assign',
      'suggest_tab': 'Suggested',
      'all_tab': 'All',
      'view_chat': 'View Chat',
      'merge_cases': 'Merge Cases',

      // Responder
      'responder_title': 'Responder',
      'assigned_incidents': 'Assigned Incidents',
      'completed': 'Completed',
      'navigate': 'Navigate',
      'mark_resolved': 'Mark Resolved',

      // Profile
      'profile': 'Profile',
      'dark_mode': 'Dark Mode',

      // Rate Limit
      'rate_limit_warning': 'Too many reports. Please wait.',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['th']?[key] ??
        key;
  }

  // Convenience getter
  String get appName => translate('app_name');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['th', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
