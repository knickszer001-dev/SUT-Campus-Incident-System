import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// #31: Announcement System — ประกาศจากระบบ
/// Admin สร้าง / ลบประกาศ, User ดูประกาศ
class AnnouncementScreen extends ConsumerStatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  int _retryCounter = 0; // ตัวแปรสำหรับบังคับให้วาด Stream ใหม่เมื่อกด Retry

  @override
  Widget build(BuildContext context) {
    final userModel = ref.watch(currentUserProvider).value;
    final isAdmin = userModel?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text("📢 ประกาศ")),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        key: ValueKey(_retryCounter), // การเปลี่ยน Key จะบังคับให้สร้าง StreamBuilder ใหม่ทั้งหมด
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          
          // # UX 2: จัดการหน้าตาแสดงผลเมื่อเกิดข้อผิดพลาดในการเชื่อมต่อ (เช่น ไม่มีสิทธิ์/เน็ตหลุด)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.red),
                    const SizedBox(height: 14),
                    Text(
                      'เกิดข้อผิดพลาดในการโหลดประกาศ',
                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กรุณาตรวจสอบสิทธิ์การใช้งาน หรือการเชื่อมต่อเครือข่ายอินเทอร์เน็ต',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _retryCounter++;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('ลองใหม่อีกครั้ง'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("ยังไม่มีประกาศ", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final body = data['body'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final priority = data['priority'] ?? 'normal'; // normal, important, urgent
              final author = data['authorName'] ?? '';

              Color borderColor;
              IconData icon;
              switch (priority) {
                case 'urgent':
                  borderColor = Colors.red;
                  icon = Icons.warning;
                  break;
                case 'important':
                  borderColor = Colors.orange;
                  icon = Icons.priority_high;
                  break;
                default:
                  borderColor = Colors.blue;
                  icon = Icons.campaign;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: borderColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: borderColor,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => _deleteAnnouncement(context, doc.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(body, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (author.isNotEmpty)
                            Text('👤 $author', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const Spacer(),
                          if (createdAt != null)
                            Text(
                              '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("📢 สร้างประกาศใหม่"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "หัวข้อประกาศ"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "เนื้อหาประกาศ",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: "ระดับความสำคัญ"),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text("🔵 ปกติ")),
                    DropdownMenuItem(value: 'important', child: Text("🟠 สำคัญ")),
                    DropdownMenuItem(value: 'urgent', child: Text("🔴 ด่วนมาก")),
                  ],
                  onChanged: (val) => setDialogState(() => priority = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final authRepo = ref.read(authRepositoryProvider);
                final authorName = await authRepo.getCurrentUserName();

                await FirebaseFirestore.instance.collection('announcements').add({
                  'title': titleController.text.trim(),
                  'body': bodyController.text.trim(),
                  'priority': priority,
                  'authorName': authorName,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("โพสต์"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteAnnouncement(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ลบประกาศ?"),
        content: const Text("ต้องการลบประกาศนี้หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ลบ"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
    }
  }
}
