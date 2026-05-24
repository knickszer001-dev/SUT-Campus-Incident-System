import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/helpers.dart';
import '../../../core/constants.dart';
import '../../../core/transition_delay.dart';
import '../../../models/incident_model.dart';
import 'incident_detail_screen.dart';

/// Filter modes สำหรับ IncidentListScreen
enum FilterMode { all, myIncidents, assignedToMe }

/// IncidentListScreen — v2: ปรับ tabs ให้ตรง 3 สถานะ + แก้ filter bug "เหตุของฉัน"
class IncidentListScreen extends ConsumerStatefulWidget {
  final FilterMode filterMode;
  final String? userId;

  const IncidentListScreen({
    super.key,
    this.filterMode = FilterMode.all,
    this.userId,
  });

  @override
  ConsumerState<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends ConsumerState<IncidentListScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  int newCount = 0;
  int inProgressCount = 0;
  int resolvedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCounts();
      }
    });
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final repo = ref.read(incidentRepositoryProvider);

    String? reporterId;
    String? responderId;

    if (widget.filterMode == FilterMode.myIncidents) {
      reporterId = widget.userId;
    } else if (widget.filterMode == FilterMode.assignedToMe) {
      responderId = widget.userId;
    }

    try {
      final results = await Future.wait([
        repo.countIncidents(IncidentStatus.newCase, reporterId: reporterId, responderId: responderId),
        repo.countIncidents(IncidentStatus.inProgress, reporterId: reporterId, responderId: responderId),
        repo.countIncidents(IncidentStatus.resolved, reporterId: reporterId, responderId: responderId),
      ]);

      if (mounted) {
        setState(() {
          newCount = results[0];
          inProgressCount = results[1];
          resolvedCount = results[2];
        });
      }
    } catch (e) {
      // ไม่ crash ถ้าโหลด count ไม่ได้
      debugPrint('Failed to load counts: $e');
    }
  }

  String get _screenTitle {
    switch (widget.filterMode) {
      case FilterMode.myIncidents:
        return "เหตุของฉัน";
      case FilterMode.assignedToMe:
        return "เหตุที่ได้รับ";
      case FilterMode.all:
        return "รายการเหตุการณ์";
    }
  }

  /// v2: สถานะที่ต้อง filter ตาม tab index (3 สถานะ)
  List<String> _getStatusesForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return [IncidentStatus.newCase];
      case 1:
        return [IncidentStatus.inProgress];
      case 2:
        return [IncidentStatus.resolved];
      default:
        return [IncidentStatus.newCase];
    }
  }

  Widget _buildListFromQuerySnapshot(
      BuildContext context, QuerySnapshot snapshot, List<String> statuses) {
    if (snapshot.docs.isEmpty) {
      return const Center(child: Text("ไม่มีเหตุการณ์"));
    }

    List<Incident> incidents = snapshot.docs
        .map<Incident>((doc) => Incident.fromFirestore(doc))
        .toList();

    // Sort in-memory to prevent missing composite index crash on Firebase
    incidents.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    // v2 Fix: สำหรับ myIncidents / assignedToMe → filter ด้วย status ของ tab ที่เลือก
    if (widget.filterMode != FilterMode.all) {
      incidents = incidents.where((i) => statuses.contains(i.status)).toList();
    }

    if (incidents.isEmpty) {
      return const Center(child: Text("ไม่มีเหตุการณ์"));
    }

    // #14: Pull-to-Refresh
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final incident = incidents[index];

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppHelpers.getPriorityColor(incident.priority),
                child: Icon(
                  AppHelpers.getTypeIcon(incident.type),
                  color: Colors.white,
                ),
              ),

              title: Text(incident.title),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(incident.typeText),
                  const SizedBox(height: 4),
                  Text(
                    incident.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        incident.statusText,
                        style: TextStyle(
                          color: AppHelpers.getStatusColor(incident.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailScreen(incidentId: incident.id),
                  ),
                );
              },

              // #12: Unread message badge
              trailing: _ChatBadge(incidentId: incident.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListFromSnapshot(
      BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot, List<String> statuses) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return _buildErrorWidget(context, snapshot.error);
    }

    if (!snapshot.hasData || snapshot.data == null) {
      return const Center(child: Text("ไม่มีเหตุการณ์"));
    }

    return _buildListFromQuerySnapshot(context, snapshot.data!, statuses);
  }

  Widget _buildErrorWidget(BuildContext context, Object? error) {
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
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIncidentList(int tabIndex) {
    final repo = ref.watch(incidentRepositoryProvider);
    final statuses = _getStatusesForTab(tabIndex);
    final user = ref.watch(authStateProvider).value;
    final activeUserId = widget.userId ?? user?.uid ?? '';

    // ตรวจจับสตรีมผ่าน StreamProvider ของ Riverpod ป้องกันการเชื่อมต่อล่ม
    if (widget.filterMode == FilterMode.myIncidents) {
      final asyncValue = ref.watch(myIncidentsStreamProvider(activeUserId));
      return asyncValue.when(
        data: (snapshot) => _buildListFromQuerySnapshot(context, snapshot, statuses),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildErrorWidget(context, err),
      );
    } else if (widget.filterMode == FilterMode.assignedToMe) {
      final asyncValue = ref.watch(assignedToMeIncidentsStreamProvider(activeUserId));
      return asyncValue.when(
        data: (snapshot) => _buildListFromQuerySnapshot(context, snapshot, statuses),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildErrorWidget(context, err),
      );
    } else {
      // FilterMode.all: ใช้ Firestore Stream โดยตรงแบบเสถียร
      final stream = repo.getIncidentsStreamByStatus(statuses);
      return StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) => _buildListFromSnapshot(context, snapshot, statuses),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "เหตุใหม่ ($newCount)"),
            Tab(text: "กำลังดำเนินการ ($inProgressCount)"),
            Tab(text: "เสร็จสิ้น ($resolvedCount)"),
          ],
        ),
      ),

      body: TransitionDelay(
        child: TabBarView(
          controller: _tabController,
          children: [
            buildIncidentList(0),
            buildIncidentList(1),
            buildIncidentList(2),
          ],
        ),
      ),
    );
  }
}

/// #12: Chat Badge — แสดงจำนวนข้อความในแชท
class _ChatBadge extends StatelessWidget {
  final String incidentId;
  const _ChatBadge({required this.incidentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incidents')
          .doc(incidentId)
          .collection('messages')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}