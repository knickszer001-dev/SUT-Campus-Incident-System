import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../core/adaptive_map_widget.dart';

/// Navigator Screen — F6 / 3.2
/// แผนที่นำทางแบบ Grab: ตำแหน่งปัจจุบัน → จุดเกิดเหตุ
/// + ปุ่มเปิด Google Maps ภายนอก
/// รองรับ Windows ด้วย flutter_map (OpenStreetMap)
class NavigatorScreen extends StatefulWidget {

  final double destinationLat;
  final double destinationLng;
  final String incidentTitle;

  const NavigatorScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.incidentTitle,
  });

  @override
  State<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends State<NavigatorScreen> {

  AdaptiveMapController? _mapController;
  Position? _currentPosition;
  List<AdaptiveMarker> _markers = [];
  List<AdaptivePolyline> _polylines = [];

  StreamSubscription<Position>? _positionSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ไม่ได้รับอนุญาตใช้ตำแหน่ง")),
          );
        }
        return;
      }

      // ดึงตำแหน่งปัจจุบัน
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _updateMarkersAndRoute();

      // Live tracking ตำแหน่ง
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // อัปเดตทุก 10 เมตร
        ),
      ).listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _updateMarkersAndRoute();
        }
      });

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ไม่สามารถดึงตำแหน่งได้ กรุณาเปิด GPS")),
        );
      }
    }
  }

  void _updateMarkersAndRoute() {
    if (_currentPosition == null) return;

    final myLat = _currentPosition!.latitude;
    final myLng = _currentPosition!.longitude;

    setState(() {
      _markers = [
        AdaptiveMarker(
          id: 'me',
          lat: myLat,
          lng: myLng,
          title: "ตำแหน่งของฉัน",
          color: Colors.lightBlue,
        ),
        AdaptiveMarker(
          id: 'destination',
          lat: widget.destinationLat,
          lng: widget.destinationLng,
          title: widget.incidentTitle,
          color: Colors.red,
        ),
      ];

      // เส้นตรง (simplified route — ไม่ใช้ Directions API)
      _polylines = [
        AdaptivePolyline(
          id: 'route',
          points: [
            LatLngPoint(myLat, myLng),
            LatLngPoint(widget.destinationLat, widget.destinationLng),
          ],
          color: Colors.blue,
          width: 4,
          isDashed: true,
        ),
      ];
    });

    // ซูมให้เห็นทั้ง 2 จุด
    final swLat = myLat < widget.destinationLat ? myLat : widget.destinationLat;
    final swLng = myLng < widget.destinationLng ? myLng : widget.destinationLng;
    final neLat = myLat > widget.destinationLat ? myLat : widget.destinationLat;
    final neLng = myLng > widget.destinationLng ? myLng : widget.destinationLng;

    _mapController?.animateToBounds(swLat, swLng, neLat, neLng, padding: 80);
  }

  /// 3.3: เปิด Google Maps ภายนอก (นำทางจริง)
  Future<void> _openExternalNavigation() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${widget.destinationLat},${widget.destinationLng}'
      '&travelmode=driving'
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ไม่สามารถเปิด Google Maps ได้")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("เกิดข้อผิดพลาด กรุณาลองใหม่")),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("🧭 นำทาง")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("กำลังค้นหาตำแหน่ง..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("🧭 นำทาง: ${widget.incidentTitle}"),
      ),
      body: Stack(
        children: [
          AdaptiveMapWidget(
            initialLat: _currentPosition != null
                ? _currentPosition!.latitude
                : widget.destinationLat,
            initialLng: _currentPosition != null
                ? _currentPosition!.longitude
                : widget.destinationLng,
            initialZoom: 15,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _updateMarkersAndRoute();
              }
            },
          ),

          // ปุ่มเปิด Google Maps ภายนอก
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text("เปิดนำทางใน Google Maps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _openExternalNavigation,
            ),
          ),

          // แสดงระยะทาง
          if (_currentPosition != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.directions, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        "ระยะทาง: ${_calculateDistance()} ม.",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _calculateDistance() {
    if (_currentPosition == null) return '-';
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destinationLat,
      widget.destinationLng,
    );
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} กม.';
    }
    return distance.toStringAsFixed(0);
  }
}
