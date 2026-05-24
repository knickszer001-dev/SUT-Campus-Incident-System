import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// #21: Session Timeout — ปิดการใช้งานระบบ Auto-logout เพื่อเปิดจอ Monitor บอร์ดค้างไว้ได้ยาวนาน
class SessionTimeoutWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  ConsumerState<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends ConsumerState<SessionTimeoutWrapper> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
