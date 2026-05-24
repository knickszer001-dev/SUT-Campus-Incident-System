import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../models/incident_model.dart';
import '../auth/presentation/login_screen.dart';
import '../chat/presentation/chat_screen.dart';
import '../chat/presentation/direct_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map_dashboard_screen.dart';
import 'incident_panel.dart';
import 'dispatcher_stats_widget.dart';
import 'resolved_incidents_panel.dart';
import 'responders_panel.dart';

/// DispatcherScreen — v4: 3-Tab Sidebar (รายการเหตุ / เสร็จแล้ว / ผู้รับเหตุ)
class DispatcherScreen extends ConsumerStatefulWidget {
  const DispatcherScreen({super.key});

  @override
  ConsumerState<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends ConsumerState<DispatcherScreen>
    with SingleTickerProviderStateMixin {
  /// Incident ที่ถูกเลือกจาก Sidebar → Map animate camera ไปหมุดนั้น
  Incident? _selectedIncident;

  /// Department + Name ของ dispatcher (load ครั้งเดียวใน initState)
  String? _department;
  String? _dispatcherName;

  /// Connectivity tracking — null = ยังไม่รู้, true = online, false = offline
  bool? _isOnline;

  /// F7: GlobalKey สำหรับเรียก animateToLatLng ของ MapDashboardScreen
  final GlobalKey<MapDashboardScreenState> _mapKey = GlobalKey<MapDashboardScreenState>();

  /// v4: Tab controller สำหรับ sidebar
  late TabController _sidebarTabController;

  @override
  void initState() {
    super.initState();
    _sidebarTabController = TabController(length: 3, vsync: this);
    _loadDispatcherProfile();
  }

  @override
  void dispose() {
    _sidebarTabController.dispose();
    super.dispose();
  }

  Future<void> _loadDispatcherProfile() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final doc = await ref.read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _department = data['department'] as String?;
          final first = data['firstName'] ?? '';
          final last = data['lastName'] ?? '';
          _dispatcherName = '$first $last'.trim();
          if (_dispatcherName!.isEmpty) {
            _dispatcherName = data['studentId'] ?? data['email'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load dispatcher profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
      },
    );
  }

  /// 📱 Mobile Layout: TabBar เต็มหน้าจอ (แผนที่ | รายการเหตุ | เสร็จแล้ว | ผู้รับเหตุ)
  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: _buildAppBar(
          bottom: const TabBar(
            isScrollable: false,
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 11),
            tabs: [
              Tab(icon: Icon(Icons.map, size: 20), text: 'แผนที่'),
              Tab(icon: Icon(Icons.list_alt, size: 20), text: 'รายการเหตุ'),
              Tab(icon: Icon(Icons.check_circle, size: 20), text: 'เสร็จแล้ว'),
              Tab(icon: Icon(Icons.people, size: 20), text: 'ผู้รับเหตุ'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_isOnline == false) _buildOfflineBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 0: แผนที่
                  Stack(
                    children: [
                      MapDashboardScreen(
                        key: _mapKey,
                        selectedIncident: _selectedIncident,
                        onMarkerTap: (incident) {
                          setState(() => _selectedIncident = incident);
                        },
                      ),
                      Positioned(
                        right: 16, bottom: 16,
                        child: _buildChatFAB(),
                      ),
                    ],
                  ),

                  // Tab 1: รายการเหตุ
                  Column(
                    children: [
                      const DispatcherStatsWidget(),
                      Expanded(
                        child: IncidentPanel(
                          department: _department,
                          selectedIncident: _selectedIncident,
                          onIncidentTap: (incident) {
                            setState(() => _selectedIncident = incident);
                          },
                          onConnectivityChange: (isOnline) {
                            if (mounted && _isOnline != isOnline) {
                              setState(() => _isOnline = isOnline);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: เสร็จแล้ว
                  const ResolvedIncidentsPanel(),

                  // Tab 3: ผู้รับเหตุ
                  const RespondersPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🖥️ Desktop Layout: Sidebar + Map (เดิม)
  Widget _buildDesktopLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.45 < 500 ? screenWidth * 0.45 : 500.0;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isOnline == false) _buildOfflineBanner(),
          Expanded(
            child: Row(
              children: [
                // ═══ SIDEBAR ซ้าย: Tabbed Panel ═══
                SizedBox(
                  width: sidebarWidth,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).primaryColor,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: Row(
                                children: [
                                  const Icon(Icons.dashboard, color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  const Text('แผงควบคุม',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_department != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        AppDepartments.getLabel(_department!),
                                        style: const TextStyle(fontSize: 10, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TabBar(
                              controller: _sidebarTabController,
                              indicatorColor: Colors.white,
                              indicatorWeight: 3,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white60,
                              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              unselectedLabelStyle: const TextStyle(fontSize: 11),
                              tabs: const [
                                Tab(icon: Icon(Icons.list_alt, size: 18), text: 'รายการเหตุ', iconMargin: EdgeInsets.only(bottom: 2)),
                                Tab(icon: Icon(Icons.check_circle, size: 18), text: 'เสร็จแล้ว', iconMargin: EdgeInsets.only(bottom: 2)),
                                Tab(icon: Icon(Icons.people, size: 18), text: 'ผู้รับเหตุ', iconMargin: EdgeInsets.only(bottom: 2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _sidebarTabController,
                          children: [
                            Column(
                              children: [
                                const DispatcherStatsWidget(),
                                Expanded(
                                  child: IncidentPanel(
                                    department: _department,
                                    selectedIncident: _selectedIncident,
                                    onIncidentTap: (incident) {
                                      setState(() => _selectedIncident = incident);
                                    },
                                    onConnectivityChange: (isOnline) {
                                      if (mounted && _isOnline != isOnline) {
                                        setState(() => _isOnline = isOnline);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const ResolvedIncidentsPanel(),
                            const RespondersPanel(),
                          ],
                        ),
                      ),
                      if (_selectedIncident != null)
                        _buildDetailPanel(_selectedIncident!),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Stack(
                    children: [
                      MapDashboardScreen(
                        key: _mapKey,
                        selectedIncident: _selectedIncident,
                        onMarkerTap: (incident) {
                          setState(() => _selectedIncident = incident);
                        },
                      ),
                      Positioned(
                        left: 16, bottom: 16,
                        child: _buildChatFAB(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// FAB แชท พร้อม unread badge
  Widget _buildChatFAB() {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: () => _showDispatcherChatSheet(context, user.uid),
          backgroundColor: AppTheme.primaryOrange,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: ref.read(firestoreProvider)
              .collection('incidents')
              .where('status', whereIn: const ['NEW', 'IN_PROGRESS'])
              .snapshots(),
          builder: (context, incidentSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: ref.read(firestoreProvider)
                  .collection('direct_messages')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, dmSnap) {
                int unread = 0;
                if (incidentSnap.hasData) {
                  for (final doc in incidentSnap.data!.docs) {
                    final incident = Incident.fromFirestore(doc);
                    if (incident.hasUnreadMessages(user.uid)) {
                      unread++;
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
                      unread++;
                    }
                  }
                }
                if (unread == 0) return const SizedBox.shrink();
                return Positioned(
                  right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Bottom Sheet แชท — รวม incident chat + DM
  void _showDispatcherChatSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('🚨 แชทเหตุ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  _buildIncidentChatsInSheet(uid),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('📞 แชทกับผู้รับเหตุ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  _buildResponderDMsInSheet(uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentChatsInSheet(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.read(firestoreProvider)
          .collection('incidents')
          .where('status', whereIn: ['NEW', 'IN_PROGRESS'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('ไม่มีเหตุที่มีแชท', style: TextStyle(color: Colors.grey)));
        }
        final incidents = snapshot.data!.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['lastMessageAt'] != null)
            .map((doc) => Incident.fromFirestore(doc))
            .toList();
        incidents.sort((a, b) {
          final at = a.lastMessageAt ?? DateTime(2000);
          final bt = b.lastMessageAt ?? DateTime(2000);
          return bt.compareTo(at);
        });
        if (incidents.isEmpty) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('ไม่มีเหตุที่มีแชท', style: TextStyle(color: Colors.grey)));
        }
        return Column(
          children: incidents.take(15).map((incident) {
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
                  ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                  : const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(incidentId: incident.id, incidentTitle: incident.title, readOnly: true, userRole: 'dispatcher'),
                ));
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResponderDMsInSheet(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref.read(firestoreProvider)
          .collection('direct_messages')
          .where('participants', arrayContains: uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, dmSnapshot) {
        if (!dmSnapshot.hasData || dmSnapshot.data!.docs.isEmpty) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('ยังไม่มีการแชทกับผู้รับเหตุ', style: TextStyle(color: Colors.grey)));
        }
        return Column(
          children: dmSnapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherId = participants.firstWhere((p) => p != uid, orElse: () => '');
            final lastMsg = data['lastMessageAt'] as Timestamp?;
            final readBy = data['lastReadBy'] as Map<String, dynamic>? ?? {};
            final lastRead = readBy[uid] as Timestamp?;
            final hasUnread = lastMsg != null && (lastRead == null || lastMsg.compareTo(lastRead) > 0);
            final lastText = (data['lastMessage'] ?? data['lastMessageText']) as String? ?? '';
            String timeStr = '';
            if (lastMsg != null) {
              final dt = lastMsg.toDate();
              timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
            }
            return FutureBuilder<DocumentSnapshot>(
              future: ref.read(firestoreProvider).collection('users').doc(otherId).get(),
              builder: (context, userSnap) {
                final userName = userSnap.hasData && userSnap.data!.exists
                    ? '${(userSnap.data!.data() as Map<String, dynamic>)['firstName'] ?? ''} ${(userSnap.data!.data() as Map<String, dynamic>)['lastName'] ?? ''}'.trim()
                    : otherId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasUnread ? Colors.red : Colors.indigo,
                    child: Icon(hasUnread ? Icons.mark_chat_unread : Icons.person, color: Colors.white, size: 20),
                  ),
                  title: Text(userName.isNotEmpty ? userName : otherId,
                      style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(lastText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DirectChatScreen(otherUserId: otherId, otherUserName: userName.isNotEmpty ? userName : otherId, currentUserRole: 'dispatcher'),
                    ));
                  },
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar({PreferredSizeWidget? bottom}) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📡 ศูนย์รับเหตุ', style: TextStyle(fontSize: 16)),
          if (_dispatcherName != null && _dispatcherName!.isNotEmpty)
            Text(
              _dispatcherName!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
        ],
      ),
      bottom: bottom,
      actions: [
        // Connectivity indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _isOnline == false
            ? const Icon(Icons.wifi_off, color: Colors.red, size: 20)
            : const Icon(Icons.wifi, color: Colors.green, size: 20),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'ออกจากระบบ',
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
    );
  }

  /// Offline Warning Banner
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠️ ขาดการเชื่อมต่อ — ข้อมูลอาจไม่ถูกต้อง กรุณาตรวจสอบสัญญาณ',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Detail Panel — v3: F7 Monitor buttons + F8 Unread Badge
  Widget _buildDetailPanel(Incident incident) {
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';
    final hasUnread = incident.hasUnreadMessages(currentUid);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.blue.shade200, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _selectedIncident = null),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppHelpers.getPriorityColor(incident.priority),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    incident.priorityText,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppHelpers.getStatusColor(incident.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    incident.statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  incident.typeText,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            if (incident.description.isNotEmpty)
              Text(
                incident.description,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 6),

            // Info rows
            if (incident.reporterName != null)
              Text('👤 ผู้แจ้ง: ${incident.reporterName}',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            if (incident.responderName != null && incident.responderName!.isNotEmpty)
              Text('🚑 ผู้รับเคส: ${incident.responderName}',
                style: const TextStyle(fontSize: 12, color: Colors.teal)),
            Text('⏰ ${incident.formattedTime}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (incident.latitude != null && incident.longitude != null)
              Text('📍 ${incident.latitude!.toStringAsFixed(5)}, ${incident.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (incident.imageUrls.isNotEmpty)
              Text('📷 รูปแนบ ${incident.imageUrls.length} รูป',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),

            // === F7: Monitor Buttons (เฉพาะ IN_PROGRESS) ===
            if (incident.status == IncidentStatus.inProgress) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const Text('🔎 ตรวจสอบเหตุ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // F7: ดูแชท (readOnly) + F8 Unread badge
                  _buildMonitorButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'ดูแชท',
                    color: Colors.indigo,
                    badge: hasUnread,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            incidentId: incident.id,
                            incidentTitle: incident.title,
                            readOnly: true,
                            userRole: 'dispatcher',
                          ),
                        ),
                      );
                    },
                  ),

                  // F7: ดูตำแหน่ง User
                  if (incident.latitude != null && incident.longitude != null)
                    _buildMonitorButton(
                      icon: Icons.person_pin_circle,
                      label: '📍 ตำแหน่งผู้แจ้ง',
                      color: Colors.orange,
                      onPressed: () {
                        _mapKey.currentState?.animateToLatLng(
                          incident.latitude!,
                          incident.longitude!,
                        );
                      },
                    ),

                  // F7: ดูตำแหน่ง Responder
                  if (incident.responderId != null)
                    _buildMonitorButton(
                      icon: Icons.location_searching,
                      label: '📍 ตำแหน่งผู้รับเหตุ',
                      color: Colors.teal,
                      onPressed: () async {
                        final repo = ref.read(incidentRepositoryProvider);
                        final loc = await repo.getResponderLocation(incident.responderId!);
                        if (loc != null && mounted) {
                          _mapKey.currentState?.animateToLatLng(loc['lat']!, loc['lng']!);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ไม่พบตำแหน่งล่าสุดของผู้ตอบสนอง'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// F7: Monitor Button Widget พร้อม badge
  Widget _buildMonitorButton({
    required IconData icon,
    required String label,
    required Color color,
    bool badge = false,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          icon: Icon(icon, size: 14, color: color),
          label: Text(label, style: TextStyle(fontSize: 11, color: color)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            minimumSize: const Size(0, 30),
          ),
          onPressed: onPressed,
        ),
        // F8: Unread badge
        if (badge)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
