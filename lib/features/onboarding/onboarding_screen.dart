import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../auth/presentation/login_screen.dart';

/// F33: Onboarding Tutorial — แสดงครั้งแรกที่เปิดแอป
/// UX Review: เปลี่ยนชื่อเป็นไทย, ใช้โลโก้มหาลัยหน้าแรก, สีส้ม
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  /// เช็คว่าเคยดู onboarding แล้วหรือยัง
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  /// บันทึกว่าดู onboarding แล้ว
  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  void _onDone(BuildContext context) async {
    await markOnboardingComplete();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      scrollPhysics: const BouncingScrollPhysics(),
      pages: [
        // Page 1: แนะนำแอป — UX Review: ชื่อไทย + โลโก้มหาลัย
        PageViewModel(
          title: "ระบบแจ้งเหตุมหาวิทยาลัย",
          body: "ระบบแจ้งเหตุฉุกเฉินในมหาวิทยาลัย\nช่วยให้คุณแจ้งเหตุได้ทันทีพร้อม GPS",
          image: _buildLogoImage(),
          decoration: _pageDecoration(),
        ),

        // Page 2: วิธีแจ้งเหตุ
        PageViewModel(
          title: "แจ้งเหตุง่ายๆ",
          body: "กดปุ่ม 'แจ้งเหตุ' เลือกประเภท ถ่ายรูป\nระบบจะส่ง GPS ตำแหน่งอัตโนมัติ",
          image: _buildImage(Icons.report_problem, Colors.red),
          decoration: _pageDecoration(),
        ),

        // Page 3: SOS
        PageViewModel(
          title: "🆘 ปุ่ม SOS",
          body: "กดค้าง 2 วินาทีเพื่อส่งแจ้งเหตุฉุกเฉินทันที\nไม่ต้องกรอกข้อมูล ระบบส่งอัตโนมัติ",
          image: _buildImage(Icons.sos, Colors.red.shade700),
          decoration: _pageDecoration(),
        ),

        // Page 4: ติดตามสถานะ
        PageViewModel(
          title: "ติดตามสถานะ",
          body: "ดูสถานะเหตุแบบ real-time\nแชทกับผู้ตอบสนองได้โดยตรง",
          image: _buildImage(Icons.track_changes, Colors.teal),
          decoration: _pageDecoration(),
        ),

        // Page 5: เริ่มต้น
        PageViewModel(
          title: "พร้อมใช้งาน!",
          body: "เข้าสู่ระบบด้วยรหัสนักศึกษาหรือบุคลากร\nแจ้งเหตุได้ทันที",
          image: _buildImage(Icons.check_circle, Colors.green),
          decoration: _pageDecoration(),
        ),
      ],
      onDone: () => _onDone(context),
      onSkip: () => _onDone(context),
      showSkipButton: true,
      skip: const Text("ข้าม", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      next: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text("ถัดไป", style: TextStyle(color: Colors.white)),
      ),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text("เริ่มใช้งาน", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(22, 8),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        activeColor: AppTheme.primaryOrange,
        color: Colors.grey.shade300,
      ),
    );
  }

  /// หน้าแรก: ใช้โลโก้มหาลัยแทน icon
  Widget _buildLogoImage() {
    return Center(
      child: Image.asset(
        'assets/images/university_logo.png',
        width: 160,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildImage(Icons.shield, AppTheme.primaryOrange),
      ),
    );
  }

  Widget _buildImage(IconData icon, Color color) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 80, color: color),
      ),
    );
  }

  PageDecoration _pageDecoration() {
    return PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryOrange,
      ),
      bodyTextStyle: const TextStyle(
        fontSize: 16,
        color: Colors.black54,
        height: 1.5,
      ),
      imagePadding: const EdgeInsets.only(top: 60),
      contentMargin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
