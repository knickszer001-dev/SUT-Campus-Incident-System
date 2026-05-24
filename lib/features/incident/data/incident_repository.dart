import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notification/notification_service.dart';
import 'dart:math';
import '../domain/responder_logic.dart';

/// IncidentRepository — v4: เพิ่ม F5 Suggestion Assignment, F6 Location Tracking
class IncidentRepository {
  final FirebaseFirestore _firestore;

  IncidentRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  /// ส่งเหตุใหม่
  Future<String> submitIncident(Map<String, dynamic> data) async {
    final docRef = await _firestore.collection("incidents").add(data);
    
    // Trigger push notification to dispatchers
    try {
      final title = data['title'] as String? ?? 'เหตุการณ์ใหม่';
      final priority = data['priority'] as String? ?? 'LOW';
      final priorityMap = {'CRITICAL': 'วิกฤต', 'HIGH': 'สูง', 'MEDIUM': 'ปานกลาง', 'LOW': 'ต่ำ'};
      final priorityText = priorityMap[priority] ?? priority;
      
      NotificationService.sendPushNotification(
        targetRoles: const ['dispatcher'],
        title: '🚨 เหตุด่วนใหม่!',
        body: '$title (ระดับ: $priorityText)',
        payload: {
          'type': 'incident_new',
          'incidentId': docRef.id,
        },
        channelId: 'urgent_incidents',
      );
    } catch (_) {}

    return docRef.id;
  }

  /// อัปเดตสถานะ (Transaction-based) + #29 Audit Log
  Future<bool> updateIncidentStatus(String incidentId, String newStatus, {String? userId, String? userName}) async {
    try {
      final docRef = _firestore.collection("incidents").doc(incidentId);

      bool success = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("Incident does not exist!");
        }

        final currentStatus = snapshot.data()?['status'] as String? ?? '';

        // อนุญาต CANCELLED transition จากทุก status ยกเว้น RESOLVED
        if (newStatus != 'CANCELLED' && !ResponderLogic.canTransition(currentStatus, newStatus)) {
          throw Exception("Invalid state transition");
        }

        final updates = <String, dynamic>{
          "status": newStatus,
          "updatedAt": FieldValue.serverTimestamp(),
        };

        if (newStatus == "RESOLVED") {
          updates["resolvedAt"] = FieldValue.serverTimestamp();
          updates["timelineStatus"] = "RESOLVED";
        }

        transaction.update(docRef, updates);
        return true;
      });

      // #29: เขียน audit log
      if (success) {
        await addAuditLog(incidentId, 'STATUS_CHANGE', userId: userId, userName: userName, extra: {'newStatus': newStatus});

        // Trigger push notification to reporter
        try {
          final doc = await _firestore.collection('incidents').doc(incidentId).get();
          final reporterId = doc.data()?['reporterId'] as String?;
          final title = doc.data()?['title'] as String? ?? 'เหตุการณ์';
          
          if (reporterId != null) {
            final statusMap = {'PENDING': 'รอดำเนินการ', 'IN_PROGRESS': 'กำลังดำเนินการ', 'RESOLVED': 'เสร็จสิ้น', 'CANCELLED': 'ยกเลิก'};
            final statusText = statusMap[newStatus] ?? newStatus;
            
            NotificationService.sendPushNotification(
              targetUid: reporterId,
              title: '🔄 อัปเดตสถานะเหตุการณ์',
              body: 'เหตุ "$title" เปลี่ยนสถานะเป็น: $statusText',
              payload: {
                'type': 'status',
                'incidentId': incidentId,
              },
              channelId: 'status_updates',
            );
          }
        } catch (_) {}
      }

      return success;
    } catch(e) {
      return false;
    }
  }

  /// Assign Responder + #29 Audit Log
  Future<void> assignResponder(
    String docId,
    String responderId,
    String responderName,
    String department,
    {String? dispatcherId, String? dispatcherName}
  ) async {
    await _firestore.collection('incidents').doc(docId).update({
      'status': 'IN_PROGRESS',
      'timelineStatus': 'ACCEPTED',
      'responderId': responderId,
      'responderName': responderName,
      'department': department,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(docId, 'ASSIGN', userId: dispatcherId, userName: dispatcherName, extra: {
      'responderId': responderId,
      'responderName': responderName,
    });

    // Trigger push notification to responder
    try {
      final doc = await _firestore.collection('incidents').doc(docId).get();
      final title = doc.data()?['title'] as String? ?? 'เหตุการณ์';
      NotificationService.sendPushNotification(
        targetUid: responderId,
        title: '📋 มอบหมายงานใหม่',
        body: 'คุณได้รับมอบหมายเหตุ: $title',
        payload: {
          'type': 'incident_assigned',
          'incidentId': docId,
        },
        channelId: 'urgent_incidents',
      );
    } catch (_) {}
  }

  /// อัปเดตสถานะ timelineStatus ย่อย เช่น 'EN_ROUTE', 'ARRIVED' + #29 Audit Log
  Future<void> updateTimelineStatus(String incidentId, String newTimelineStatus, {String? userId, String? userName}) async {
    await _firestore.collection('incidents').doc(incidentId).update({
      'timelineStatus': newTimelineStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(incidentId, 'TIMELINE_CHANGE', userId: userId, userName: userName, extra: {
      'timelineStatus': newTimelineStatus,
    });
  }

  /// #11: ยกเลิกเหตุ
  Future<void> cancelIncident(String incidentId, String cancelReason, String cancelledByUid, String cancelledByName) async {
    await _firestore.collection('incidents').doc(incidentId).update({
      'status': 'CANCELLED',
      'cancelReason': cancelReason,
      'cancelledBy': cancelledByUid,
      'cancelledByName': cancelledByName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await addAuditLog(incidentId, 'CANCEL', userId: cancelledByUid, userName: cancelledByName, extra: {
      'reason': cancelReason,
    });
  }

  /// #29: Audit Log
  Future<void> addAuditLog(String incidentId, String action, {String? userId, String? userName, Map<String, dynamic>? extra}) async {
    try {
      await _firestore.collection('incidents').doc(incidentId).collection('logs').add({
        'action': action,
        'userId': userId,
        'userName': userName,
        ...?extra,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ไม่ให้ audit log fail ทำให้ main flow พัง
    }
  }

  /// #4: Rate Limiting — นับเหตุที่แจ้งล่าสุด
  Future<int> countRecentIncidents(String uid, Duration duration) async {
    final since = DateTime.now().subtract(duration);
    final query = await _firestore
        .collection('incidents')
        .where('reporterId', isEqualTo: uid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .get();
    return query.docs.length;
  }

  /// Stream ทุกเหตุ
  Stream<QuerySnapshot> getIncidentsStream() {
    return _firestore.collection("incidents").snapshots();
  }

  /// Stream ตาม status list
  Stream<QuerySnapshot> getIncidentsStreamByStatus(List<String> statuses) {
    if (statuses.length == 1) {
      return _firestore
          .collection("incidents")
          .where("status", isEqualTo: statuses.first)
          .orderBy("createdAt", descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection("incidents")
          .where("status", whereIn: statuses)
          .orderBy("createdAt", descending: true)
          .snapshots();
    }
  }

  Stream<QuerySnapshot> getMyIncidents(String uid) {
    return _firestore
        .collection("incidents")
        .where("reporterId", isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getAssignedToMe(String uid) {
    return _firestore
        .collection("incidents")
        .where("responderId", isEqualTo: uid)
        .snapshots();
  }

  Future<int> countIncidents(
    String? status, {
    bool inArray = false,
    List<String>? statuses,
    String? reporterId,
    String? responderId,
  }) async {
    Query query = _firestore.collection("incidents");
    
    if (reporterId != null) {
      query = query.where("reporterId", isEqualTo: reporterId);
    }
    if (responderId != null) {
      query = query.where("responderId", isEqualTo: responderId);
    }

    if (status != null) {
      query = query.where("status", isEqualTo: status);
    } else if (inArray && statuses != null) {
      query = query.where("status", whereIn: statuses);
    }

    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Stream<DocumentSnapshot> getIncidentStream(String incidentId) {
    return _firestore.collection("incidents").doc(incidentId).snapshots();
  }

  Stream<QuerySnapshot> getRespondersForAssignment() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .snapshots();
  }

  /// #29: ดึง audit logs
  Stream<QuerySnapshot> getAuditLogs(String incidentId) {
    return _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// #8: ดึงเบอร์ reporter สำหรับ Call Button
  Future<String?> getReporterPhone(String reporterId) async {
    try {
      final doc = await _firestore.collection('users').doc(reporterId).get();
      return doc.data()?['phoneNumber'] as String?;
    } catch (_) {
      return null;
    }
  }

  // =============================================
  // F5: Suggestion-based Assignment System
  // =============================================

  /// F5: Mapping incident type → department ที่แนะนำ
  static const Map<String, String> typeToDepartment = {
    'security': 'security',
    'medical': 'hospital',
    'accident': 'rescue',
    'facility': 'security',
    'assistance': '_all', // ทุกหน่วย
  };

  /// F5: นับจำนวน active cases (IN_PROGRESS) ของ responder
  Future<int> countActiveIncidents(String responderId) async {
    final query = await _firestore
        .collection('incidents')
        .where('responderId', isEqualTo: responderId)
        .where('status', isEqualTo: 'IN_PROGRESS')
        .get();
    return query.docs.length;
  }

  /// F5: ดึง Responder พร้อม stats สำหรับ Suggestion Tab
  /// คืน List<Map> ที่มี: responderId, name, department, activeCases, distance, score
  Future<List<Map<String, dynamic>>> getRespondersWithStats({
    required String incidentType,
    double? incidentLat,
    double? incidentLng,
  }) async {
    final respondersSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .get();

    // ดึงสถานะ active incidents (IN_PROGRESS) ทั้งหมดในครั้งเดียวเพื่อเลี่ยงคิวรี่ N+1 (Critical 2)
    final activeIncidentsSnap = await _firestore
        .collection('incidents')
        .where('status', isEqualTo: 'IN_PROGRESS')
        .get();

    final Map<String, int> activeCasesMap = {};
    for (final doc in activeIncidentsSnap.docs) {
      final rId = doc.data()['responderId'] as String?;
      if (rId != null) {
        activeCasesMap[rId] = (activeCasesMap[rId] ?? 0) + 1;
      }
    }

    final recommendedDept = typeToDepartment[incidentType] ?? '_all';
    final List<Map<String, dynamic>> results = [];

    for (final doc in respondersSnap.docs) {
      final data = doc.data();
      final responderId = doc.id;
      final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
      final dept = data['department'] ?? '';
      final displayName = name.isNotEmpty
          ? name
          : (data['studentId'] ?? data['email'] ?? responderId);

      // นับ active cases จาก Memory Map ใน $O(1)$
      final activeCases = activeCasesMap[responderId] ?? 0;

      // คำนวณระยะห่าง (ถ้ามี lastLocation + incident location)
      double? distanceKm;
      final lastLoc = data['lastLocation'] as Map<String, dynamic>?;
      if (lastLoc != null && incidentLat != null && incidentLng != null) {
        final rLat = (lastLoc['lat'] as num?)?.toDouble();
        final rLng = (lastLoc['lng'] as num?)?.toDouble();
        if (rLat != null && rLng != null) {
          distanceKm = _haversineDistance(incidentLat, incidentLng, rLat, rLng);
        }
      }

      // คำนวณ score
      int score = 0;
      // department match × 3
      if (recommendedDept == '_all' || dept == recommendedDept) {
        score += 3;
      }
      // active cases < 2 × 2
      if (activeCases < 2) {
        score += 2;
      }
      // distance < 1km × 1
      if (distanceKm != null && distanceKm < 1.0) {
        score += 1;
      }

      results.add({
        'responderId': responderId,
        'name': displayName,
        'department': dept,
        'activeCases': activeCases,
        'distanceKm': distanceKm,
        'score': score,
        'deptMatch': recommendedDept == '_all' || dept == recommendedDept,
      });
    }

    // เรียงตาม score มากไปน้อย
    results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return results;
  }

  /// คำนวณระยะห่าง Haversine (km)
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0; // radius of Earth in km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  // =============================================
  // F6: Responder Location Tracking
  // =============================================

  /// F6: อัปเดตตำแหน่ง Responder ลง Firestore
  Future<void> updateResponderLocation(String uid, double lat, double lng) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLocation': {
          'lat': lat,
          'lng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (_) {
      // ไม่ให้ location update fail ทำให้ app พัง
    }
  }

  /// F6: Stream ตำแหน่ง Responder ทุกคน (สำหรับ Dispatcher Map)
  Stream<QuerySnapshot> getRespondersLocationStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .snapshots();
  }

  /// F7: ดึง lastLocation ของ responder ตาม uid
  Future<Map<String, double>?> getResponderLocation(String responderId) async {
    try {
      final doc = await _firestore.collection('users').doc(responderId).get();
      final data = doc.data();
      if (data == null) return null;
      final loc = data['lastLocation'] as Map<String, dynamic>?;
      if (loc == null) return null;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }

  /// ลบเหตุการณ์ + ข้อความแชทของเหตุนั้น
  Future<bool> deleteIncident(String incidentId) async {
    try {
      final docRef = _firestore.collection('incidents').doc(incidentId);

      // ลบ messages sub-collection ก่อน
      final messages = await docRef.collection('messages').get();
      for (final msg in messages.docs) {
        await msg.reference.delete();
      }

      // ลบ logs sub-collection
      final logs = await docRef.collection('logs').get();
      for (final log in logs.docs) {
        await log.reference.delete();
      }

      // ลบ incident doc
      await docRef.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
