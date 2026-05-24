import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../core/providers.dart';
import '../../core/constants.dart';
import '../../core/adaptive_map_widget.dart';
import '../../models/incident_model.dart';

/// Map Dashboard สำหรับ Dispatcher — v2: F6 Responder Markers + F7 animateToLatLng
/// แสดงหมุดเหตุ real-time + หมุด responder สีฟ้า บนแผนที่
/// รองรับ Windows ด้วย flutter_map (OpenStreetMap)
class MapDashboardScreen extends ConsumerStatefulWidget {

  /// Incident ที่ถูกเลือกจาก Panel → animate camera ไปที่หมุดนั้น
  final Incident? selectedIncident;

  /// Callback เมื่อ user กดหมุดบนแผนที่
  final void Function(Incident incident)? onMarkerTap;

  const MapDashboardScreen({
    super.key,
    this.selectedIncident,
    this.onMarkerTap,
  });

  @override
  ConsumerState<MapDashboardScreen> createState() => MapDashboardScreenState();
}

class MapDashboardScreenState extends ConsumerState<MapDashboardScreen> {

  AdaptiveMapController? _mapController;
  List<AdaptiveMarker> _incidentMarkers = [];
  List<AdaptiveMarker> _responderMarkers = [];
  StreamSubscription? _incidentSub;
  StreamSubscription? _responderSub;
  final Map<String, Incident> _incidentMap = {};

  @override
  void initState() {
    super.initState();
    _loadIncidentMarkers();
    _loadResponderMarkers(); // F6: เพิ่ม responder markers
  }

  @override
  void didUpdateWidget(covariant MapDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เมื่อมี incident ที่ถูกเลือกจาก Panel → animate camera ไป
    if (widget.selectedIncident != null &&
        widget.selectedIncident != oldWidget.selectedIncident) {
      _animateToIncident(widget.selectedIncident!);
    }
  }

  void _animateToIncident(Incident incident) {
    if (_mapController == null) return;
    if (incident.latitude == null || incident.longitude == null) return;

    _mapController!.animateTo(incident.latitude!, incident.longitude!, zoom: 17);
  }

  /// F7: Public method สำหรับ DispatcherScreen เรียก animate ไปยังจุดที่ต้องการ
  void animateToLatLng(double lat, double lng) {
    if (_mapController == null) return;
    _mapController!.animateTo(lat, lng, zoom: 17);
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
      debugPrint('Fallback coordinates on dispatcher dashboard map');
    }
  }

  Color _getColorByPriority(String priority) {
    switch (priority) {
      case 'CRITICAL':
        return Colors.purple;
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.yellow;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  void _loadIncidentMarkers() {
    final repo = ref.read(incidentRepositoryProvider);

    // v2: แสดงเหตุที่ยังไม่ RESOLVED (NEW + IN_PROGRESS)
    _incidentSub = repo.getIncidentsStreamByStatus([
      IncidentStatus.newCase,
      IncidentStatus.inProgress,
    ]).listen((snapshot) {
      final List<AdaptiveMarker> newMarkers = [];

      _incidentMap.clear();

      for (var doc in snapshot.docs) {
        final incident = Incident.fromFirestore(doc);
        _incidentMap[incident.id] = incident;

        if (incident.latitude == null || incident.longitude == null) continue;

        newMarkers.add(
          AdaptiveMarker(
            id: incident.id,
            lat: incident.latitude!,
            lng: incident.longitude!,
            title: incident.title,
            snippet: '${incident.priorityText} • ${incident.statusText}',
            color: _getColorByPriority(incident.priority),
            onTap: () {
              widget.onMarkerTap?.call(incident);
            },
          ),
        );
      }

      if (mounted) {
        setState(() {
          _incidentMarkers = newMarkers;
        });
      }
    });
  }

  /// F6: โหลด Responder markers สีฟ้า
  void _loadResponderMarkers() {
    final repo = ref.read(incidentRepositoryProvider);

    _responderSub = repo.getRespondersLocationStream().listen((snapshot) {
      final List<AdaptiveMarker> markers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lastLoc = data['lastLocation'] as Map<String, dynamic>?;
        if (lastLoc == null) continue;

        final lat = (lastLoc['lat'] as num?)?.toDouble();
        final lng = (lastLoc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final dept = data['department'] ?? '';
        final displayName = name.isNotEmpty ? name : (data['studentId'] ?? doc.id);

        markers.add(
          AdaptiveMarker(
            id: 'responder_${doc.id}',
            lat: lat,
            lng: lng,
            title: '🚑 $displayName',
            snippet: dept.isNotEmpty ? 'หน่วย: $dept' : 'ผู้ตอบสนอง',
            color: Colors.lightBlue,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _responderMarkers = markers;
        });
      }
    });
  }

  @override
  void dispose() {
    _incidentSub?.cancel();
    _responderSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // รวม markers ทั้ง incident + responder
    final allMarkers = <AdaptiveMarker>[..._incidentMarkers, ..._responderMarkers];

    return AdaptiveMapWidget(
      initialLat: 14.8818,
      initialLng: 102.0196, // พิกัดศูนย์กลาง มหาวิทยาลัยเทคโนโลยีสุรนารี (SUT Campus Center)
      initialZoom: 15,
      markers: allMarkers,
      myLocationEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;
        // ถ้ามี selectedIncident ตอนเปิด → animate ไปเลย
        if (widget.selectedIncident != null) {
          _animateToIncident(widget.selectedIncident!);
        } else if (_incidentMarkers.isNotEmpty) {
          // UX: แพนกล้องไปยังพิกัดจุดศูนย์กลางเฉลี่ยของเหตุการณ์จริงที่กำลังเกิดขึ้นทั้งหมด
          double totalLat = 0;
          double totalLng = 0;
          for (final m in _incidentMarkers) {
            totalLat += m.lat;
            totalLng += m.lng;
          }
          final avgLat = totalLat / _incidentMarkers.length;
          final avgLng = totalLng / _incidentMarkers.length;
          _mapController?.animateTo(avgLat, avgLng, zoom: 15);
        } else {
          _centerMapToUserLocation();
        }
      },
    );
  }
}
