import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';
import '../chat/presentation/direct_chat_screen.dart';

/// RespondersPanel — แท็บรายชื่อผู้รับเหตุ + ค้นหา + กดแชท DM
class RespondersPanel extends ConsumerStatefulWidget {
  const RespondersPanel({super.key});

  @override
  ConsumerState<RespondersPanel> createState() => _RespondersPanelState();
}

class _RespondersPanelState extends ConsumerState<RespondersPanel> {

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(incidentRepositoryProvider);

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade50,
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 ค้นหาชื่อผู้รับเหตุ...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
        ),

        // Responder list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('โหลดข้อมูลไม่สำเร็จ', style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('ไม่พบผู้รับเหตุในระบบ', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              final responders = snapshot.data!.docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim().toLowerCase();
                final sid = (data['studentId'] ?? '').toString().toLowerCase();
                final dept = (data['department'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || sid.contains(_searchQuery) || dept.contains(_searchQuery);
              }).toList();

              if (responders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('ไม่พบผู้รับเหตุที่ค้นหา', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Count bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.teal.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.teal.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'ผู้รับเหตุ ${responders.length} คน',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(4),
                      itemCount: responders.length,
                      itemBuilder: (context, index) {
                        final doc = responders[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildResponderCard(doc.id, data);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResponderCard(String responderId, Map<String, dynamic> data) {
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty
        ? name
        : (data['studentId'] ?? data['email'] ?? responderId);
    final dept = data['department'] ?? '';
    final deptLabel = AppDepartments.getLabel(dept);

    // Check online status from lastLocation timestamp
    bool isOnline = false;
    String lastSeenStr = 'ไม่ทราบ';
    final lastLocation = data['lastLocation'] as Map<String, dynamic>?;
    if (lastLocation != null) {
      final updatedAt = lastLocation['updatedAt'];
      if (updatedAt is Timestamp) {
        final lastSeen = updatedAt.toDate();
        final diff = DateTime.now().difference(lastSeen);
        isOnline = diff.inMinutes < 5;
        if (diff.inMinutes < 1) {
          lastSeenStr = 'เมื่อสักครู่';
        } else if (diff.inMinutes < 60) {
          lastSeenStr = '${diff.inMinutes} นาทีที่แล้ว';
        } else if (diff.inHours < 24) {
          lastSeenStr = '${diff.inHours} ชม. ที่แล้ว';
        } else {
          lastSeenStr = '${diff.inDays} วันที่แล้ว';
        }
      }
    }

    return Card(
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isOnline ? Colors.teal : Colors.grey,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            // Online indicator
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deptLabel, style: const TextStyle(fontSize: 11)),
            Row(
              children: [
                Icon(
                  isOnline ? Icons.circle : Icons.access_time,
                  size: 10,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'ออนไลน์' : 'ล่าสุด: $lastSeenStr',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
          tooltip: 'แชทกับ $displayName',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DirectChatScreen(
                  otherUserId: responderId,
                  otherUserName: displayName,
                  currentUserRole: 'dispatcher',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
