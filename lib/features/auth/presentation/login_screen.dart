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

  /// F3: แสดง dialog ลืมรหัสผ่าน — v3: แยก 2 ขั้นตอน
  /// Step 1: ยืนยันตัวตน (รหัส + เบอร์โทร)
  /// Step 2: ตั้งรหัสผ่านใหม่
  void _showForgotPasswordDialog() {
    final resetIdController = TextEditingController();
    final phoneController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKeyStep1 = GlobalKey<FormState>();
    final formKeyStep2 = GlobalKey<FormState>();
    int currentStep = 1; // 1 = ยืนยันตัวตน, 2 = ตั้งรหัสผ่านใหม่
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Text('🔑 ลืมรหัสผ่าน'),
                  const Spacer(),
                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ขั้นตอน $currentStep/2',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryOrange),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Error Message ===
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // =====================
                    // STEP 1: ยืนยันตัวตน
                    // =====================
                    if (currentStep == 1)
                      Form(
                        key: formKeyStep1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'กรอกรหัสนักศึกษา/บุคลากร และเบอร์โทรที่ลงทะเบียนไว้\nเพื่อยืนยันตัวตนของคุณ',
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
                                if (v == null || v.trim().isEmpty) return 'กรุณากรอกรหัส';
                                if (!AppHelpers.isValidStudentId(v.trim())) return 'รหัสต้องมีอย่างน้อย 3 ตัวอักษร';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'เบอร์โทรที่ลงทะเบียนไว้',
                                prefixIcon: Icon(Icons.phone),
                                labelText: 'เบอร์โทรศัพท์',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'กรุณากรอกเบอร์โทร';
                                if (v.trim().length < 9) return 'เบอร์โทรไม่ถูกต้อง';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                    // =====================
                    // STEP 2: ตั้งรหัสผ่านใหม่
                    // =====================
                    if (currentStep == 2)
                      Form(
                        key: formKeyStep2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // แสดงข้อมูลที่ยืนยันแล้ว
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '✅ ยืนยันตัวตนสำเร็จ\nรหัส: ${resetIdController.text.trim().toUpperCase()}',
                                      style: TextStyle(color: Colors.green.shade900, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'กรอกรหัสผ่านใหม่ที่ต้องการ',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: newPasswordController,
                              obscureText: obscureNew,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'รหัสผ่านใหม่',
                                prefixIcon: const Icon(Icons.lock_outline),
                                labelText: 'รหัสผ่านใหม่',
                                suffixIcon: IconButton(
                                  icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                                if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirm,
                              decoration: InputDecoration(
                                hintText: 'ยืนยันรหัสผ่านใหม่',
                                prefixIcon: const Icon(Icons.lock_reset),
                                labelText: 'ยืนยันรหัสผ่านใหม่',
                                suffixIcon: IconButton(
                                  icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                                if (v != newPasswordController.text) return 'รหัสผ่านไม่ตรงกัน';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                // ปุ่มซ้าย: ยกเลิก / ย้อนกลับ
                TextButton(
                  onPressed: () {
                    if (currentStep == 2) {
                      setDialogState(() {
                        currentStep = 1;
                        errorMessage = null;
                      });
                    } else {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(
                    currentStep == 2 ? '← ย้อนกลับ' : 'ยกเลิก',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),

                // ปุ่มขวา: ยืนยันตัวตน / ตั้งรหัสผ่านใหม่
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          // === STEP 1: ยืนยันตัวตน ===
                          if (currentStep == 1) {
                            if (!formKeyStep1.currentState!.validate()) return;

                            setDialogState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            try {
                              await ref.read(authRepositoryProvider).verifyStudentByPhone(
                                resetIdController.text.trim(),
                                phoneController.text.trim(),
                              );
                              setDialogState(() {
                                isLoading = false;
                                currentStep = 2;
                                errorMessage = null;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                                errorMessage = _getResetErrorMessage(e);
                              });
                            }
                          }
                          // === STEP 2: ตั้งรหัสผ่านใหม่ ===
                          else {
                            if (!formKeyStep2.currentState!.validate()) return;

                            setDialogState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            try {
                              await ref.read(authRepositoryProvider).resetPasswordByPhone(
                                resetIdController.text.trim(),
                                phoneController.text.trim(),
                                newPasswordController.text,
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ เปลี่ยนรหัสผ่านสำเร็จ! กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                                errorMessage = _getResetErrorMessage(e);
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(currentStep == 1 ? 'ยืนยันตัวตน' : 'ตั้งรหัสผ่านใหม่'),
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
    if (msg.contains('เบอร์โทรศัพท์ไม่ตรง')) return 'เบอร์โทรศัพท์ไม่ตรงกับที่ลงทะเบียนไว้';
    if (msg.contains('user-not-found')) return 'ไม่พบบัญชีนี้ในระบบ';
    if (msg.contains('too-many-requests')) return 'ลองใหม่ภายหลัง';
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }
}