import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/helpers.dart';
import '../../../core/constants.dart';
import '../../../models/incident_model.dart';
import '../domain/responder_logic.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../responder/navigator_screen.dart';
import '../../../core/app_network_image.dart';

/// IncidentDetailScreen — v3: เพิ่ม #8 Call, #11 Cancel, #16 Progress Bar, #29 Audit Log
class IncidentDetailScreen extends ConsumerWidget {

  final String incidentId;

  const IncidentDetailScreen({
    super.key,
    required this.incidentId,
  });

  Future<bool> _updateStatus(BuildContext context, WidgetRef ref, String currentStatus, String newStatus) async {
    if (!ResponderLogic.canTransition(currentStatus, newStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("การเปลี่ยนสถานะไม่ถูกต้องตามลำดับขั้นตอน"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยัน"),
        content: Text("ต้องการเปลี่ยนสถานะเป็น \"${AppHelpers.getStatusText(newStatus)}\" ใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("ยกเลิก", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      final currentUser = ref.read(authStateProvider).value;
      final success = await repo.updateIncidentStatus(incidentId, newStatus,
        userId: currentUser?.uid,
        userName: currentUser?.email,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("สถานะถูกเปลี่ยนแปลงโดยบุคคลอื่นไปแล้ว หรือเกิดข้อผิดพลาด"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return success;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่"), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// อัปเดตสถานะเดินทางย่อย
  Future<bool> _updateTimelineStatus(BuildContext context, WidgetRef ref, String newTimelineStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการดำเนินการ"),
        content: Text("ต้องการปรับปรุงความคืบหน้าเป็น \"${newTimelineStatus == 'EN_ROUTE' ? 'เริ่มออกเดินทาง' : 'ถึงจุดเกิดเหตุ'}หรือไม่?\""),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("ยกเลิก", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      final currentUser = ref.read(authStateProvider).value;
      await repo.updateTimelineStatus(incidentId, newTimelineStatus,
        userId: currentUser?.uid,
        userName: currentUser?.email,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่"), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// #11: Cancel Incident Dialog
  Future<void> _showCancelDialog(BuildContext context, WidgetRef ref, Incident incident) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยกเลิกเหตุการณ์"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("กรุณากรอกเหตุผลในการยกเลิก:"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "เหตุผล...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("ปิด", style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ยืนยันยกเลิก"),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonController.text.trim().isEmpty) return;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final authRepo = ref.read(authRepositoryProvider);
      final userName = await authRepo.getCurrentUserName();

      await repo.cancelIncident(
        incident.id,
        reasonController.text.trim(),
        user?.uid ?? '',
        userName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ยกเลิกเหตุการณ์เรียบร้อย"), backgroundColor: Colors.orange),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// #8: Call reporter
  Future<void> _callReporter(BuildContext context, WidgetRef ref, String reporterId) async {
    final repo = ref.read(incidentRepositoryProvider);
    final phone = await repo.getReporterPhone(reporterId);
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ไม่พบเบอร์โทรของผู้แจ้ง")),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final repo = ref.watch(incidentRepositoryProvider);
    final userModelAsync = ref.watch(currentUserProvider);
    final userModel = userModelAsync.value;
    final role = userModelAsync.hasValue ? (userModel?['role'] ?? 'user') : 'user';
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final isResponder = role == 'responder';
    final isDispatcher = role == 'dispatcher';
    final isResponderOrDispatcher = isResponder || isDispatcher;

    return StreamBuilder<DocumentSnapshot>(
      stream: repo.getIncidentStream(incidentId),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("รายละเอียดเหตุการณ์")),
            body: const Center(child: Text("ไม่พบเหตุการณ์")),
          );
        }

        final incident = Incident.fromFirestore(snapshot.data!);
        final status = incident.status;
        final isReporter = currentUserId != null && incident.reporterId == currentUserId;
        final isCancelled = status == 'CANCELLED';

        return Scaffold(
          appBar: AppBar(title: const Text("รายละเอียดเหตุการณ์")),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(
                  incident.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // === #16: Status Progress Bar ===
                _StatusProgressBar(status: status, timelineStatus: incident.timelineStatus),

                const SizedBox(height: 20),

                const Text("รายละเอียด", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(incident.description),

                if (incident.reporterName != null && incident.reporterName!.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Text("👤 ผู้แจ้ง: ${incident.reporterName}",
                    style: const TextStyle(fontSize: 16)),
                ],

                const SizedBox(height: 15),
                Text("ประเภทเหตุการณ์: ${incident.typeText}", style: const TextStyle(fontSize: 16)),

                const SizedBox(height: 15),
                Row(
                  children: [
                    const Text("ระดับความเร่งด่วน: ", style: TextStyle(fontSize: 16)),
                    Chip(
                      label: Text(incident.priorityText),
                      backgroundColor: AppHelpers.getPriorityColor(incident.priority),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                Row(
                  children: [
                    const Text("สถานะ: ", style: TextStyle(fontSize: 18)),
                    Chip(
                      label: Text(isCancelled ? 'ยกเลิก' : incident.statusText),
                      backgroundColor: isCancelled ? Colors.grey : AppHelpers.getStatusColor(status),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),

                // แสดงเหตุผลยกเลิก (#11)
                if (isCancelled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("เหตุผลที่ยกเลิก:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          (snapshot.data!.data() as Map<String, dynamic>?)?['cancelReason'] ?? '-',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                if (incident.responderName != null && incident.responderName!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text("🚑 ผู้รับเคส: ${incident.responderName}", style: const TextStyle(fontSize: 16)),
                ],

                const SizedBox(height: 10),
                Text("⏰ เวลาแจ้ง: ${incident.formattedTime}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),

                // === รูปที่แนบ ===
                if (incident.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text("📷 รูปภาพประกอบ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: incident.imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: AppNetworkImage(
                                  imageUrl: incident.imageUrls[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                imageUrl: incident.imageUrls[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // === Action Buttons ===
                if (!isCancelled) ...[

                  // === Responder Premium Journey Actions ===
                  if (isResponder && status == IncidentStatus.inProgress) ...[
                    if (incident.timelineStatus == null || incident.timelineStatus == 'ACCEPTED') ...[
                      _buildPremiumActionButton(
                        label: "🧭 เริ่มออกเดินทาง (En Route)",
                        icon: Icons.minor_crash,
                        gradientColors: [Colors.teal, Colors.teal.shade700],
                        onPressed: () async {
                          await _updateTimelineStatus(context, ref, 'EN_ROUTE');
                        },
                      ),
                    ] else if (incident.timelineStatus == 'EN_ROUTE') ...[
                      _buildPremiumActionButton(
                        label: "📍 ถึงจุดเกิดเหตุแล้ว (Arrived)",
                        icon: Icons.location_on,
                        gradientColors: [Colors.orange, Colors.amber.shade800],
                        onPressed: () async {
                          await _updateTimelineStatus(context, ref, 'ARRIVED');
                        },
                      ),
                    ] else if (incident.timelineStatus == 'ARRIVED') ...[
                      _buildPremiumActionButton(
                        label: "✅ เสร็จสิ้นภารกิจ (Complete)",
                        icon: Icons.task_alt,
                        gradientColors: [Colors.green, Colors.green.shade700],
                        onPressed: () async {
                          bool success = await _updateStatus(context, ref, status, IncidentStatus.resolved);
                          if (success && context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // #8: Call Button — Responder/Dispatcher โทรหา Reporter
                  if (isResponderOrDispatcher && (incident.reporterId?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildActionButton("📞 โทรหาผู้แจ้ง", Colors.blue, () {
                        _callReporter(context, ref, incident.reporterId!);
                      }),
                    ),

                  // Chat + F8: Unread Badge
                  if ((status == IncidentStatus.inProgress || status == IncidentStatus.resolved) &&
                      (isReporter || isResponderOrDispatcher))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildActionButton("💬 แชท", Colors.indigo, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  incidentId: incidentId,
                                  incidentTitle: incident.title,
                                  userRole: role,
                                ),
                              ),
                            );
                          }),
                          // F8: Unread badge
                          if (incident.hasUnreadMessages(currentUserId ?? ''))
                            Positioned(
                              right: 8,
                              top: 4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // นำทาง
                  if (isResponderOrDispatcher &&
                      incident.latitude != null && incident.longitude != null &&
                      status != IncidentStatus.resolved)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildActionButton("🧭 นำทางไปที่เกิดเหตุ", Colors.teal, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NavigatorScreen(
                              destinationLat: incident.latitude!,
                              destinationLng: incident.longitude!,
                              incidentTitle: incident.title,
                            ),
                          ),
                        );
                      }),
                    ),

                  // #11: Cancel Button — User ยกเลิกได้เมื่อ NEW, Dispatcher ยกเลิกได้ทุกเมื่อ
                  if ((isReporter && status == IncidentStatus.newCase) || isDispatcher)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildActionButton("❌ ยกเลิกเหตุการณ์", Colors.grey, () {
                        _showCancelDialog(context, ref, incident);
                      }),
                    ),
                ],

                // === #27: Rating/Feedback — เฉพาะ Reporter เมื่อ RESOLVED ===
                if (isReporter && status == IncidentStatus.resolved) ...[
                  const SizedBox(height: 20),
                  _RatingSection(
                    incidentId: incidentId,
                    existingRating: (snapshot.data!.data() as Map<String, dynamic>?)?['rating'] as int?,
                    existingFeedback: (snapshot.data!.data() as Map<String, dynamic>?)?['feedback'] as String?,
                  ),
                ],

                // === #29: Audit Log Section ===
                const SizedBox(height: 30),
                const Text("📋 ประวัติการดำเนินการ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _AuditLogSection(incidentId: incidentId, repo: repo),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumActionButton({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// #16: Animated Status Progress Bar
class _StatusProgressBar extends StatelessWidget {
  final String status;
  final String? timelineStatus;
  const _StatusProgressBar({required this.status, this.timelineStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'label': 'แจ้งเหตุแล้ว', 'icon': Icons.campaign_outlined},
      {'label': 'รับเคส', 'icon': Icons.handshake_outlined},
      {'label': 'เดินทาง', 'icon': Icons.minor_crash_outlined},
      {'label': 'ถึงจุดเหตุ', 'icon': Icons.location_on_outlined},
      {'label': 'เสร็จสิ้น', 'icon': Icons.task_alt},
    ];

    int currentStep = 0;
    if (status == 'IN_PROGRESS') {
      currentStep = 1;
      if (timelineStatus == 'EN_ROUTE') currentStep = 2;
      if (timelineStatus == 'ARRIVED') currentStep = 3;
    } else if (status == 'RESOLVED') {
      currentStep = 4;
    } else if (status == 'CANCELLED') {
      currentStep = -1;
    }

    if (currentStep == -1) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text(
              'เหตุการณ์ถูกยกเลิก (Cancelled)',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isActive = currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.5),
                  color: isActive ? Colors.orange : Colors.grey.shade200,
                  gradient: isActive
                      ? const LinearGradient(colors: [Colors.orange, Colors.amber])
                      : null,
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isActive = currentStep >= stepIndex;
          final isCurrent = currentStep == stepIndex;

          final Color stepColor = isActive
              ? (isCurrent ? Colors.orange.shade700 : Colors.green)
              : Colors.grey.shade300;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 38 : 32,
                height: isCurrent ? 38 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? stepColor.withOpacity(0.15) : Colors.grey.shade50,
                  border: Border.all(
                    color: isCurrent ? Colors.orange.shade700 : (isActive ? Colors.green : Colors.grey.shade300),
                    width: isCurrent ? 2.5 : 1.5,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    steps[stepIndex]['icon'] as IconData,
                    color: isActive ? (isCurrent ? Colors.orange.shade800 : Colors.green.shade700) : Colors.grey.shade400,
                    size: isCurrent ? 18 : 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex]['label'] as String,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? (isCurrent ? Colors.orange.shade800 : Colors.green.shade800)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// #29: Audit Log Section
class _AuditLogSection extends StatelessWidget {
  final String incidentId;
  final dynamic repo;
  const _AuditLogSection({required this.incidentId, required this.repo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: repo.getAuditLogs(incidentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("ยังไม่มีประวัติ", style: TextStyle(color: Colors.grey, fontSize: 13));
        }

        final logs = snapshot.data!.docs;

        return Column(
          children: logs.take(10).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final action = data['action'] ?? '';
            final userName = data['userName'] ?? '';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final timeStr = timestamp != null
                ? '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                : '';

            String label;
            IconData icon;
            Color color;

            switch (action) {
              case 'STATUS_CHANGE':
                final newStatus = data['newStatus'] ?? '';
                label = 'เปลี่ยนสถานะเป็น ${AppHelpers.getStatusText(newStatus)}';
                icon = Icons.swap_horiz;
                color = Colors.blue;
                break;
              case 'ASSIGN':
                label = 'มอบหมายให้ ${data['responderName'] ?? ''}';
                icon = Icons.person_add;
                color = Colors.orange;
                break;
              case 'CANCEL':
                label = 'ยกเลิก: ${data['reason'] ?? ''}';
                icon = Icons.cancel;
                color = Colors.red;
                break;
              default:
                label = action;
                icon = Icons.info;
                color = Colors.grey;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 13)),
                        Text('$userName • $timeStr',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// #27: Rating / Feedback Section
class _RatingSection extends StatefulWidget {
  final String incidentId;
  final int? existingRating;
  final String? existingFeedback;

  const _RatingSection({
    required this.incidentId,
    this.existingRating,
    this.existingFeedback,
  });

  @override
  State<_RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<_RatingSection> {
  late int _rating;
  late TextEditingController _feedbackController;
  bool _isSaving = false;
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 0;
    _feedbackController = TextEditingController(text: widget.existingFeedback ?? '');
    _alreadyRated = widget.existingRating != null && widget.existingRating! > 0;
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('incidents').doc(widget.incidentId).update({
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
      });
      if (mounted) {
        setState(() { _isSaving = false; _alreadyRated = true; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ขอบคุณสำหรับการให้คะแนน ⭐"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("บันทึกไม่สำเร็จ กรุณาลองใหม่"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("⭐ ให้คะแนนการบริการ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: _alreadyRated ? null : () => setState(() => _rating = index + 1),
              );
            }),
          ),

          if (!_alreadyRated) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: "ความคิดเห็นเพิ่มเติม (ไม่บังคับ)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                onPressed: _isSaving || _rating == 0 ? null : _submitRating,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("ส่งคะแนน"),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            if (_feedbackController.text.isNotEmpty)
              Text('" ${_feedbackController.text} "', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.brown)),
            const SizedBox(height: 4),
            const Text("ขอบคุณที่ให้คะแนน ✅", style: TextStyle(color: Colors.green, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}