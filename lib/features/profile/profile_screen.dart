import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/app_network_image.dart';
import '../../models/user_model.dart';
import '../auth/presentation/login_screen.dart';
import '../auth/presentation/role_redirect.dart';

/// ProfileScreen — Q8: เพิ่มปุ่มแก้ไข + ฟอร์มแก้ไขข้อมูลส่วนตัว
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("ยังไม่ได้เข้าสู่ระบบ")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ข้อมูลผู้ใช้"),
        actions: [
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
      ),

      body: StreamBuilder(
        stream: ref.read(firestoreProvider)
            .collection('users')
            .doc(user.uid)
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("ไม่พบข้อมูล"));
          }

          final userModel = UserModel.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppTheme.primaryOrange,
                        child: userModel.profileImageUrl != null && userModel.profileImageUrl!.isNotEmpty
                            ? ClipOval(
                                child: AppNetworkImage(
                                  imageUrl: userModel.profileImageUrl!,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                userModel.fullName.isNotEmpty
                                    ? userModel.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 32, color: Colors.white),
                              ),
                      ),
                      // ปุ่มเปลี่ยนรูป
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _uploadProfileImage(context, ref, userModel.uid),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildInfoRow(Icons.person, "ชื่อ", userModel.fullName.isNotEmpty ? userModel.fullName : '-'),
                _buildInfoRow(Icons.badge, "รหัสนักศึกษา/บุคลากร", userModel.studentId.isNotEmpty ? userModel.studentId : '-'),
                _buildInfoRow(Icons.phone, "เบอร์โทร", userModel.phoneNumber.isNotEmpty ? userModel.phoneNumber : '-'),
                _buildInfoRow(
                  Icons.badge,
                  "บทบาท",
                  userModel.role,
                  onLongPress: () => _showDeveloperRoleSwitchDialog(context, ref, userModel),
                ),
                if (userModel.department != null)
                  _buildInfoRow(Icons.business, "หน่วยงาน", userModel.department!),
                _buildInfoRow(Icons.star, "คะแนนอาสา", '${userModel.volunteerPoints}'),

                const SizedBox(height: 24),

                // 🆕 Q8: ปุ่มแก้ไข
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("แก้ไขข้อมูล"),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _EditProfileDialog(userModel: userModel),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // #3: ปุ่มเปลี่ยนรหัสผ่าน
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock),
                    label: const Text("เปลี่ยนรหัสผ่าน"),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _ChangePasswordDialog(ref: ref),
                      );
                    },
                  ),
                ),

                const Divider(height: 28),

                // #33: Dark Mode Toggle
                Row(
                  children: [
                    const Icon(Icons.dark_mode, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('โหมดมืด')),
                    Switch(
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      onChanged: (isDark) {
                        ref.read(themeModeProvider.notifier).state =
                            isDark ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onLongPress}) {
    final rowContent = Row(
      children: [
        Icon(icon, color: AppTheme.primaryOrange, size: 20),
        const SizedBox(width: 12),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Expanded(
          child: Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 16)),
              if (onLongPress != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(กดค้างเพื่อเปลี่ยน)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: onLongPress != null
          ? InkWell(
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: rowContent,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: rowContent,
            ),
    );
  }

  void _showDeveloperRoleSwitchDialog(BuildContext context, WidgetRef ref, UserModel userModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.developer_mode, color: Colors.amber),
              SizedBox(width: 8),
              Text("Developer Role Switcher"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("เลือกบทบาทที่ต้องการจำลองเพื่อทำการทดสอบระบบ:"),
              const SizedBox(height: 12),
              ListTile(
                title: const Text("User (ผู้แจ้งเหตุ)"),
                leading: const Icon(Icons.person, color: Colors.blue),
                onTap: () => _updateRoleAndRedirect(dialogContext, ref, userModel.uid, "user"),
              ),
              ListTile(
                title: const Text("Dispatcher (เจ้าหน้าที่รับแจ้ง)"),
                leading: const Icon(Icons.support_agent, color: Colors.orange),
                onTap: () => _updateRoleAndRedirect(dialogContext, ref, userModel.uid, "dispatcher"),
              ),
              ListTile(
                title: const Text("Responder (ผู้เผชิญเหตุ/กู้ภัย)"),
                leading: const Icon(Icons.local_hospital, color: Colors.teal),
                onTap: () => _updateRoleAndRedirect(dialogContext, ref, userModel.uid, "responder"),
              ),
              ListTile(
                title: const Text("Admin (ผู้ดูแลระบบ)"),
                leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                onTap: () => _updateRoleAndRedirect(dialogContext, ref, userModel.uid, "admin"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateRoleAndRedirect(BuildContext context, WidgetRef ref, String uid, String newRole) async {
    Navigator.pop(context); // ปิด dialog
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กำลังเปลี่ยนบทบาทผู้ใช้...')),
    );

    try {
      final firestore = ref.read(firestoreProvider);
      
      final updates = <String, dynamic>{
        'role': newRole,
      };
      if (newRole == 'responder' || newRole == 'dispatcher') {
        updates['department'] = 'security';
      }

      await firestore.collection('users').doc(uid).update(updates);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เปลี่ยนบทบาทเป็น $newRole สำเร็จแล้ว! กำลังเปลี่ยนหน้าจอ...'),
          backgroundColor: Colors.green,
        ),
      );

      // หน่วงเวลาสั้นๆ แล้ว redirect ไปยังหน้า RoleRedirect เพื่อเข้าสู่หน้าจอของบทบาทนั้นทันที
      await Future.delayed(const Duration(milliseconds: 600));
      if (!context.mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleRedirect()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปลี่ยนบทบาทได้ กรุณาลองใหม่'), backgroundColor: Colors.red),
      );
    }
  }

  /// อัปโหลดรูปโปรไฟล์
  Future<void> _uploadProfileImage(BuildContext context, WidgetRef ref, String uid) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กำลังอัปโหลดรูปโปรไฟล์...'), duration: Duration(seconds: 10)),
    );

    try {
      final bytes = await image.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      await ref.read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .update({'profileImageUrl': downloadUrl});

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตรูปโปรไฟล์เรียบร้อย'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดไม่สำเร็จ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// B4: ดึง Dialog ออกมาเป็น ConsumerStatefulWidget เพื่อจัดการ Memory Lifecycle
class _EditProfileDialog extends ConsumerStatefulWidget {
  final UserModel userModel;

  const _EditProfileDialog({required this.userModel});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late TextEditingController firstNameCtrl;
  late TextEditingController lastNameCtrl;
  late TextEditingController phoneCtrl;

  // 🆕 Plan 1: Form key for validation
  final _formKey = GlobalKey<FormState>();
  // 🆕 Plan 1: Loading state to prevent double submission
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    firstNameCtrl = TextEditingController(text: widget.userModel.firstName);
    lastNameCtrl = TextEditingController(text: widget.userModel.lastName);
    phoneCtrl = TextEditingController(text: widget.userModel.phoneNumber);
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("✏️ แก้ไขข้อมูล"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔧 Plan 1: TextFormField with validators instead of plain TextField
              TextFormField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(labelText: "ชื่อ"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(labelText: "นามสกุล"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกนามสกุล';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "เบอร์โทรศัพท์"),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          // 🔧 Plan 1: ป้องกันปิด dialog ระหว่างกำลังบันทึก
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("ยกเลิก"),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("บันทึก"),
        ),
      ],
    );
  }

  /// 🔧 Plan 1: บันทึกข้อมูลพร้อม validation + try-catch + mounted check
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // เก็บ reference ก่อน async เพื่อป้องกัน context unmount
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('users').doc(widget.userModel.uid).update({
        'firstName': firstNameCtrl.text.trim(),
        'lastName': lastNameCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("อัปเดตข้อมูลเรียบร้อย")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }
}

/// #3: Dialog เปลี่ยนรหัสผ่าน
class _ChangePasswordDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordDialog({required this.ref});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPwController.text;
    final newPw = _newPwController.text;
    final confirmPw = _confirmPwController.text;

    if (currentPw.isEmpty || newPw.isEmpty) {
      setState(() => _error = 'กรุณากรอกข้อมูลให้ครบ');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _error = 'รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await widget.ref.read(authRepositoryProvider).changePassword(currentPw, newPw);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เปลี่ยนรหัสผ่านสำเร็จ ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().contains('wrong-password')
              ? 'รหัสผ่านปัจจุบันไม่ถูกต้อง'
              : 'เกิดข้อผิดพลาด กรุณาลองใหม่';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("🔑 เปลี่ยนรหัสผ่าน"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "รหัสผ่านปัจจุบัน",
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "รหัสผ่านใหม่",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "ยืนยันรหัสผ่านใหม่",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ยกเลิก"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("เปลี่ยน"),
        ),
      ],
    );
  }
}