/// Roles ในระบบ
class AppRoles {
  static const String user = 'user';
  static const String dispatcher = 'dispatcher';
  static const String responder = 'responder';
  static const String admin = 'admin';
}

/// หน่วยงานที่รับเหตุ
class AppDepartments {
  static const String security = 'security';
  static const String rescue = 'rescue';
  static const String hospital = 'hospital';

  static const Map<String, String> labels = {
    security: '🛡️ ยามมหาวิทยาลัย',
    rescue: '🚑 จิตอาสากู้ภัย',
    hospital: '🏥 โรงพยาบาลมหาวิทยาลัย',
  };

  static String getLabel(String? dept) => labels[dept] ?? '-';
}

/// สถานะเหตุการณ์ — v2: ลดเหลือ 3 สถานะ
class IncidentStatus {
  static const String newCase = 'NEW';
  static const String inProgress = 'IN_PROGRESS';
  static const String resolved = 'RESOLVED';
}

/// ประเภทเหตุการณ์
class IncidentType {
  static const String accident = 'accident';
  static const String facility = 'facility';
  static const String assistance = 'assistance';
  static const String security = 'security';
  static const String medical = 'medical';
}

/// ระดับความเร่งด่วน
class IncidentPriority {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String critical = 'CRITICAL';
}
