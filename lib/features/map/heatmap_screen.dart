import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import '../../core/adaptive_map_widget.dart';

/// F28: Heatmap Screen — แสดงพื้นที่เกิดเหตุซ้ำบ่อยด้วย Circles overlay
/// ใช้ Circle + opacity แทน Heatmap tile เพราะ google_maps_flutter ไม่รองรับ heatmap layer โดยตรง
/// รองรับ Windows ด้วย flutter_map (OpenStreetMap)
class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  List<AdaptiveCircle> _heatCircles = [];
  bool _isLoading = true;
  AdaptiveMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _centerMapToUserLocation() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        _mapController?.animateTo(lastPos.latitude, lastPos.longitude, zoom: 15);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 4));

      if (mounted) {
        _mapController?.animateTo(pos.latitude, pos.longitude, zoom: 15);
      }
    } catch (_) {
      debugPrint('Fallback heatmap coordinates due to GPS status');
    }
  }

  Future<void> _loadHeatmapData() async {
    try {
      final firestore = ref.read(firestoreProvider);
      final snapshot = await firestore.collection('incidents').get();

      // Grid-based aggregation (ปัดค่า lat/lng เป็น grid ~100m)
      final Map<String, _HeatPoint> grid = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        // ปัด lat/lng เป็น grid ~100m (0.001 ≈ 111m)
        final gridLat = (lat * 1000).round() / 1000;
        final gridLng = (lng * 1000).round() / 1000;
        final key = '$gridLat,$gridLng';

        if (grid.containsKey(key)) {
          grid[key]!.count++;
          grid[key]!.sumLat += lat;
          grid[key]!.sumLng += lng;
        } else {
          grid[key] = _HeatPoint(lat: lat, lng: lng, count: 1, sumLat: lat, sumLng: lng);
        }
      }

      // คำนวณ max count สำหรับ normalize
      int maxCount = 1;
      for (final point in grid.values) {
        if (point.count > maxCount) maxCount = point.count;
      }

      // สร้าง circles
      final List<AdaptiveCircle> circles = [];
      for (final entry in grid.entries) {
        final point = entry.value;
        final avgLat = point.sumLat / point.count;
        final avgLng = point.sumLng / point.count;
        final intensity = point.count / maxCount; // 0.0 - 1.0

        circles.add(
          AdaptiveCircle(
            id: entry.key,
            lat: avgLat,
            lng: avgLng,
            radiusMeters: 50 + (intensity * 150), // 50-200m
            fillColor: _getHeatColor(intensity),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _heatCircles = circles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getHeatColor(double intensity) {
    if (intensity > 0.7) return Colors.red.withValues(alpha: 0.5);
    if (intensity > 0.4) return Colors.orange.withValues(alpha: 0.4);
    if (intensity > 0.2) return Colors.yellow.withValues(alpha: 0.35);
    return Colors.green.withValues(alpha: 0.25);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 แผนที่ความเสี่ยง (Heatmap)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                AdaptiveMapWidget(
                  initialLat: 14.9061,
                  initialLng: 102.0113,
                  initialZoom: 15,
                  circles: _heatCircles,
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _centerMapToUserLocation();
                  },
                ),
                // Legend
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ความถี่เหตุ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        _legendRow('สูงมาก', Colors.red),
                        _legendRow('สูง', Colors.orange),
                        _legendRow('ปานกลาง', Colors.yellow.shade700),
                        _legendRow('ต่ำ', Colors.green),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _HeatPoint {
  double lat;
  double lng;
  int count;
  double sumLat;
  double sumLng;

  _HeatPoint({required this.lat, required this.lng, required this.count, required this.sumLat, required this.sumLng});
}
