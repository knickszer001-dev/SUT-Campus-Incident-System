import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';

/// User Management Screen — v2: #22 เพิ่ม Search + Phone + Stats
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  String? _roleFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("👑 จัดการผู้ใช้"),
      ),

      body: Column(
        children: [
          // #22: Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: "ค้นหาชื่อ, รหัสนักศึกษา, อีเมล...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // #22: Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ทั้งหมด', null),
                _buildFilterChip('Admin', 'admin'),
                _buildFilterChip('Dispatcher', 'dispatcher'),
                _buildFilterChip('Responder', 'responder'),
                _buildFilterChip('User', 'user'),
              ],
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("ไม่พบผู้ใช้"));
                }

                var users = snapshot.data!.docs
                    .map((doc) => UserModel.fromFirestore(doc))
                    .toList();

                // Apply role filter
                if (_roleFilter != null) {
                  users = users.where((u) => u.role == _roleFilter).toList();
                }

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  users = users.where((u) {
                    final name = u.fullName.toLowerCase();
                    final email = u.email.toLowerCase();
                    final sid = u.studentId.toLowerCase();
                    final phone = u.phoneNumber.toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        sid.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();
                }

                // Sort
                users.sort((a, b) => _roleWeight(a.role) - _roleWeight(b.role));

                // #22: Stats header
                final totalUsers = snapshot.data!.docs.length;
                final adminCount = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'admin').length;
                final dispCount = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'dispatcher').length;
                final respCount = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'responder').length;

                return Column(
                  children: [
                    // User count stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Text('ทั้งหมด $totalUsers คน', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          Text('A:$adminCount  D:$dispCount  R:$respCount',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),

                    Expanded(
                      child: users.isEmpty
                          ? const Center(child: Text("ไม่พบผู้ใช้ที่ตรงกับการค้นหา"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return _buildUserCard(context, user);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? role) {
    final isActive = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : null)),
        selected: isActive,
        selectedColor: Colors.blue,
        onSelected: (_) => setState(() => _roleFilter = role),
      ),
    );
  }

  int _roleWeight(String role) {
    switch (role) {
      case 'admin': return 0;
      case 'dispatcher': return 1;
      case 'responder': return 2;
      case 'user': return 3;
      default: return 4;
    }
  }

  Widget _buildUserCard(BuildContext context, UserModel user) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user.fullName.isNotEmpty ? user.fullName : user.email),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            if (user.phoneNumber.isNotEmpty)
              Text('📱 ${user.phoneNumber}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
            if (user.studentId.isNotEmpty)
              Text('🎓 ${user.studentId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRoleBadge(user.role),
                if (user.department != null) ...[
                  const SizedBox(width: 6),
                  _buildDeptBadge(user.department!),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditDialog(context, user),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getRoleColor(role),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getRoleLabel(role),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildDeptBadge(String dept) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppDepartments.getLabel(dept),
        style: TextStyle(color: Colors.teal.shade800, fontSize: 11),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'dispatcher': return Colors.blue;
      case 'responder': return Colors.teal;
      case 'user': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return '🔧 Admin';
      case 'dispatcher': return '📡 Dispatcher';
      case 'responder': return '🚑 Responder';
      case 'user': return '👤 User';
      default: return role;
    }
  }

  void _showEditDialog(BuildContext context, UserModel user) {
    String selectedRole = user.role;
    String? selectedDepartment = user.department;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text("แก้ไข: ${user.fullName.isNotEmpty ? user.fullName : user.email}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("บทบาท", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text("👤 User")),
                      DropdownMenuItem(value: 'dispatcher', child: Text("📡 Dispatcher")),
                      DropdownMenuItem(value: 'responder', child: Text("🚑 Responder")),
                      DropdownMenuItem(value: 'admin', child: Text("🔧 Admin")),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRole = value!;
                        if (selectedRole == 'user' || selectedRole == 'admin') {
                          selectedDepartment = null;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  if (selectedRole == 'dispatcher' || selectedRole == 'responder') ...[
                    const Text("หน่วยงาน", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedDepartment,
                      items: const [
                        DropdownMenuItem(value: null, child: Text("— ไม่ระบุ —")),
                        DropdownMenuItem(value: 'security', child: Text("🛡️ ยามมหาวิทยาลัย")),
                        DropdownMenuItem(value: 'rescue', child: Text("🚑 จิตอาสากู้ภัย")),
                        DropdownMenuItem(value: 'hospital', child: Text("🏥 โรงพยาบาล")),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDepartment = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("ยกเลิก"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _updateUserRole(user.uid, selectedRole, selectedDepartment);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("อัปเดต ${user.fullName.isNotEmpty ? user.fullName : user.email} เรียบร้อย")),
                      );
                    }
                  },
                  child: const Text("บันทึก"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateUserRole(String uid, String role, String? department) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('users').doc(uid).update({
      'role': role,
      'department': department,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
