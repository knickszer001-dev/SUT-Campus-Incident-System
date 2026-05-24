import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/app_network_image.dart';
import '../incident/presentation/choose_report_type_screen.dart';
import '../incident/presentation/incident_list_screen.dart';
import '../auth/presentation/login_screen.dart';
import '../profile/profile_screen.dart';
import '../safety/safety_tips_screen.dart';
import '../announcement/announcement_screen.dart';
import '../chat/presentation/chat_history_screen.dart';
import '../../models/incident_model.dart';

/// HomeScreen — v5: white AppBar, SOS ย้ายไปล่าง, สีสอดคล้อง
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final userDataAsync = ref.watch(currentUserProvider);

    final displayName = userDataAsync.when(
      data: (data) {
        if (data == null) return user?.email ?? '';
        final first = data['firstName'] as String? ?? '';
        final last = data['lastName'] as String? ?? '';
        final name = '$first $last'.trim();
        if (name.isNotEmpty) return name;
        final sid = data['studentId'] as String? ?? '';
        return sid.isNotEmpty ? sid : (user?.email ?? '');
      },
      loading: () => user?.email ?? '',
      error: (_, __) => user?.email ?? '',
    );

    final profileImageUrl = userDataAsync.when(
      data: (data) => data?['profileImageUrl'] as String?,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // Chat FAB + notification badge
      floatingActionButton: _ChatFAB(userId: user?.uid),

      appBar: AppBar(
        // โลโก้มหาลัย + สาขาวิชา ซ้ายบน (พื้นหลังขาว มองเห็นชัด)
        titleSpacing: 0,
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/university_logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shield, color: AppTheme.primaryOrange, size: 28),
                ),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/department_logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        title: Text('ระบบแจ้งเหตุ',
            style: TextStyle(fontSize: 16, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: AppTheme.primaryOrange),
            tooltip: 'โปรไฟล์',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppTheme.primaryOrange),
            tooltip: 'ออกจากระบบ',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // === Greeting Card (ฉบับพรีเมียมหรูหรา) ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE57A2B), Color(0xFFD35400)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE57A2B).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 📸 รูปโปรไฟล์พร้อมกรอบสีขาวและเงาเรืองแสงสุดหรู
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: profileImageUrl != null && profileImageUrl.isNotEmpty
                            ? ClipOval(
                                child: AppNetworkImage(
                                  imageUrl: profileImageUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 📝 ข้อมูลผู้ใช้แบบพรีเมียม
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'สวัสดีครับ/ค่ะ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 🛡️ ป้ายความปลอดภัยแบบ Glass Capsule
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified_user, color: Colors.white, size: 9),
                                    SizedBox(width: 2),
                                    Text(
                                      'ปลอดภัย',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 🔔 ไอคอนกระดิ่งแจ้งเตือนสไตล์มินิมอลแบบโปร่งแสง
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),



              const SizedBox(height: 20),

              Text(
                'เมนูหลัก',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              // === ปุ่มแจ้งเหตุ ===
              _HomeButton(
                icon: Icons.report_problem,
                label: 'แจ้งเหตุ',
                subtitle: 'แจ้งเหตุฉุกเฉินพร้อม GPS',
                color: Colors.red.shade600,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChooseReportTypeScreen()),
                ),
              ),

              const SizedBox(height: 10),

              // === เหตุของฉัน ===
              _HomeButton(
                icon: Icons.history,
                label: 'เหตุของฉัน',
                subtitle: 'ติดตามสถานะเหตุที่แจ้ง',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncidentListScreen(
                      filterMode: FilterMode.myIncidents,
                      userId: user?.uid,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _HomeButton(
                icon: Icons.health_and_safety,
                label: 'คำแนะนำความปลอดภัย',
                subtitle: 'สิ่งที่ควรทำเมื่อเกิดเหตุ',
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SafetyTipsScreen()),
                ),
              ),

              const SizedBox(height: 10),

              _HomeButton(
                icon: Icons.campaign,
                label: 'ประกาศจากระบบ',
                subtitle: 'ข่าวสารและแจ้งเตือน',
                color: Colors.deepOrange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnouncementScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // === แถบข้อมูล ===
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'หากเกิดเหตุฉุกเฉินร้ายแรง กรุณาโทร 191 / 1669 ด้วย',
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }
}

/// Chat FAB with notification badge
class _ChatFAB extends ConsumerWidget {
  final String? userId;
  const _ChatFAB({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = userId;
    if (uid == null) return const SizedBox.shrink();

    final incidentsAsync = ref.watch(myIncidentsStreamProvider(uid));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
          ),
          backgroundColor: AppTheme.primaryOrange,
          elevation: 6,
          child: const Icon(Icons.chat, color: Colors.white, size: 26),
        ),
        incidentsAsync.when(
          data: (snapshot) {
            int unreadCount = 0;
            for (final doc in snapshot.docs) {
              final incident = Incident.fromFirestore(doc);
              if (incident.hasUnreadMessages(uid)) {
                unreadCount++;
              }
            }
            if (unreadCount == 0) return const SizedBox.shrink();
            return Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}



/// ปุ่มเมนูหลัก
class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.05),
          highlightColor: color.withValues(alpha: 0.02),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 🎨 แถบสีด้านซ้ายเพิ่มความพรีเมียม
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),

                // 🌟 ไอคอนสไตล์พาสเทลเรืองแสงสุดหรู
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // 📝 ข้อความเมนูหลัก
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ➡️ หัวลูกศรเรียบหรู
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade300,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}