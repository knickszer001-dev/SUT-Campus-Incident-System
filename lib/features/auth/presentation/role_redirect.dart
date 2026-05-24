import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/version_check.dart';
import '../../home/home_screen.dart';
import '../../admin/admin_dashboard.dart';
import '../../responder/responder_dashboard.dart';
import '../../dispatcher/dispatcher_screen.dart';
import '../../notification/web_notification_watcher.dart';
import '../../notification/notification_service.dart';
import '../presentation/login_screen.dart';

/// RoleRedirect — แก้ Bug 6 + Q2
/// Bug 6: เปลี่ยนจาก FutureBuilder ใน build() → ใช้ ConsumerStatefulWidget + initState
///         เพื่อหยุด re-call API ทุกครั้งที่ Widget rebuild
/// Q2:    ใช้ authRepository.ensureUserProfile() แทนการ insert DB ซ้อนในไฟล์นี้
class RoleRedirect extends ConsumerStatefulWidget {
  const RoleRedirect({super.key});

  @override
  ConsumerState<RoleRedirect> createState() => _RoleRedirectState();
}

class _RoleRedirectState extends ConsumerState<RoleRedirect> {
  String? _role;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  /// 🔧 Bug 6: เรียก API ครั้งเดียวใน initState — ไม่ re-call เมื่อ rebuild
  /// 🔧 Q2: ใช้ authRepository.ensureUserProfile() แทนเขียน DB ซ้ำ
  /// 🔧 F8: เพิ่ม timeout + failsafe error handling
  Future<void> _loadUserRole() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        if (mounted) setState(() { _isLoading = false; _error = 'no_user'; });
        return;
      }

      // Q2: ใช้ ensureUserProfile จาก authRepository แทนเขียน insert ซ้ำ
      // F8: เพิ่ม timeout 10 วินาที — ถ้าโหลดนานเกินแสดง error
      await ref.read(authRepositoryProvider).ensureUserProfile(user)
          .timeout(const Duration(seconds: 10));

      final doc = await ref.read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final data = doc.data();
      setState(() {
        _role = data?['role'] as String? ?? 'user';
        _isLoading = false;
      });

      // Save FCM token upon authentication validation
      NotificationService.saveToken();

      // #5: Version check (non-blocking)
      if (mounted) VersionChecker.checkVersion(context);
    } on TimeoutException {
      // F8: Timeout-specific error
      if (mounted) {
        setState(() {
          _error = 'timeout';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // F8: หน้า Loading พร้อมข้อความบอกสถานะ
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'กำลังตรวจสอบสิทธิ์ผู้ใช้...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'หากรอนานเกินไป กรุณาตรวจสอบอินเทอร์เน็ต',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    if (_error == 'no_user') {
      // ไม่ควรถึงจุดนี้ปกติ — main.dart จัดการ redirect แล้ว
      return const Scaffold(
        body: Center(child: Text('ยังไม่ได้เข้าสู่ระบบ')),
      );
    }

    // F8: Failsafe error handling — แยก timeout vs error ทั่วไป
    if (_error != null) {
      final isTimeout = _error == 'timeout';
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTimeout ? Icons.timer_off : Icons.wifi_off,
                  size: 56,
                  color: isTimeout ? Colors.orange : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  isTimeout
                      ? 'การเชื่อมต่อใช้เวลานานเกินไป'
                      : 'ไม่สามารถโหลดข้อมูลได้',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isTimeout
                      ? 'เซิร์ฟเวอร์ตอบกลับช้า หรือสัญญาณอินเทอร์เน็ตไม่เสถียร\nกรุณาลองใหม่อีกครั้ง'
                      : 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (!isTimeout && _error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                  onPressed: () {
                    setState(() { _isLoading = true; _error = null; });
                    _loadUserRole();
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('ออกจากระบบ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🎯 Redirect ตาม role (ห่อด้วย WebNotificationWatcher สำหรับแจ้งเตือนบน Web)
    Widget screen;
    switch (_role) {
      case 'dispatcher':
        screen = const DispatcherScreen();
        break;
      case 'responder':
        screen = const ResponderDashboard();
        break;
      case 'admin':
        screen = const AdminDashboard();
        break;
      case 'user':
      default:
        screen = const HomeScreen();
    }
    return WebNotificationWatcher(child: screen);
  }
}