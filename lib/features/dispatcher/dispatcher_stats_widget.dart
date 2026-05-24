import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';

/// F12: Dispatcher Stats Widget — สำหรับแสดงด้านบนของ Dispatcher Sidebar
class DispatcherStatsWidget extends ConsumerWidget {
  const DispatcherStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(incidentRepositoryProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: repo.getIncidentsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        int totalNew = 0;
        int totalIP = 0;
        int totalResolved = 0;
        int todayCount = 0;
        int totalAssignTime = 0;
        int assignedCount = 0;

        // Responder workload map
        final Map<String, int> responderWorkload = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          if (status == IncidentStatus.newCase) totalNew++;
          if (status == IncidentStatus.inProgress) totalIP++;
          if (status == IncidentStatus.resolved) totalResolved++;

          // วันนี้
          if (createdAt != null && createdAt.isAfter(todayStart)) {
            todayCount++;
          }

          // คำนวณ avg assign time (NEW → IN_PROGRESS)
          if (status == IncidentStatus.inProgress || status == IncidentStatus.resolved) {
            final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
            if (createdAt != null && updatedAt != null) {
              totalAssignTime += updatedAt.difference(createdAt).inMinutes;
              assignedCount++;
            }
          }

          // Responder workload
          final responderId = data['responderId'] as String?;
          if (responderId != null && status == IncidentStatus.inProgress) {
            responderWorkload[responderId] = (responderWorkload[responderId] ?? 0) + 1;
          }
        }

        final avgAssignMin = assignedCount > 0 ? (totalAssignTime / assignedCount).round() : 0;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Stats counters
              Row(
                children: [
                  _buildMini('🆕', totalNew, Colors.red),
                  _buildMini('⚙️', totalIP, Colors.orange),
                  _buildMini('✅', totalResolved, Colors.green),
                  _buildMini('📅', todayCount, Colors.blue),
                ],
              ),
              const SizedBox(height: 6),
              // Row 2: Avg assign time + workload
              Row(
                children: [
                  Icon(Icons.timer, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'ส่งงานเฉลี่ย: ${avgAssignMin} นาที',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(Icons.people, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${responderWorkload.length} คนรับงาน',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
              // Row 3: Workload bar (ถ้ามี)
              if (responderWorkload.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 20,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: responderWorkload.entries.map((entry) {
                      final count = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: count >= 3 ? Colors.red.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${count}เคส',
                            style: TextStyle(
                              fontSize: 10,
                              color: count >= 3 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMini(String emoji, int count, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
