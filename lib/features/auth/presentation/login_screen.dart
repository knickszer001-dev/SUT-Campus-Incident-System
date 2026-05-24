import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';
import 'register_screen.dart';
import 'role_redirect.dart';

/// LoginScreen — v2: เปลี่ยนจาก email เป็นรหัสนักศึกษา/บุคลากร
/// UX Review: เปลี่ยนสีเป็นส้ม, เพิ่มโลโก้, แก้ภาษา, แก้ error ดิบ
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final studentId = studentIdController.text.trim();
    final password = passwordController.text;

    setState(() => isLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).login(studentId, password);
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleRedirect()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เข้าสู่ระบบไม่สำเร็จ: ${_getErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// UX Review Bug 2: fallback ไม่แสดง error ดิบ
  String _getErrorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return 'ไม่พบบัญชีนี้';
    if (msg.contains('wrong-password')) return 'รหัสผ่านไม่ถูกต้อง';
    if (msg.contains('invalid-email')) return 'รูปแบบรหัสไม่ถูกต้อง';
    if (msg.contains('invalid-credential')) return 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง';
    if (msg.contains('too-many-requests')) return 'ลองใหม่ภายหลัง (ล็อกชั่วคราว)';
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // === Header — UX Review: โลโก้มหาลัย + สาขา แทน icon Shield ===
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      // โลโก้มหาวิทยาลัย
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/university_logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(Icons.shield,
                                color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // UX Review #1: ชื่อไทยเป็นหลัก
                      Text(
                        'ระบบแจ้งเหตุมหาวิทยาลัย',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ระบบจัดการเหตุฉุกเฉินมหาวิทยาลัย',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // === รหัสนักศึกษา/บุคลากร (v2) ===
                const Text('รหัสนักศึกษา/บุคลากร',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: studentIdController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'รหัสนักศึกษา/บุคลากร',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'กรุณากรอกรหัสนักศึกษา/บุคลากร';
                    }
                    if (!AppHelpers.isValidStudentId(v.trim())) {
                      return 'รหัสต้องมีอย่างน้อย 3 ตัวอักษร (ตัวอักษรหรือตัวเลขเท่านั้น)';
                    }
                    return null;
                  },
                ),
                // UX Review #8: อธิบายรูปแบบรหัสใต้ช่อง
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    'ใช้รหัสนักศึกษาหรือรหัสบุคลากรของท่าน',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),

                const SizedBox(height: 16),

                // === Password ===
                const Text('รหัสผ่าน',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null,
                  onFieldSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 28),

                // === ปุ่มเข้าสู่ระบบ ===
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('เข้าสู่ระบบ',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 8),

                // === F3: ลืมรหัสผ่าน — UX Review #3: สีเทาแทนสีแดง ===
                Center(
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'ลืมรหัสผ่าน?',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // === ลิงก์สมัคร ===
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: 'ยังไม่มีบัญชี? ',
                        style: const TextStyle(color: Colors.black54),
                        children: [
                          TextSpan(
                            text: 'สมัครสมาชิก',
                            style: TextStyle(
                              color: AppTheme.primaryOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// F3: แสดง dialog ลืมรหัสผ่าน
  void _showForgotPasswordDialog() {
    final resetIdController = TextEditingController();
    final formKeyReset = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('🔑 ลืมรหัสผ่าน'),
              content: Form(
                key: formKeyReset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'กรอกรหัสนักศึกษา/บุคลากรของคุณ\nระบบจะดำเนินการรีเซ็ตรหัสผ่านให้',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'รหัสนักศึกษา/บุคลากร',
                        prefixIcon: Icon(Icons.badge),
                        labelText: 'รหัสนักศึกษา/บุคลากร',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'กรุณากรอกรหัส';
                        }
                        if (!AppHelpers.isValidStudentId(v.trim())) {
                          return 'รหัสต้องมีอย่างน้อย 3 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                // UX Review #4: ปุ่มยกเลิก สีเทา
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: isResetting
                      ? null
                      : () async {
                          if (!formKeyReset.currentState!.validate()) return;

                          setDialogState(() => isResetting = true);
                          try {
                            await ref.read(authRepositoryProvider).resetPassword(
                              resetIdController.text.trim(),
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('ส่งคำขอรีเซ็ตรหัสผ่านเรียบร้อย — กรุณาติดต่อผู้ดูแลระบบเพื่อรับรหัสผ่านใหม่'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isResetting = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('ไม่สำเร็จ: ${_getResetErrorMessage(e)}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isResetting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('รีเซ็ตรหัสผ่าน'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getResetErrorMessage(Object e) {
    final msg = e.toString();
    if (msg.contains('ไม่พบรหัสนักศึกษา')) return 'ไม่พบรหัสนักศึกษา/บุคลากรนี้ในระบบ';
    if (msg.contains('user-not-found')) return 'ไม่พบบัญชีนี้ในระบบ';
    if (msg.contains('too-many-requests')) return 'ลองใหม่ภายหลัง';
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }
}