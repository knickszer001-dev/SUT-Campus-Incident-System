import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/providers.dart';

/// ReportIncidentScreen — v2: Quick Incident support + GPS pre-fetch
/// - quickType / quickPriority / quickTitle: pre-fill จาก Quick Incident Buttons
/// - GPS เริ่มดึงทันทีใน initState (background)
class ReportIncidentScreen extends ConsumerStatefulWidget {
  final String? quickType;
  final String? quickPriority;
  final String? quickTitle;

  const ReportIncidentScreen({
    super.key,
    this.quickType,
    this.quickPriority,
    this.quickTitle,
  });

  @override
  ConsumerState<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

enum _GpsStatus { idle, fetching, ready, failed }

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  late String selectedType;
  late String selectedPriority;

  bool isSubmitting = false;

  double? latitude;
  double? longitude;
  _GpsStatus _gpsStatus = _GpsStatus.idle;

  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    selectedType = widget.quickType ?? 'assistance';
    selectedPriority = widget.quickPriority ?? 'LOW';
    if (widget.quickTitle != null) {
      titleController.text = widget.quickTitle!;
    }
    // 🆕 Pre-fetch GPS ทันที (background)
    _initLocation();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  /// 🆕 Pre-fetch GPS ใน background ทันทีเมื่อเปิดหน้า
  Future<void> _initLocation() async {
    setState(() => _gpsStatus = _GpsStatus.fetching);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.failed);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.failed);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      latitude = position.latitude;
      longitude = position.longitude;
      if (mounted) setState(() => _gpsStatus = _GpsStatus.ready);
    } catch (e) {
      if (mounted) setState(() => _gpsStatus = _GpsStatus.failed);
    }
  }

  /// Fallback: ดึง GPS อีกครั้งถ้า pre-fetch ไม่ได้
  Future<void> getLocation() async {
    if (_gpsStatus == _GpsStatus.ready) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ GPS ปิดอยู่ — จะส่งเหตุโดยไม่มีพิกัด'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ ไม่ได้รับสิทธิ์ GPS — จะส่งเหตุโดยไม่มีพิกัด'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ ไม่สามารถดึงพิกัดได้ แต่ยังส่งเหตุได้'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() { _selectedImages.add(image); });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเลือกรูปได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];
    final List<String> urls = [];
    final List<Reference> uploadedRefs = [];
    final storage = FirebaseStorage.instance;
    final user = ref.read(authStateProvider).value;
    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = '${user?.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = storage.ref().child('incident_images/$fileName');
        final bytes = await _selectedImages[i].readAsBytes();
        final uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Upload Timeout'),
        );
        uploadedRefs.add(snapshot.ref);
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      }
    } catch (e) {
      for (final ref in uploadedRefs) {
        try { await ref.delete(); } catch (_) {}
      }
      rethrow;
    }
    return urls;
  }

  Future<void> submitIncident() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { isSubmitting = true; });
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
          );
        }
        return;
      }
      final repo = ref.read(incidentRepositoryProvider);
      final recentCount = await repo.countRecentIncidents(user.uid, const Duration(hours: 1));
      if (recentCount >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ คุณแจ้งเหตุบ่อยเกินไป — จำกัด 5 ครั้ง/ชม. กรุณารอสักครู่'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      // ถ้า GPS ยังไม่ได้ ให้ลองดึงอีกครั้ง
      if (_gpsStatus != _GpsStatus.ready) {
        await getLocation();
      }
      final authRepo = ref.read(authRepositoryProvider);
      final reporterName = await authRepo.getCurrentUserName();
      final imageUrls = await _uploadImages();

      await repo.submitIncident({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'reporterId': user.uid,
        'reporterName': reporterName,
        'type': selectedType,
        'priority': selectedPriority,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'NEW',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'responderId': null,
        'responderName': null,
        'department': null,
        'imageUrls': imageUrls,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ แจ้งเหตุเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) setState(() { isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQuickMode = widget.quickType != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isQuickMode ? '🚨 แจ้งเหตุด่วน' : 'แจ้งเหตุ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // GPS Status indicator
              _buildGpsStatusChip(),
              const SizedBox(height: 16),

              const Row(
                children: [
                  Icon(Icons.category, size: 18, color: Colors.black54),
                  SizedBox(width: 6),
                  Text('ประเภทเหตุการณ์',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 6),

              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'accident', child: Text('🚗 อุบัติเหตุ')),
                  DropdownMenuItem(value: 'fire', child: Text('🔥 ไฟไหม้')),
                  DropdownMenuItem(value: 'medical', child: Text('🏥 การแพทย์/คนหมดสติ')),
                  DropdownMenuItem(value: 'security', child: Text('🛡️ ทะเลาะวิวาท/ความปลอดภัย')),
                  DropdownMenuItem(value: 'facility', child: Text('🔧 สาธารณูปโภค')),
                  DropdownMenuItem(value: 'assistance', child: Text('🙋 ขอความช่วยเหลืออื่นๆ')),
                ],
                onChanged: (value) { setState(() { selectedType = value!; }); },
              ),

              const SizedBox(height: 20),

              const Row(
                children: [
                  Icon(Icons.priority_high, size: 18, color: Colors.black54),
                  SizedBox(width: 6),
                  Text('ระดับความเร่งด่วน',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 6),

              DropdownButtonFormField<String>(
                value: selectedPriority,
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('🟢 ทั่วไป')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('🟡 ปานกลาง')),
                  DropdownMenuItem(value: 'HIGH', child: Text('🔴 เร่งด่วน')),
                  DropdownMenuItem(value: 'CRITICAL', child: Text('🚨 วิกฤต')),
                ],
                onChanged: (value) { setState(() { selectedPriority = value!; }); },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'หัวข้อเหตุการณ์',
                  hintText: 'ระบุหัวข้อสั้นๆ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณากรอกหัวข้อ';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียดเหตุการณ์',
                  hintText: 'บอกรายละเอียดเพิ่มเติม (ถ้ามี)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณากรอกรายละเอียด';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Text('📷 แนบรูปภาพ (ถ้ามี)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              Row(
                children: [
                  if (!kIsWeb)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('กล้อง'),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  if (!kIsWeb) const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: Icon(kIsWeb ? Icons.add_photo_alternate : Icons.photo_library),
                    label: Text(kIsWeb ? 'แนบรูป / ถ่ายภาพ' : 'แกลเลอรี'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),

              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            height: 100,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List>(
                                future: _selectedImages[index].readAsBytes(),
                                builder: (context, snap) {
                                  if (!snap.hasData) {
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  }
                                  return Image.memory(snap.data!, fit: BoxFit.cover, width: 100, height: 100);
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2, right: 10,
                            child: GestureDetector(
                              onTap: () => setState(() { _selectedImages.removeAt(index); }),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : submitIncident,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('ส่งแจ้งเหตุ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsStatusChip() {
    switch (_gpsStatus) {
      case _GpsStatus.fetching:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('กำลังดึงพิกัด GPS...', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
          ],
        );
      case _GpsStatus.ready:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text('📍 GPS พร้อมแล้ว',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          ],
        );
      case _GpsStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Flexible(
              child: Text('ไม่สามารถดึงพิกัดได้',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _initLocation,
              child: Text('ลองใหม่',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700,
                      decoration: TextDecoration.underline)),
            ),
          ],
        );
      case _GpsStatus.idle:
        return const SizedBox.shrink();
    }
  }
}