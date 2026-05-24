import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers.dart';
import 'chat_screen.dart';

/// Chat History Screen — แสดงรายการแชทแยกตามเหตุ (สำหรับ User Role)
/// เปิดจาก Floating Action Button ในหน้า Home
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติแชท'),
        centerTitle: true,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('กรุณาเข้าสู่ระบบ'))
          : _ChatListBody(uid: uid),
    );
  }
}

class _ChatListBody extends StatelessWidget {
  final String uid;
  const _ChatListBody({required this.uid});

  @override
  Widget build(BuildContext context) {
    // ดึงเฉพาะเหตุที่ user เป็นผู้แจ้ง
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incidents')
          .where('reporterId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('กำลังโหลดประวัติแชท...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('เกิดข้อผิดพลาด: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'ยังไม่มีประวัติแชท',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  'เมื่อคุณแจ้งเหตุและมีการสนทนา\nจะแสดงรายการที่นี่',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 76,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _ChatIncidentTile(
              incidentId: doc.id,
              data: data,
              currentUid: uid,
            );
          },
        );
      },
    );
  }
}

class _ChatIncidentTile extends StatelessWidget {
  final String incidentId;
  final Map<String, dynamic> data;
  final String currentUid;

  const _ChatIncidentTile({
    required this.incidentId,
    required this.data,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'เหตุการณ์';
    final status = data['status'] as String? ?? 'PENDING';
    final lastMessageAt = data['lastMessageAt'] as Timestamp?;
    final lastMessageSenderId = data['lastMessageSenderId'] as String?;
    final priority = data['priority'] as String? ?? 'LOW';

    // ตรวจสอบข้อความที่ยังไม่ได้อ่าน
    final lastReadBy = data['lastReadBy'] as Map<String, dynamic>?;
    final lastReadTime = lastReadBy?[currentUid] as Timestamp?;
    final hasUnread = lastMessageSenderId != null &&
        lastMessageSenderId != currentUid &&
        (lastReadTime == null ||
            (lastMessageAt != null && lastMessageAt.compareTo(lastReadTime) > 0));

    // Status info
    final statusInfo = _getStatusInfo(status);
    final priorityInfo = _getPriorityInfo(priority);
    final timeText = lastMessageAt != null
        ? _formatTime(lastMessageAt.toDate())
        : '';

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              incidentId: incidentId,
              incidentTitle: title,
              userRole: 'user',
            ),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: priorityInfo.color.withValues(alpha: 0.15),
            child: Icon(priorityInfo.icon, color: priorityInfo.color, size: 24),
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
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
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeText.isNotEmpty)
            Text(
              timeText,
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? Colors.blue.shade700 : Colors.grey,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusInfo.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusInfo.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusInfo.color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasUnread ? 'มีข้อความใหม่' : 'กดเพื่อเปิดแชท',
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? Colors.blue.shade700 : Colors.grey,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
        size: 20,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'เมื่อกี้';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาที';
    if (diff.inHours < 24) return '${diff.inHours} ชม.';
    if (diff.inDays < 7) return '${diff.inDays} วัน';
    return '${dateTime.day}/${dateTime.month}';
  }

  ({Color color, String label}) _getStatusInfo(String status) {
    switch (status) {
      case 'NEW':
      case 'PENDING':
        return (color: Colors.orange, label: 'รอดำเนินการ');
      case 'IN_PROGRESS':
        return (color: Colors.blue, label: 'กำลังดำเนินการ');
      case 'RESOLVED':
        return (color: Colors.green, label: 'เสร็จสิ้น');
      case 'CANCELLED':
        return (color: Colors.grey, label: 'ยกเลิก');
      default:
        return (color: Colors.grey, label: status);
    }
  }

  ({Color color, IconData icon}) _getPriorityInfo(String priority) {
    switch (priority) {
      case 'CRITICAL':
        return (color: Colors.red.shade700, icon: Icons.warning_amber);
      case 'HIGH':
        return (color: Colors.orange.shade700, icon: Icons.priority_high);
      case 'MEDIUM':
        return (color: Colors.amber.shade700, icon: Icons.chat_bubble_outline);
      default:
        return (color: Colors.blue, icon: Icons.chat_bubble_outline);
    }
  }
}
