import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import '../../core/helpers.dart';
import '../../core/constants.dart';
import '../../models/incident_model.dart';
import '../incident/presentation/incident_detail_screen.dart';
import '../incident/presentation/report_incident_screen.dart';
import '../incident/presentation/incident_list_screen.dart';
import '../chat/presentation/chat_screen.dart';
import '../chat/presentation/direct_chat_screen.dart';
import '../auth/presentation/login_screen.dart';
import '../safety/safety_tips_screen.dart';
import '../announcement/announcement_screen.dart';
import '../../core/theme.dart';
import 'navigator_screen.dart';

/// ResponderDashboard — v4: + แชทกับศูนย์รับเหตุ (DM)
class ResponderDashboard extends ConsumerStatefulWidget {
  const ResponderDashboard({super.key});

  @override
  ConsumerState<ResponderDashboard> createState() => _ResponderDashboardState();
}

class _ResponderDashboardState extends ConsumerState<ResponderDashboard>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  Timer? _locationTimer; // F6: periodic location update

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {})); // Update FAB visibility
    _initLocationTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  /// F6: เริ่ม GPS tracking — ดึงตำแหน่งทันทีหลัง login + อัปเดตทุก 30 วินาที
  Future<void> _initLocationTracking() async {
    // ดึงตำแหน่งครั้งแรกทันที
    await _updateLocation();

    // อัปเดตทุก 30 วินาที
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLocation();
    });
  }

  /// F6: ดึง GPS + อัปเดต lastLocation ใน Firestore
  Future<void> _updateLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final repo = ref.read(incidentRepositoryProvider);
      await repo.updateResponderLocation(
        user.uid,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('[F6] Location update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🚑 ผู้ตอบสนอง"),
        actions: [
          // F6: Location indicator
          Tooltip(
            message: 'ตำแหน่งถูกอัปเดตอัตโนมัติ',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.gps_fixed, color: Colors.green.shade300, size: 20),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_ind), text: "เหตุที่ได้รับ"),
            Tab(icon: Icon(Icons.check_circle), text: "เสร็จสิ้น"),
            Tab(icon: Icon(Icons.add_alert), text: "แจ้งเหตุเอง"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncidentList(
            user?.uid,
            [IncidentStatus.inProgress],
            showActions: true,
          ),
          _buildIncidentList(
            user?.uid,
            [IncidentStatus.resolved],
            showActions: false,
          ),
          _buildUserFeaturesTab(),
        ],
      ),

      // Floating chat button — รวมแชทกับ User + แชทกับศูนย์
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            onPressed: () => _showChatOptions(context, user?.uid),
            backgroundColor: AppTheme.primaryOrange,
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .where('responderId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'IN_PROGRESS')
                  .snapshots(),
              builder: (context, incidentSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('direct_messages')
                      .where('participants', arrayContains: user.uid)
                      .snapshots(),
                  builder: (context, dmSnap) {
                    int totalUnread = 0;
                    if (incidentSnap.hasData) {
                      for (final doc in incidentSnap.data!.docs) {
                        final incident = Incident.fromFirestore(doc);
                        if (incident.hasUnreadMessages(user.uid)) {
                          totalUnread++;
                        }
                      }
                    }
                    if (dmSnap.hasData) {
                      for (final doc in dmSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final lastMsg = data['lastMessageAt'] as Timestamp?;
                        final readBy = data['lastReadBy'] as Map<String, dynamic>? ?? {};
                        final lastRead = readBy[user.uid] as Timestamp?;
                        if (lastMsg != null && (lastRead == null || lastMsg.compareTo(lastRead) > 0)) {
                          totalUnread++;
                        }
                      }
                    }
                    if (totalUnread == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          '$totalUnread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  /// แสดง Bottom Sheet เลือกแชท (incident chat + dispatcher DM)
  void _showChatOptions(BuildContext context, String? uid) {
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('💬 แชททั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // Section 1: แชทเหตุที่ได้รับ
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('🚨 แชทเหตุที่ได้รับ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  _buildIncidentChatList(uid),
                  const Divider(),
                  // Section 2: แชทกับศูนย์
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('📞 แชทกับศูนย์รับเหตุ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  _buildDispatcherChatListInSheet(uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แสดงรายการแชทเหตุที่ Responder ได้รับ (IN_PROGRESS)
  Widget _buildIncidentChatList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.read(incidentRepositoryProvider).getAssignedToMe(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final incidents = snapshot.data!.docs
            .map((doc) => Incident.fromFirestore(doc))
            .where((i) => i.status == IncidentStatus.inProgress)
            .toList();
        if (incidents.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('ไม่มีเหตุที่กำลังดำเนินการ', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: incidents.map((incident) {
            final hasUnread = incident.hasUnreadMessages(uid);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: hasUnread ? Colors.red : AppHelpers.getPriorityColor(incident.priority),
                child: Icon(hasUnread ? Icons.mark_chat_unread : Icons.warning_amber, color: Colors.white, size: 20),
              ),
              title: Text(incident.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('👤 ${incident.reporterName ?? '-'}', style: const TextStyle(fontSize: 12)),
              trailing: hasUnread
                  ? Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    )
                  : const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatScreen(
                  incidentId: incident.id,
                  incidentTitle: incident.title,
                  userRole: 'responder',
                ),
              ));
            },
          );
        }).toList(),
        );
      },
    );
  }

  /// แสดงรายชื่อ Dispatcher ใน BottomSheet พร้อมกับ unread badge
  Widget _buildDispatcherChatListInSheet(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.read(firestoreProvider)
          .collection('direct_messages')
          .where('participants', arrayContains: uid)
          .snapshots(),
      builder: (context, dmSnapshot) {
        final Map<String, bool> unreadMap = {};
        if (dmSnapshot.hasData) {
          for (final doc in dmSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherId = participants.firstWhere((p) => p != uid, orElse: () => '');
            final lastMsg = data['lastMessageAt'] as Timestamp?;
            final readBy = data['lastReadBy'] as Map<String, dynamic>? ?? {};
            final lastRead = readBy[uid] as Timestamp?;
            final hasUnread = lastMsg != null && (lastRead == null || lastMsg.compareTo(lastRead) > 0);
            if (hasUnread && otherId.isNotEmpty) {
              unreadMap[otherId] = true;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: ref.read(firestoreProvider)
              .collection('users')
              .where('role', isEqualTo: 'dispatcher')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final dispatchers = snapshot.data!.docs;
            if (dispatchers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('ไม่พบศูนย์รับเหตุ', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: dispatchers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                final displayName = name.isNotEmpty ? name : (data['email'] ?? doc.id);
                final hasUnread = unreadMap[doc.id] ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasUnread ? Colors.red : AppTheme.primaryOrange,
                    child: Icon(hasUnread ? Icons.mark_chat_unread : Icons.headset_mic, color: Colors.white, size: 20),
                  ),
                  title: Text(displayName, style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('📌 ${AppDepartments.getLabel(data['department'] ?? '')}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: hasUnread
                      ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DirectChatScreen(
                        otherUserId: doc.id,
                        otherUserName: displayName,
                        currentUserRole: 'responder',
                      ),
                    ));
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  /// Tab 3: ฟีเจอร์ผู้ใช้ — ให้ Responder แจ้งเหตุเองได้
  Widget _buildUserFeaturesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('โหมดแจ้งเหตุ',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('สำหรับแจ้งเหตุเองระหว่างเข้าเวร / ตรวจการ',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // แจ้งเหตุ
          _UserFeatureButton(
            icon: Icons.report_problem,
            label: 'แจ้งเหตุ',
            subtitle: 'แจ้งเหตุฉุกเฉินพร้อม GPS',
            color: Colors.red.shade600,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
            ),
          ),
          const SizedBox(height: 10),

          // เหตุของฉัน (ที่ฉันแจ้งเอง)
          _UserFeatureButton(
            icon: Icons.history,
            label: 'เหตุที่ฉันแจ้ง',
            subtitle: 'ดูเหตุที่ฉันแจ้งเอง (ในฐานะผู้แจ้ง)',
            color: Colors.blue.shade600,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncidentListScreen()),
            ),
          ),
          const SizedBox(height: 10),

          // ประกาศ
          _UserFeatureButton(
            icon: Icons.campaign,
            label: 'ประกาศ',
            subtitle: 'อ่านประกาศจากศูนย์รับเหตุ',
            color: Colors.purple.shade600,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnnouncementScreen()),
            ),
          ),
          const SizedBox(height: 10),

          // เคล็ดลับความปลอดภัย
          _UserFeatureButton(
            icon: Icons.health_and_safety,
            label: 'เคล็ดลับความปลอดภัย',
            subtitle: 'คำแนะนำเพื่อความปลอดภัย',
            color: Colors.teal.shade600,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafetyTipsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentList(String? uid, List<String> statuses, {required bool showActions}) {
    if (uid == null) {
      return const Center(child: Text("ยังไม่ได้เข้าสู่ระบบ"));
    }

    final repo = ref.watch(incidentRepositoryProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: repo.getAssignedToMe(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'เกิดข้อผิดพลาดในการโหลดข้อมูล',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () { setState(() {}); },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('ลองใหม่'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showActions ? Icons.inbox : Icons.check_circle_outline,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  showActions ? "ยังไม่มีเหตุที่ได้รับ" : "ยังไม่มีเหตุที่เสร็จสิ้น",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // filter ตาม statuses ที่ต้องการแสดงใน tab นี้
        final incidents = snapshot.data!.docs
            .map((doc) => Incident.fromFirestore(doc))
            .where((i) => statuses.contains(i.status))
            .toList();

        if (incidents.isEmpty) {
          return Center(
            child: Text(
              showActions ? "ไม่มีเหตุที่ต้องจัดการ" : "ยังไม่มีเหตุที่เสร็จสิ้น",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            return _buildIncidentCard(incident, showActions, uid);
          },
        );
      },
    );
  }

  Widget _buildIncidentCard(Incident incident, bool showActions, String uid) {
    // F8: ตรวจ unread messages
    final hasUnread = incident.hasUnreadMessages(uid);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incident.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header badges
              Row(
                children: [
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
                  Text(
                    incident.formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Title
              Text(
                incident.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              Text(
                "${incident.typeText}  •  👤 ${incident.reporterName ?? '-'}",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),

              // v2: Action buttons — แชท, นำทาง, ดูรายละเอียด, เสร็จสิ้น
              if (showActions) ...[
                const SizedBox(height: 14),

                // แถวที่ 1: แชท (+ F8 badge) + นำทาง
                Row(
                  children: [
                    // ปุ่มแชท + F8: Unread badge
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text("แชท", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      incidentId: incident.id,
                                      incidentTitle: incident.title,
                                      userRole: 'responder',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // F8: Unread badge
                          if (hasUnread)
                            Positioned(
                              right: -2,
                              top: -2,
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

                    const SizedBox(width: 8),

                    // ปุ่มนำทาง
                    if (incident.latitude != null && incident.longitude != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation, size: 18),
                          label: const Text("นำทาง", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          ),
                          onPressed: () {
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
                          },
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // แถวที่ 2: ดูรายละเอียด + เสร็จสิ้น
                Row(
                  children: [
                    // ปุ่มดูรายละเอียด
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("รายละเอียด", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IncidentDetailScreen(incidentId: incident.id),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ปุ่มเสร็จสิ้น (IN_PROGRESS → RESOLVED)
                    if (incident.status == IncidentStatus.inProgress)
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [Colors.green, Colors.green.shade700],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 20, color: Colors.white),
                            label: const Text("เสร็จสิ้น", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _markAsResolved(incident),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // สำหรับ tab เสร็จสิ้น — แสดงปุ่มดูรายละเอียดอย่างเดียว
              if (!showActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("ดูรายละเอียด", style: TextStyle(fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IncidentDetailScreen(incidentId: incident.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text("แชท", style: TextStyle(fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                incidentId: incident.id,
                                incidentTitle: incident.title,
                                userRole: 'responder',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// v2: เปลี่ยนสถานะจาก IN_PROGRESS → RESOLVED
  Future<void> _markAsResolved(Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันเสร็จสิ้น"),
        content: Text("ต้องการปิดเคส \"${incident.title}\" ใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ยืนยัน"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(incidentRepositoryProvider);
      final success = await repo.updateIncidentStatus(incident.id, IncidentStatus.resolved);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("ปิดเคสเรียบร้อยแล้ว"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("ไม่สามารถปิดเคสได้ — สถานะอาจถูกเปลี่ยนแปลงแล้ว"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// ปุ่มเมนูฟีเจอร์ User สำหรับ Responder
class _UserFeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _UserFeatureButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}