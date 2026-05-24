import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import 'report_incident_screen.dart';

/// ChooseReportTypeScreen — หน้าเลือกประเภทการแจ้งเหตุฉุกเฉินและปุ่ม SOS (ฉบับพรีเมียม)
class ChooseReportTypeScreen extends ConsumerWidget {
  const ChooseReportTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'แจ้งเหตุฉุกเฉิน / ขอความช่วยเหลือ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 💡 แถบคำแนะนำกระจกเงาเรียบหรู (Glassmorphic Tip)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.shield, color: AppTheme.primaryOrange, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ศูนย์รับแจ้งเหตุอัจฉริยะ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'กรุณาเลือกประเภทเหตุการณ์เพื่อประสานงานชุดเคลื่อนที่เร็ว หรือกดปุ่ม SOS ค้างไว้หากตกอยู่ในสถานการณ์วิกฤต',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🏷️ หัวข้อประเภทเหตุ
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'เลือกประเภทการแจ้งเหตุ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 🎛️ ตารางประเภทเหตุ 6 แบบ (จัดเรียงสวยงามด้วยเฉดสี Premium Muted HSL-like Palette เพื่อลด Visual Clutter และเน้นปุ่ม SOS)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
                children: [
                  _TypeButton(
                    emoji: '🚗',
                    label: 'อุบัติเหตุ',
                    tag: 'ด่วนสูง',
                    colors: const [Color(0xFFE07A5F), Color(0xFFC95B43)], // Muted Coral / Terracotta
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'accident',
                          quickPriority: 'HIGH',
                          quickTitle: 'อุบัติเหตุ',
                        ),
                      ),
                    ),
                  ),
                  _TypeButton(
                    emoji: '🔥',
                    label: 'อัคคีภัย / ไฟไหม้',
                    tag: 'วิกฤต',
                    colors: const [Color(0xFFDE8F55), Color(0xFFC87034)], // Muted Burnt Amber
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'fire',
                          quickPriority: 'CRITICAL',
                          quickTitle: 'ไฟไหม้ / อัคคีภัย',
                        ),
                      ),
                    ),
                  ),
                  _TypeButton(
                    emoji: '🏥',
                    label: 'การแพทย์ / บาดเจ็บ',
                    tag: 'ด่วนสูง',
                    colors: const [Color(0xFF81B29A), Color(0xFF5E8B75)], // Muted Soft Sage Green
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'medical',
                          quickPriority: 'HIGH',
                          quickTitle: 'คนหมดสติ / บาดเจ็บป่วยฉุกเฉิน',
                        ),
                      ),
                    ),
                  ),
                  _TypeButton(
                    emoji: '🛡️',
                    label: 'ความมั่นคง / วิวาท',
                    tag: 'ด่วนสูง',
                    colors: const [Color(0xFF6F7D8C), Color(0xFF4F5D6B)], // Muted Steel Indigo
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'security',
                          quickPriority: 'HIGH',
                          quickTitle: 'ทะเลาะวิวาท / รักษาความปลอดภัย',
                        ),
                      ),
                    ),
                  ),
                  _TypeButton(
                    emoji: '🔧',
                    label: 'สาธารณูปโภคชำรุด',
                    tag: 'ปานกลาง',
                    colors: const [Color(0xFF3D5A80), Color(0xFF2B3E58)], // Muted Slate Blue
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'facility',
                          quickPriority: 'MEDIUM',
                          quickTitle: 'ปัญหาสาธารณูปโภคชำรุด',
                        ),
                      ),
                    ),
                  ),
                  _TypeButton(
                    emoji: '🙋',
                    label: 'ขอความช่วยเหลืออื่นๆ',
                    tag: 'ทั่วไป',
                    colors: const [Color(0xFF98A68E), Color(0xFF7E8A74)], // Muted Warm Olive
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen(
                          quickType: 'assistance',
                          quickPriority: 'LOW',
                          quickTitle: 'ขอความช่วยเหลือทั่วไป',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 🆘 ย้าย SOS มาหน้านี้ตามคำสั่ง
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC62828),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'เหตุฉุกเฉินวิกฤตสูงสุด',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SOSButton(user: user, ref: ref),

              const SizedBox(height: 28),

              // 📞 แถบเบอร์โทรฉุกเฉิน
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, const Color(0xFFFFF9C4).withValues(alpha: 0.4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.phone_in_talk, color: Colors.amber.shade800, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สายด่วนหน่วยกู้ชีพสากล',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'หากเป็นอันตรายต่อชีวิต กรุณาโทรสายด่วนภาครัฐควบคู่ไปด้วย (โทร 191 / 1669)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.brown,
                              height: 1.3,
                            ),
                          ),
                        ],
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
}

/// ปุ่มเลือกประเภทการแจ้งเหตุใน Grid พร้อมเฉดสีเรืองแสงและป้าย Priority
class _TypeButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String tag;
  final List<Color> colors;
  final VoidCallback onTap;

  const _TypeButton({
    required this.emoji,
    required this.label,
    required this.tag,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // 🏷️ ป้าย Tag บอกระดับความสำคัญมุมบนขวา
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // ไอคอนและข้อความจัดวางอย่างลงตัว
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SOS Emergency Button (ฉบับเรืองแสงพรีเมียมพร้อมอนิเมชั่น)
class _SOSButton extends StatefulWidget {
  final dynamic user;
  final WidgetRef ref;
  const _SOSButton({required this.user, required this.ref});

  @override
  State<_SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<_SOSButton> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  late AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    double lastHapticPercent = 0.0;
    _holdController.addListener(() {
      final percent = _holdController.value;
      // ให้สั่นเบาตอบรับทุกๆ 15% ของแถบพลังงาน (UX 1)
      if (percent - lastHapticPercent >= 0.15) {
        lastHapticPercent = percent;
        HapticFeedback.lightImpact();
      }
    });

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact(); // สั่นแรงตอบรับเมื่อสั่งการสำเร็จ (UX 1)
        _submitSOS();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  /// ดึงข้อมูลชื่อผู้แจ้งจริงและ GPS ความละเอียดสูงในเบื้องหลังโดยไม่บล็อกความเร็วปุ่ม SOS (UX 1)
  Future<void> _updateReporterInfoAndHighAccuracyLocationAsync(String docId, String uid) async {
    try {
      // 1. ดึงชื่อผู้แจ้งจริงๆ ในเบื้องหลัง (หลีกเลี่ยงบล็อกเครือข่ายหลัก)
      String? realName;
      try {
        final authRepo = widget.ref.read(authRepositoryProvider);
        realName = await authRepo.getCurrentUserName();
      } catch (e) {
        debugPrint('Failed to fetch real name in background: $e');
      }

      // 2. ดึงพิกัด GPS ความละเอียดสูง
      double? highLat, highLng;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 7));
            highLat = pos.latitude;
            highLng = pos.longitude;
          }
        }
      } catch (e) {
        debugPrint('Location permission or GPS high accuracy fetch failed: $e');
      }

      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (realName != null && realName.isNotEmpty) {
        updates['reporterName'] = realName;
      }
      if (highLat != null && highLng != null) {
        updates['latitude'] = highLat;
        updates['longitude'] = highLng;
      }

      await FirebaseFirestore.instance.collection('incidents').doc(docId).update(updates);
      debugPrint('Background SOS info and high accuracy GPS updated successfully for $docId');
    } catch (e) {
      debugPrint('Error in background SOS info update: $e');
    }
  }

  Future<void> _submitSOS() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final user = widget.user;
      if (user == null) return;

      final repo = widget.ref.read(incidentRepositoryProvider);

      // ดึงพิกัดล่าสุดที่แคชไว้ (Last Known) ทันทีเพื่อความรวดเร็วระดับวินาทีชีวิต (UX 1)
      double? lat, lng;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            final cachedPos = await Geolocator.getLastKnownPosition();
            lat = cachedPos?.latitude;
            lng = cachedPos?.longitude;
          }
        }
      } catch (e) {
        debugPrint('Instant GPS read failed, submitting fallback: $e');
      }

      // ยิงข้อมูลขึ้นเซิร์ฟเวอร์ทันทีเพื่อความปลอดภัยสูงสุดโดยไม่ต้องรอโหลดข้อมูลช้า
      final docId = await repo.submitIncident({
        "title": "🆘 SOS เหตุฉุกเฉิน",
        "description": "แจ้งเหตุฉุกเฉินผ่านปุ่ม SOS อัตโนมัติ",
        "reporterId": user.uid,
        "reporterName": user.displayName ?? user.email ?? 'ผู้ใช้งานฉุกเฉิน',
        "type": "emergency",
        "priority": "CRITICAL",
        "latitude": lat,
        "longitude": lng,
        "status": "NEW",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "responderId": null,
        "responderName": null,
        "department": null,
        "imageUrls": [],
      });

      // รันการค้นหาข้อมูลจริงและ GPS ความละเอียดสูงและอัปเดตแบบ Asynchronous ในเบื้องหลังโดยไม่บล็อกผู้ใช้
      _updateReporterInfoAndHighAccuracyLocationAsync(docId, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ส่งแจ้งเหตุฉุกเฉินเรียบร้อยแล้ว! เจ้าหน้าที่กำลังเข้าช่วยเหลือ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ขออภัย ไม่สามารถส่งแจ้งเหตุได้ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _holdController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _holdController,
      builder: (context, child) {
        final percent = _holdController.value;

        return GestureDetector(
          onLongPressStart: (_) => _holdController.forward(),
          onLongPressEnd: (_) {
            if (!_holdController.isCompleted) {
              _holdController.reset();
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFF9E1C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // SOS Glowing Circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow animation matching progress
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15 + (percent * 0.25)),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1 * percent),
                            blurRadius: 10 + (10 * percent),
                            spreadRadius: 2 + (4 * percent),
                          ),
                        ],
                      ),
                    ),
                    // Circular Progress Ring
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 4,
                      ),
                    ),
                    // Innermost Action Symbol
                    _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(
                            Icons.sos,
                            color: Colors.white,
                            size: 34,
                          ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'กดค้าง 2 วินาที เพื่อ SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ส่งข้อมูล GPS และแจ้งเตือนทีมแพทย์ฉุกเฉินทันที',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
