/// v2: ปรับ IncidentState เหลือ 3 ค่า — newCase, inProgress, resolved
/// ลบ assigned, onRoute, onSite, cancelled ออก
enum IncidentState {
  newCase('NEW'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED');

  final String code;
  const IncidentState(this.code);

  static IncidentState fromCode(String code) {
    final normalized = code.trim().toUpperCase();
    return IncidentState.values.firstWhere(
      (s) => s.code == normalized,
      orElse: () => IncidentState.newCase, // assume NEW if unknown
    );
  }
}

class ResponderLogic {
  /// v2: ตรวจสอบว่าสามารถเปลี่ยนสถานะจาก currentStatus ไป nextStatus ได้หรือไม่
  /// Transition ที่อนุญาต:
  ///   NEW → IN_PROGRESS  (เมื่อ Dispatcher กด Assign)
  ///   IN_PROGRESS → RESOLVED  (เมื่อ Responder กดเสร็จสิ้น)
  /// ไม่มี reverse transition
  static bool canTransition(String currentStatus, String nextStatus) {
    final current = IncidentState.fromCode(currentStatus);
    final next = IncidentState.fromCode(nextStatus);

    // ไม่สามารถเปลี่ยนจาก RESOLVED ไปไหนได้อีก
    if (current == IncidentState.resolved) {
      return false;
    }

    // NEW → IN_PROGRESS
    if (current == IncidentState.newCase && next == IncidentState.inProgress) {
      return true;
    }

    // IN_PROGRESS → RESOLVED
    if (current == IncidentState.inProgress && next == IncidentState.resolved) {
      return true;
    }

    return false;
  }

  /// v2: คืนค่า status ถัดไปที่สามารถเปลี่ยนได้ หรือ null ถ้าไม่มี
  static String? getNextStatus(String currentStatus) {
    final current = IncidentState.fromCode(currentStatus);

    switch (current) {
      case IncidentState.newCase:
        return IncidentState.inProgress.code;
      case IncidentState.inProgress:
        return IncidentState.resolved.code;
      case IncidentState.resolved:
        return null;
    }
  }
}
