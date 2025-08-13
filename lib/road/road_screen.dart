import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/road/road_save_load.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:wheeltrip/road/road_tmap.dart';
import 'package:wheeltrip/road/road_new.dart';
import 'package:wheeltrip/road/road_poly_tap.dart';

class RoadScreen extends StatefulWidget {
  const RoadScreen({super.key});

  @override
  RoadScreenState createState() => RoadScreenState();
}

class RoadScreenState extends State<RoadScreen> {
  GoogleMapController? _mapController;
  LatLng? startPoint;
  LatLng? endPoint;

  Set<Circle> circles = {};
  Set<Polyline> polylines = {};

  List<Map<String, dynamic>> loadedRoutes = [];

  @override
  void initState() {
    super.initState();
    _loadAndDisplayRoutes();
  }

  Future<void> _loadAndDisplayRoutes() async {
    loadedRoutes = await RoadFirestoreService.loadRoutes();

    Set<Polyline> loadedPolylines = {};

    for (var route in loadedRoutes) {
      loadedPolylines.add(
        Polyline(
          polylineId: PolylineId(route['id']),
          points: route['points'],
          width: 7,
          color: RoadFirestoreService.getPolylineColor(route['avgRate']),
          consumeTapEvents: true,
          onTap:
              () => onPolylineTap(
                mapController: _mapController,
                context: context,
                routeId: route['id'],
                coords: route['points'],
                avgRate: route['avgRate'],
                userEmail: user_email,
                reloadRoutes: _loadAndDisplayRoutes,
              ),
        ),
      );
    }

    setState(() {
      polylines = loadedPolylines;
    });
  }

  Future<void> _saveNewRoute(
    List<LatLng> coords,
    int rate,
    List<String> feature,
  ) async {
    final result = await RoadFirestoreService.saveNewRoute(
      userEmail: user_email,
      coords: coords,
      rate: rate,
      features: feature,
    );

    setState(() {
      polylines.add(
        Polyline(
          polylineId: PolylineId(result['id']),
          points: coords,
          width: 7,
          color: RoadFirestoreService.getPolylineColor(result['avgRate']),
          consumeTapEvents: true,
          onTap: () async {
            await onPolylineTap(
              mapController: _mapController,
              context: this.context,
              routeId: result['id'],
              coords: coords,
              avgRate: result['avgRate'],
              userEmail: user_email,
              reloadRoutes: _loadAndDisplayRoutes,
            );
          },
        ),
      );

      startPoint = null;
      endPoint = null;
      circles.clear();
    });
  }

  Future<void> _getRouteAndSave() async {
    // onMapTap 후 새 경로 생성
    if (startPoint == null || endPoint == null) return;

    final coords = await TmapService.getWalkingRoute(startPoint!, endPoint!);
    if (coords.isEmpty) return;

    final tempPolyline = Polyline(
      polylineId: PolylineId('temp'),
      points: coords,
      width: 8,
      color: Colors.blueAccent.withAlpha((255 * 0.7).round()),
    );

    setState(() {
      polylines.add(tempPolyline);
    });

    if (_mapController != null) {
      final lat = (startPoint!.latitude + endPoint!.latitude) / 2- 0.0005;
      final lng = (startPoint!.longitude + endPoint!.longitude) / 2;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 17),
        ),
      );
    }

    bool? saved = await showNewBottomSheet(
      context: context,
      coords: coords,
      onRouteSaved: (coords, rate, features) async {
        await _saveNewRoute(coords, rate, features);
      },
    );

    if (saved != true) {
      setState(() {
        polylines.removeWhere((p) => p.polylineId.value == 'temp');
        startPoint = null;
        endPoint = null;
        circles.clear();
      });
    }
  }

  void _onMapTap(LatLng pos) {
    final adjustedPos = LatLng(pos.latitude + 0.00001, pos.longitude - 0.00001);

    setState(() {
      if (startPoint == null) {
        startPoint = adjustedPos;
        circles.add(
          Circle(
            circleId: CircleId('start'),
            center: adjustedPos,
            radius: 5,
            fillColor: Colors.green.withAlpha((255 * 0.8).round()),
            strokeColor: Colors.green,
            strokeWidth: 1,
          ),
        );
      } else if (endPoint == null) {
        endPoint = adjustedPos;
        circles.add(
          Circle(
            circleId: CircleId('end'),
            center: adjustedPos,
            radius: 5,
            fillColor: Colors.red.withAlpha((255 * 0.8).round()),
            strokeColor: Colors.red,
            strokeWidth: 1,
          ),
        );
        _getRouteAndSave();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true, // 내 위치 표시
        myLocationButtonEnabled: true, // 내 위치로 돌아가는 버튼 표시
        onTap: _onMapTap,
        circles: circles,
        polylines: polylines,
        initialCameraPosition: CameraPosition(
          target: LatLng(35.8880, 128.6106),
          zoom: 17,
        ),
      ),
    );
  }
}
