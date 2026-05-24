import 'package:flutter/material.dart';

/// UI Helper Functions — จุดเดียวสำหรับ color/icon/text mapping
/// v2: ปรับ status mapping เหลือ 3 สถานะ + เพิ่ม isValidStudentId

class AppHelpers {

  // === StudentId Validation (v3: รองรับทุก format) ===

  /// ตรวจสอบรหัสนักศึกษา/บุคลากร: อย่างน้อย 3 ตัวอักษร ประกอบด้วยตัวอักษรหรือตัวเลข
  static bool isValidStudentId(String id) {
    if (id.length < 3) return false;
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);
  }

  // === Priority ===

  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'CRITICAL':
        return Colors.red.shade900;
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String getPriorityText(String priority) {
    switch (priority) {
      case 'CRITICAL':
        return '🔴 ฉุกเฉินมาก';
      case 'HIGH':
        return '🔴 เร่งด่วน';
      case 'MEDIUM':
        return '🟠 ปานกลาง';
      case 'LOW':
        return '🟢 ทั่วไป';
      default:
        return '-';
    }
  }

  // === Status (v2: 3 สถานะ) ===

  static Color getStatusColor(String status) {
    switch (status) {
      case 'NEW':
        return Colors.amber;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String getStatusText(String status) {
    switch (status) {
      case 'NEW':
        return 'เหตุใหม่';
      case 'IN_PROGRESS':
        return 'กำลังดำเนินการ';
      case 'RESOLVED':
        return 'เสร็จสิ้น';
      default:
        return status;
    }
  }

  // === Type ===

  static IconData getTypeIcon(String type) {
    switch (type) {
      case 'accident':
        return Icons.car_crash;
      case 'facility':
        return Icons.build;
      case 'assistance':
        return Icons.volunteer_activism;
      case 'security':
        return Icons.security;
      case 'medical':
        return Icons.local_hospital;
      default:
        return Icons.warning;
    }
  }

  static String getTypeText(String type) {
    switch (type) {
      case 'accident':
        return 'อุบัติเหตุ';
      case 'facility':
        return 'ปัญหาสาธารณูปโภค';
      case 'assistance':
        return 'ขอความช่วยเหลือ';
      case 'security':
        return 'ความปลอดภัย';
      case 'medical':
        return 'การแพทย์';
      default:
        return 'อื่นๆ';
    }
  }

  // === Priority Marker (Map) ===

  static Color getMarkerColor(String priority) {
    switch (priority) {
      case 'CRITICAL':
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.amber;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
