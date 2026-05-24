import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/helpers.dart';
import '../../core/constants.dart';
import '../../models/incident_model.dart';
import 'line_share_helper.dart';
import 'sound_alert_service.dart';
import '../../core/app_network_image.dart';
import '../../core/web_notification.dart' as web_noti;
import '../chat/presentation/chat_screen.dart';

/// Incident Panel สำหรับ Dispatcher — v3: F5 Suggestion Assignment + F8 Unread Badge
class IncidentPanel extends ConsumerStatefulWidget {

  /// Callback เมื่อกดเหตุ → Map animate camera ไปหมุด
  final void Function(Incident incident)? onIncidentTap;

  /// Department ของ dispatcher คนนี้
  final String? department;

  /// Incident ที่ถูกเลือกจาก Map → highlight card ใน Sidebar
  final Incident? selectedIncident;

  /// Callback แจ้งสถานะ connectivity
  final void Function(bool isOnline)? onConnectivityChange;

  const IncidentPanel({
    super.key,
    this.onIncidentTap,
    this.department,
    this.selectedIncident,
    this.onConnectivityChange,
  });

  @override
  ConsumerState<IncidentPanel> createState() => _IncidentPanelState();
}

class _IncidentPanelState extends ConsumerState<IncidentPanel> {

  /// #9: Filter — null = ALL, 'NEW', 'IN_PROGRESS'
  String? _statusFilter;
  int _previousNewCount = -1; // F10: track NEW count for sound alert
  bool _showTodayOnly = false; // สวิตช์วันนี้/ทั้งหมด
  bool? _lastConnectivityStatus; // แคชสถานะเชื่อมต่อล่าสุดเพื่อป้องกันลูป (Performance 1)

  @override
  void initState() {
    super.initState();
    SoundAlertService.initialize();
  }

  @override
  void dispose() {
    SoundAlertService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(incidentRepositoryProvider);

    // v2: แสดงเหตุที่ยังไม่ปิด (NEW + IN_PROGRESS)
    return StreamBuilder<QuerySnapshot>(
      stream: repo.getIncidentsStreamByStatus([
        IncidentStatus.newCase,
        IncidentStatus.inProgress,
      ]),
      builder: (context, snapshot) {

        // ตรวจจับ connectivity จาก stream error และแคชเพื่อป้องกัน Rebuild Loop
        final isOnline = !snapshot.hasError;
        if (_lastConnectivityStatus != isOnline) {
          _lastConnectivityStatus = isOnline;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onConnectivityChange?.call(isOnline);
          });
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('กรุณาตรวจสอบสัญญาณอินเทอร์เน็ต',
                  style: TextStyle(color: Colors.red[700], fontSize: 15)),
                const SizedBox(height: 8),
                const Text(
                  'ข้อมูลอาจไม่ถูกต้อง กรุณาลองใหม่',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allIncidents = (snapshot.hasData)
            ? snapshot.data!.docs.map((doc) => Incident.fromFirestore(doc)).toList()
            : <Incident>[];

        // #9: Stats counters
        final newCount = allIncidents.where((i) => i.status == 'NEW').length;
        final ipCount = allIncidents.where((i) => i.status == 'IN_PROGRESS').length;
        final total = allIncidents.length;

        // F10: เล่นเสียงเมื่อมีเหตุ NEW เพิ่มขึ้น (ไม่เล่นตอนโหลดครั้งแรก)
        if (_previousNewCount >= 0 && newCount > _previousNewCount) {
          SoundAlertService.playAlert();
          // Web: แสดง Browser Notification + เสียง 3 ติ๊ด + สั่น
          if (kIsWeb) {
            final diff = newCount - _previousNewCount;
            web_noti.showBrowserNotification(
              '🚨 เหตุด่วนใหม่ ($diff รายการ)',
              'มีเหตุการณ์ใหม่รอดำเนินการ กรุณาตรวจสอบ',
            );
            web_noti.playWebAlertSoundMultiple(3); // 3 ติ๊ดสำหรับเหตุใหม่
            web_noti.vibrateDevice([300, 100, 300, 100, 300]);
          }
        }
        _previousNewCount = newCount;

        // #9: Filter by status
        var incidents = _statusFilter == null
            ? List<Incident>.from(allIncidents)
            : allIncidents.where((i) => i.status == _statusFilter).toList();

        // Filter เฉพาะวันนี้
        if (_showTodayOnly) {
          final now = DateTime.now();
          incidents = incidents.where((i) {
            if (i.createdAt == null) return false;
            return i.createdAt!.year == now.year &&
                   i.createdAt!.month == now.month &&
                   i.createdAt!.day == now.day;
          }).toList();
        }

        // เรียง: NEW ขึ้นก่อน, จากนั้นเรียงตามเวลา
        incidents.sort((a, b) {
          if (a.status == 'NEW' && b.status != 'NEW') return -1;
          if (a.status != 'NEW' && b.status == 'NEW') return 1;
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        return Column(
          children: [
            // #9: Stats Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  _buildStatBadge('ทั้งหมด', total, Colors.blue, _statusFilter == null, () => setState(() => _statusFilter = null)),
                  const SizedBox(width: 6),
                  _buildStatBadge('ใหม่', newCount, Colors.red, _statusFilter == 'NEW', () => setState(() => _statusFilter = _statusFilter == 'NEW' ? null : 'NEW')),
                  const SizedBox(width: 6),
                  _buildStatBadge('ดำเนินการ', ipCount, Colors.orange, _statusFilter == 'IN_PROGRESS', () => setState(() => _statusFilter = _statusFilter == 'IN_PROGRESS' ? null : 'IN_PROGRESS')),
                  const Spacer(),
                  // Toggle วันนี้/ทั้งหมด
                  GestureDetector(
                    onTap: () => setState(() => _showTodayOnly = !_showTodayOnly),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showTodayOnly ? Colors.indigo.shade50 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showTodayOnly ? Colors.indigo : Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showTodayOnly ? Icons.today : Icons.calendar_month,
                            size: 14,
                            color: _showTodayOnly ? Colors.indigo : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showTodayOnly ? 'วันนี้' : 'ทั้งหมด',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _showTodayOnly ? Colors.indigo : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Incident List
            Expanded(
              child: incidents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                        SizedBox(height: 12),
                        Text('ไม่มีเหตุการณ์ที่ต้องจัดการ',
                          style: TextStyle(fontSize: 15, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            final isNew = incident.status == IncidentStatus.newCase;
            final isSelected = widget.selectedIncident?.id == incident.id;
            // F8: Chat unread badge สำหรับ dispatcher
            final currentUid = ref.watch(authStateProvider).value?.uid ?? '';
            final hasUnread = incident.hasUnreadMessages(currentUid);

            return Card(
              color: isSelected
                  ? Colors.blue.shade50
                  : isNew
                      ? Colors.red.shade50
                      : null,
              elevation: isSelected ? 4 : 1,
              shape: isSelected
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.blue, width: 2),
                    )
                  : null,
              child: Column(
                children: [
                  // ส่วน Header ที่กดได้เพื่อเลือก incident บนแผนที่
                  Stack(
                    children: [
                  InkWell(
                    onTap: () {
                      widget.onIncidentTap?.call(incident);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Header row
                          Row(
                            children: [
                              // Priority badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppHelpers.getPriorityColor(incident.priority),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  incident.priorityText,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppHelpers.getStatusColor(incident.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  incident.statusText,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              if (isNew)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text("ใหม่!", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              if (hasUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble, color: Colors.white, size: 10),
                                      SizedBox(width: 2),
                                      Text("แชทใหม่", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Title
                          Text(
                            incident.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // Type + Reporter
                          Text(
                            "${incident.typeText}  •  👤 ${incident.reporterName ?? '-'}",
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),

                          const SizedBox(height: 4),
                          Text(
                            "⏰ ${incident.formattedTime}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),

                          // #24: SLA Timer
                          if (incident.createdAt != null && incident.status != 'RESOLVED' && incident.status != 'CANCELLED')
                            Builder(builder: (context) {
                              final elapsed = DateTime.now().difference(incident.createdAt!);
                              final minutes = elapsed.inMinutes;
                              String label;
                              Color color;
                              if (minutes < 5) {
                                label = '$minutes นาทีที่แล้ว';
                                color = Colors.green;
                              } else if (minutes < 15) {
                                label = '$minutes นาทีที่แล้ว';
                                color = Colors.orange;
                              } else if (minutes < 60) {
                                label = '$minutes นาทีที่แล้ว ⚠️';
                                color = Colors.red;
                              } else {
                                final hours = elapsed.inHours;
                                label = '$hours ชม. ${minutes % 60} นาที ⚠️';
                                color = Colors.red.shade900;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color.withOpacity(0.25), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time_filled_outlined, size: 12, color: color),
                                      const SizedBox(width: 4),
                                      Text(
                                        "เวลาเฉลี่ย (SLA): $label",
                                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          if (incident.responderName != null && incident.responderName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "🚑 ผู้รับเคส: ${incident.responderName}",
                              style: const TextStyle(fontSize: 13, color: Colors.teal),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                      // ปุ่มลบเหตุ (X) มุมขวาบน
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: () => _showDeleteDialog(context, incident),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // v2: ExpansionTile dropdown detail
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: const Text(
                        'ดูรายละเอียด',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                      children: [
                        // Description
                        if (incident.description.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('📝 รายละเอียด:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              incident.description,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Location
                        if (incident.latitude != null && incident.longitude != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '📍 พิกัด: ${incident.latitude!.toStringAsFixed(5)}, ${incident.longitude!.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),

                        // Images
                        if (incident.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('📷 รูปภาพประกอบ:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: incident.imageUrls.length,
                              itemBuilder: (context, imgIndex) {
                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: AppNetworkImage(
                                          imageUrl: incident.imageUrls[imgIndex],
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    width: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: AppNetworkImage(
                                        imageUrl: incident.imageUrls[imgIndex],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        // แถว 1: แชร์ LINE + แชท
                        Row(
                          children: [
                            // แชร์ LINE
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Text("📲", style: TextStyle(fontSize: 16)),
                                label: const Text("แชร์ LINE", style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                onPressed: () async {
                                  String? reporterPhone;
                                  if (incident.reporterId != null) {
                                    reporterPhone = await repo.getReporterPhone(incident.reporterId!);
                                  }
                                  if (!context.mounted) return;
                                  final success = await LineShareHelper.shareToLine(context, incident, reporterPhone: reporterPhone);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("ไม่สามารถเปิด LINE ได้")),
                                    );
                                  }
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            // แชทหาผู้แจ้ง
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.indigo),
                                label: const Text("แชทผู้แจ้ง", style: TextStyle(fontSize: 13, color: Colors.indigo)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  side: const BorderSide(color: Colors.indigo),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        incidentId: incident.id,
                                        incidentTitle: incident.title,
                                        readOnly: false,
                                        userRole: 'dispatcher',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        // แถว 2: มอบหมาย (เฉพาะเหตุ NEW)
                        if (incident.status == IncidentStatus.newCase) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.person_add, size: 20),
                              label: const Text("มอบหมายผู้รับเหตุ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showAssignDialog(context, incident),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
            ),
          ],
        );
      },
    );
  }

  /// #9: Stats Badge Widget
  Widget _buildStatBadge(String label, int count, Color color, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : Colors.grey.shade600,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: isActive ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// F5: Suggestion-based Assignment Dialog — 2 tabs: แนะนำ vs ทั้งหมด
  void _showAssignDialog(BuildContext context, Incident incident) {
    final repo = ref.read(incidentRepositoryProvider);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 480,
            height: 500,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_add, color: Colors.teal),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text("มอบหมายงาน",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                        Text(
                          'เหตุ: ${incident.title} (${incident.typeText})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // TabBar
                  const TabBar(
                    labelColor: Colors.teal,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.teal,
                    tabs: [
                      Tab(text: '⭐ แนะนำ'),
                      Tab(text: '📋 ทั้งหมด'),
                    ],
                  ),

                  // TabBarView
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: แนะนำ (F5 Suggestion)
                        _buildSuggestionTab(dialogContext, incident, repo),

                        // Tab 2: ทั้งหมด (เหมือนเดิม)
                        _buildAllRespondersTab(dialogContext, incident, repo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// F5: Tab แนะนำ — Responder ที่เหมาะสมเรียงตามคะแนน
  Widget _buildSuggestionTab(BuildContext dialogContext, Incident incident, dynamic repo) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getRespondersWithStats(
        incidentType: incident.type,
        incidentLat: incident.latitude,
        incidentLng: incident.longitude,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 8),
                const Text("โหลดข้อมูลไม่สำเร็จ"),
                const SizedBox(height: 4),
                const Text('กรุณาลองใหม่อีกครั้ง', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }

        final responders = snapshot.data ?? [];
        if (responders.isEmpty) {
          return const Center(child: Text("ไม่พบผู้ตอบสนองในระบบ"));
        }

        // แสดงเฉพาะคนที่ได้คะแนน > 0
        final suggested = responders.where((r) => (r['score'] as int) > 0).toList();
        if (suggested.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "ไม่มีผู้ตอบสนองที่ตรงเงื่อนไขแนะนำ\nลองดูในแท็บ \"ทั้งหมด\"",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: suggested.length,
          itemBuilder: (context, index) {
            final r = suggested[index];
            final score = r['score'] as int;
            final activeCases = r['activeCases'] as int;
            final distKm = r['distanceKm'] as double?;
            final deptMatch = r['deptMatch'] as bool;

            return Card(
              elevation: index == 0 ? 3 : 1,
              color: index == 0 ? Colors.teal.shade50 : null,
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: deptMatch ? Colors.teal : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    if (index == 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  r['name'] ?? '-',
                  style: TextStyle(
                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppDepartments.getLabel(r['department'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      children: [
                        Text(
                          '📊 คะแนน: $score',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: score >= 4 ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '📁 เคสปัจจุบัน: $activeCases',
                          style: TextStyle(
                            fontSize: 11,
                            color: activeCases < 2 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (distKm != null)
                      Text(
                        '📍 ห่าง: ${distKm.toStringAsFixed(2)} กม.',
                        style: TextStyle(
                          fontSize: 11,
                          color: distKm < 1 ? Colors.green : Colors.grey,
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _confirmAndAssign(
                    context,
                    incident,
                    r['responderId'],
                    r['name'],
                    r['department'],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// F5: Tab ทั้งหมด — Responder ทุกคน (เหมือนเดิม)
  Widget _buildAllRespondersTab(BuildContext dialogContext, Incident incident, dynamic repo) {
    return StreamBuilder<QuerySnapshot>(
      stream: repo.getRespondersForAssignment(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 8),
                const Text("โหลดรายชื่อไม่สำเร็จ"),
                const SizedBox(height: 4),
                const Text(
                  'กรุณาลองใหม่อีกครั้ง',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("ไม่พบผู้ตอบสนองในระบบ"),
          );
        }

        final responders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: responders.length,
          itemBuilder: (context, index) {
            final data = responders[index].data() as Map<String, dynamic>;
            final responderId = responders[index].id;
            final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
            final dept = data['department'] ?? '-';
            final displayName = name.isNotEmpty ? name : (data['studentId'] ?? data['email'] ?? responderId);

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(displayName),
              subtitle: Text("📌 ${AppDepartments.getLabel(dept)}"),
              onTap: () async {
                Navigator.pop(dialogContext);
                await _confirmAndAssign(context, incident, responderId, displayName, dept);
              },
            );
          },
        );
      },
    );
  }

  /// Confirmation dialog ก่อน assign
  Future<void> _confirmAndAssign(
    BuildContext context,
    Incident incident,
    String responderId,
    String responderName,
    String department,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันส่งงาน"),
        content: Text("ต้องการส่งเหตุ \"${incident.title}\" ให้ $responderName ใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      await repo.assignResponder(incident.id, responderId, responderName, department);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ส่งงานให้ $responderName เรียบร้อย")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("ไม่สามารถส่งงานได้ กรุณาลองใหม่"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ลบเหตุ — popup ยืนยันก่อนลบ
  Future<void> _showDeleteDialog(BuildContext context, Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text("ยืนยันการลบ", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ต้องการลบเหตุ \"${incident.title}\" ใช่หรือไม่?"),
            const SizedBox(height: 8),
            Text(
              "การลบจะลบข้อมูลทั้งหมดรวมถึงแชท ไม่สามารถกู้คืนได้",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ลบเหตุ"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      final success = await repo.deleteIncident(incident.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ลบเหตุเรียบร้อยแล้ว"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ไม่สามารถลบเหตุได้ กรุณาลองใหม่"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
