import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Google Maps (mobile)
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

// flutter_map (desktop)
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;

/// Checks if we're running on a desktop platform where google_maps_flutter is not supported.
bool get isDesktopPlatform {
  if (kIsWeb) return true;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Unified marker data used by the adaptive map.
class AdaptiveMarker {
  final String id;
  final double lat;
  final double lng;
  final String? title;
  final String? snippet;
  final Color color;
  final VoidCallback? onTap;

  const AdaptiveMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.title,
    this.snippet,
    this.color = Colors.red,
    this.onTap,
  });
}

/// Unified circle overlay data.
class AdaptiveCircle {
  final String id;
  final double lat;
  final double lng;
  final double radiusMeters;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  const AdaptiveCircle({
    required this.id,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.fillColor = const Color(0x40FF0000),
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
  });
}

/// Unified polyline data.
class AdaptivePolyline {
  final String id;
  final List<LatLngPoint> points;
  final Color color;
  final double width;
  final bool isDashed;

  const AdaptivePolyline({
    required this.id,
    required this.points,
    this.color = Colors.blue,
    this.width = 4,
    this.isDashed = false,
  });
}

/// Simple lat/lng point (no dependency on any map library).
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
}

/// Callback for when the map is created – provides an [AdaptiveMapController].
typedef OnAdaptiveMapCreated = void Function(AdaptiveMapController controller);

/// Wrapper around map controllers for both platforms.
class AdaptiveMapController {
  gmap.GoogleMapController? _googleController;
  fmap.MapController? _flutterMapController;

  AdaptiveMapController._google(this._googleController);
  AdaptiveMapController._flutter(this._flutterMapController);

  /// Animate camera to a specific location.
  void animateTo(double lat, double lng, {double zoom = 17}) {
    if (_googleController != null) {
      _googleController!.animateCamera(
        gmap.CameraUpdate.newCameraPosition(
          gmap.CameraPosition(target: gmap.LatLng(lat, lng), zoom: zoom),
        ),
      );
    } else if (_flutterMapController != null) {
      _flutterMapController!.move(ll.LatLng(lat, lng), zoom);
    }
  }

  /// Animate camera to show a bounding box.
  void animateToBounds(double swLat, double swLng, double neLat, double neLng, {double padding = 80}) {
    if (_googleController != null) {
      _googleController!.animateCamera(
        gmap.CameraUpdate.newLatLngBounds(
          gmap.LatLngBounds(
            southwest: gmap.LatLng(swLat, swLng),
            northeast: gmap.LatLng(neLat, neLng),
          ),
          padding,
        ),
      );
    } else if (_flutterMapController != null) {
      _flutterMapController!.fitCamera(
        fmap.CameraFit.bounds(
          bounds: fmap.LatLngBounds(
            ll.LatLng(swLat, swLng),
            ll.LatLng(neLat, neLng),
          ),
          padding: EdgeInsets.all(padding),
        ),
      );
    }
  }

  void dispose() {
    _googleController?.dispose();
    _googleController = null;
    _flutterMapController?.dispose();
    _flutterMapController = null;
  }
}

/// A cross-platform map widget.
/// - On Android/iOS: uses Google Maps
/// - On Windows/macOS/Linux: uses flutter_map with OpenStreetMap tiles
class AdaptiveMapWidget extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final List<AdaptiveMarker> markers;
  final List<AdaptiveCircle> circles;
  final List<AdaptivePolyline> polylines;
  final bool myLocationEnabled;
  final bool zoomControlsEnabled;
  final OnAdaptiveMapCreated? onMapCreated;

  const AdaptiveMapWidget({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 15,
    this.markers = const [],
    this.circles = const [],
    this.polylines = const [],
    this.myLocationEnabled = true,
    this.zoomControlsEnabled = true,
    this.onMapCreated,
  });

  @override
  State<AdaptiveMapWidget> createState() => _AdaptiveMapWidgetState();
}

class _AdaptiveMapWidgetState extends State<AdaptiveMapWidget> {
  fmap.MapController? _fmapController;

  @override
  void initState() {
    super.initState();
    if (isDesktopPlatform) {
      _fmapController = fmap.MapController();
    }
  }

  @override
  void dispose() {
    _fmapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform) {
      return _buildFlutterMap();
    } else {
      return _buildGoogleMap();
    }
  }

  // ─── Google Maps (Android / iOS) ─────────────────────────

  Widget _buildGoogleMap() {
    return gmap.GoogleMap(
      initialCameraPosition: gmap.CameraPosition(
        target: gmap.LatLng(widget.initialLat, widget.initialLng),
        zoom: widget.initialZoom,
      ),
      markers: widget.markers.map((m) {
        return gmap.Marker(
          markerId: gmap.MarkerId(m.id),
          position: gmap.LatLng(m.lat, m.lng),
          icon: _colorToBitmapDescriptor(m.color),
          infoWindow: gmap.InfoWindow(
            title: m.title ?? '',
            snippet: m.snippet ?? '',
          ),
          onTap: m.onTap,
        );
      }).toSet(),
      circles: widget.circles.map((c) {
        return gmap.Circle(
          circleId: gmap.CircleId(c.id),
          center: gmap.LatLng(c.lat, c.lng),
          radius: c.radiusMeters,
          fillColor: c.fillColor,
          strokeWidth: c.borderWidth.toInt(),
          strokeColor: c.borderColor,
        );
      }).toSet(),
      polylines: widget.polylines.map((p) {
        return gmap.Polyline(
          polylineId: gmap.PolylineId(p.id),
          points: p.points.map((pt) => gmap.LatLng(pt.lat, pt.lng)).toList(),
          color: p.color,
          width: p.width.toInt(),
          patterns: p.isDashed
              ? [gmap.PatternItem.dash(20), gmap.PatternItem.gap(10)]
              : [],
        );
      }).toSet(),
      myLocationEnabled: widget.myLocationEnabled,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        widget.onMapCreated?.call(AdaptiveMapController._google(controller));
      },
    );
  }

  gmap.BitmapDescriptor _colorToBitmapDescriptor(Color color) {
    if (color == Colors.red) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed);
    } else if (color == Colors.blue || color == Colors.lightBlue || color == Colors.cyan) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueAzure);
    } else if (color == Colors.green) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen);
    } else if (color == Colors.yellow || color == Colors.amber) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueYellow);
    } else if (color == Colors.orange) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueOrange);
    } else if (color == Colors.purple || color == Colors.deepPurple) {
      return gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueViolet);
    }
    return gmap.BitmapDescriptor.defaultMarker;
  }

  // ─── flutter_map (Windows / macOS / Linux) ──────────────

  Widget _buildFlutterMap() {
    return fmap.FlutterMap(
      mapController: _fmapController,
      options: fmap.MapOptions(
        initialCenter: ll.LatLng(widget.initialLat, widget.initialLng),
        initialZoom: widget.initialZoom,
        onMapReady: () {
          if (_fmapController != null) {
            widget.onMapCreated?.call(
              AdaptiveMapController._flutter(_fmapController),
            );
          }
        },
      ),
      children: [
        // OSM Tile layer
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.campus.incident',
          maxZoom: 19,
        ),

        // Circles
        if (widget.circles.isNotEmpty)
          fmap.CircleLayer(
            circles: widget.circles.map((c) {
              return fmap.CircleMarker(
                point: ll.LatLng(c.lat, c.lng),
                radius: c.radiusMeters,
                useRadiusInMeter: true,
                color: c.fillColor,
                borderColor: c.borderColor,
                borderStrokeWidth: c.borderWidth,
              );
            }).toList(),
          ),

        // Polylines
        if (widget.polylines.isNotEmpty)
          fmap.PolylineLayer(
            polylines: widget.polylines.map<fmap.Polyline<Object>>((p) {
              return fmap.Polyline<Object>(
                points: p.points.map((pt) => ll.LatLng(pt.lat, pt.lng)).toList(),
                color: p.color,
                strokeWidth: p.width,
                pattern: p.isDashed ? const fmap.StrokePattern.dotted() : const fmap.StrokePattern.solid(),
              );
            }).toList(),
          ),

        // Markers
        if (widget.markers.isNotEmpty)
          fmap.MarkerLayer(
            markers: widget.markers.map((m) {
              return fmap.Marker(
                point: ll.LatLng(m.lat, m.lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    // Show info and trigger callback
                    m.onTap?.call();
                    if (m.title != null && m.title!.isNotEmpty) {
                      _showMarkerInfo(m);
                    }
                  },
                  child: Tooltip(
                    message: '${m.title ?? ''}${m.snippet != null ? '\n${m.snippet}' : ''}',
                    child: Icon(
                      Icons.location_on,
                      color: m.color,
                      size: 36,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showMarkerInfo(AdaptiveMarker marker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(marker.title ?? ''),
        content: marker.snippet != null ? Text(marker.snippet!) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
