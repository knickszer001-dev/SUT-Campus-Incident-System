import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// #5: App Version Check
/// ตรวจสอบ version ล่าสุดจาก Firestore collection 'app_config' doc 'version'
/// ถ้า version ปัจจุบันต่ำกว่า minVersion → แสดง dialog บังคับอัปเดต
class VersionChecker {

  /// เรียกตอนเปิดแอป — ถ้า version เก่า → แสดง dialog
  static Future<void> checkVersion(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) return; // ยังไม่ได้ตั้ง config → skip

      final data = doc.data()!;
      final minVersion = data['minVersion'] as String? ?? '0.0.0';
      final latestVersion = data['latestVersion'] as String? ?? currentVersion;
      final forceUpdate = data['forceUpdate'] as bool? ?? false;
      final updateMessage = data['message'] as String? ?? 'มีเวอร์ชั่นใหม่ กรุณาอัปเดต';

      final isOutdated = _compareVersions(currentVersion, minVersion) < 0;
      final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;

      if (isOutdated && forceUpdate) {
        // บังคับอัปเดต — dialog ที่ปิดไม่ได้
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: const Text("⚠️ ต้องอัปเดตแอป"),
                content: Text('$updateMessage\n\nเวอร์ชั่นปัจจุบัน: $currentVersion\nเวอร์ชั่นขั้นต่ำ: $minVersion'),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      // TODO: ใส่ URL ของ App Store / Play Store
                    },
                    child: const Text("อัปเดต"),
                  ),
                ],
              ),
            ),
          );
        }
      } else if (hasUpdate) {
        // แจ้งเตือนอัปเดต (ปิดได้)
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🆕 มีเวอร์ชั่นใหม่ ($latestVersion) พร้อมให้อัปเดต'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'ดูเพิ่ม',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
      // ไม่ block การใช้งานถ้าเช็คไม่ได้
    }
  }

  /// เปรียบเทียบ semver: return < 0 ถ้า a < b, 0 ถ้าเท่ากัน, > 0 ถ้า a > b
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final va = (i < partsA.length ? partsA[i] : 0) ?? 0;
      final vb = (i < partsB.length ? partsB[i] : 0) ?? 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }
}
