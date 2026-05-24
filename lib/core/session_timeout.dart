import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/login_screen.dart';
import 'providers.dart';

/// #21: Session Timeout — Auto-logout after 30 minutes of inactivity
/// Wraps the main app body to detect user interaction and idle timeout.
class SessionTimeoutWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  ConsumerState<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends ConsumerState<SessionTimeoutWrapper> {
  Timer? _timer;
  static const _timeout = Duration(minutes: 30);
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, _onTimeout);
  }

  void _onTimeout() {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("⏰ หมดเวลาใช้งาน"),
        content: const Text("ไม่มีการใช้งานเป็นเวลานาน\nกรุณาเข้าสู่ระบบใหม่เพื่อความปลอดภัย"),
        actions: [
          TextButton(
            onPressed: () {
              _dialogShown = false;
              Navigator.pop(ctx);
              _resetTimer();
            },
            child: const Text("ใช้งานต่อ"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("ออกจากระบบ"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
