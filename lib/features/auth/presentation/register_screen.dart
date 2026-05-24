import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';

/// RegisterScreen — v2: เปลี่ยนจาก email เป็นรหัสนักศึกษา/บุคลากร
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final studentIdController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    studentIdController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).register(
        studentIdController.text.trim(),
        firstNameController.text.trim(),
        lastNameController.text.trim(),
        phoneController.text.trim(),
        passwordController.text,
      );
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลงทะเบียนสำเร็จ! เข้าสู่ระบบได้เลย'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลงทะเบียนไม่สำเร็จ: ${_getErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getErrorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('student-id-already-in-use')) return 'รหัสนักศึกษา/บุคลากรนี้ถูกใช้ไปแล้ว';
    if (msg.contains('email-already-in-use')) return 'รหัสนักศึกษา/บุคลากรนี้ถูกใช้ไปแล้ว';
    if (msg.contains('weak-password')) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    if (msg.contains('invalid-email')) return 'รูปแบบรหัสไม่ถูกต้อง';
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.person_add,
                        size: 48, color: AppTheme.primaryOrange),
                    SizedBox(height: 8),
                    Text('สร้างบัญชีใหม่',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('กรอกข้อมูลให้ครบเพื่อสมัครสมาชิก',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // รหัสนักศึกษา/บุคลากร (v2)
              _buildField(
                controller: studentIdController,
                label: 'รหัสนักศึกษา/บุคลากร',
                icon: Icons.badge,
                hint: 'รหัสนักศึกษา/บุคลากร',
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัสนักศึกษา/บุคลากร';
                  if (!AppHelpers.isValidStudentId(v.trim())) {
                    return 'รหัสต้องมีอย่างน้อย 3 ตัวอักษร (ตัวอักษรหรือตัวเลขเท่านั้น)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ชื่อ + นามสกุล (แถวเดียวกัน)
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: firstNameController,
                      label: 'ชื่อ',
                      icon: Icons.person,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: lastNameController,
                      label: 'นามสกุล',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'กรุณากรอกนามสกุล' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _buildField(
                controller: phoneController,
                label: 'เบอร์โทรศัพท์',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'กรุณากรอกเบอร์โทร';
                  if (v.trim().length < 9) return 'เบอร์โทรไม่ถูกต้อง';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Password field — มีปุ่มซ่อน/แสดง
              TextFormField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                  if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  return null;
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('สมัครสมาชิก',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}