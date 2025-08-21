// lib/road/road_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:wheeltrip/road/road_save_load.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:wheeltrip/road/road_tmap.dart';
import 'package:wheeltrip/road/road_new.dart';
import 'package:wheeltrip/road/road_poly_tap.dart';
import 'package:wheeltrip/profile/profile_marker.dart';
import 'package:wheeltrip/road/road_icon.dart';

// ✅ 추천 경로 로직
import 'package:wheeltrip/road/route_recommender.dart';

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

  final RouteIconService routeIconService = RouteIconService();

  // ✅ 친구(연결된 사람) 마커들
  final Set<Marker> _friendMarkers = {};
  final DatabaseReference _locationRef =
  FirebaseDatabase.instance.ref('real_location');
  StreamSubscription<DatabaseEvent>? _locationSub;
  Set<String> _allowedEmails = {};
  late final ProfileMarkerCache _markerHelper;

  // feature 마커
  final Set<Marker> _featureMarkers = {};

  List<Map<String, dynamic>> loadedRoutes = [];

  @override
  void initState() {
    super.initState();
    _markerHelper = ProfileMarkerCache();
    _initFriendsMarkers();
    _loadAndDisplayRoutes();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _initFriendsMarkers() async {
    final myEmail = FirebaseAuth.instance.currentUser?.email;
    if (myEmail == null || myEmail.isEmpty) return;

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('counter_email', arrayContains: myEmail)
          .get();

      _allowedEmails = q.docs.map((d) => d.id.toLowerCase()).toSet();
      _allowedEmails.remove(myEmail.toLowerCase());

      await _markerHelper.warmProfileUrls(_allowedEmails);

      await _locationSub?.cancel();
      _locationSub = _locationRef.onValue.listen(_onLocationEvent);
    } catch (e) {
      debugPrint('friends load failed: $e');
      if (!mounted) return;
      setState(() {
        _allowedEmails = {};
        _friendMarkers.clear();
      });
    }
  }

  Future<void> _onLocationEvent(DatabaseEvent event) async {
    final snap = event.snapshot;
    if (!snap.exists || snap.value is! Map) {
      if (!mounted) return;
      setState(() => _friendMarkers.clear());
      return;
    }

    final map = Map<String, dynamic>.from(snap.value as Map);
    final next = <Marker>{};
    final futures = <Future<Marker?>>[];

    for (final entry in map.entries) {
      final v = entry.value;
      if (v is! Map) continue;

      final userData = Map<String, dynamic>.from(v);
      final email = (userData['email'] as String?)?.toLowerCase();
      final lat = (userData['latitude'] as num?)?.toDouble();
      final lng = (userData['longitude'] as num?)?.toDouble();
      final name = (userData['name'] as String?) ?? '이름 없음';

      if (email == null || !_allowedEmails.contains(email)) continue;
      if (lat == null || lng == null) continue;

      futures.add(() async {
        final icon = await _markerHelper.markerFor(email, size: 112);
        return Marker(
          markerId: MarkerId('friend_$email'),
          position: LatLng(lat, lng),
          icon: icon,
          infoWindow: InfoWindow(title: name), // 이메일 표시 X
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 100, // 폴리라인 위로
        );
      }());
    }

    final built = await Future.wait(futures);
    for (final m in built) {
      if (m != null) next.add(m);
    }

    if (!mounted) return;
    setState(() {
      _friendMarkers
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _loadAndDisplayRoutes() async {
    loadedRoutes = await RoadFirestoreService.loadRoutes();

    final loadedPolylines = <Polyline>{};

    for (var route in loadedRoutes) {
      loadedPolylines.add(
        Polyline(
          polylineId: PolylineId(route['id']),
          points: route['points'],
          width: 7,
          color: RoadFirestoreService.getPolylineColor(route['avgRate']),
          consumeTapEvents: true,
          onTap: () =>
              onPolylineTap(
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

    // 2️⃣ feature 마커 처리
    final featureMarkers = await routeIconService.getRouteMarkers();

    if (!mounted) return;
    setState(() {
      polylines = loadedPolylines;
      // 친구 마커와 feature 마커 합치기
      _featureMarkers.clear();
      _featureMarkers.addAll(featureMarkers);
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

    if (!mounted) return;
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
              context: context,
              routeId: result['id'],
              coords: coords,
              avgRate: result['avgRate'],
              userEmail: user_email,
              reloadRoutes: _loadAndDisplayRoutes,
            );
          },
        ),
      );

      // 새 경로 저장 후 입력 상태 초기화
      startPoint = null;
      endPoint = null;
      circles.clear();
    });
    // ✅ 저장 후 feature 마커 갱신
    await _loadAndDisplayRoutes();
  }

  Future<void> _getRoute() async {
    if (startPoint == null || endPoint == null) return;

    final coords = await TmapService.getWalkingRoute(startPoint!, endPoint!);
    if (coords.isEmpty) return;

    final tempPolyline = Polyline(
      polylineId: const PolylineId('temp'),
      points: coords,
      width: 8,
      color: Colors.blueAccent.withAlpha((255 * 0.7).round()),
    );

    setState(() {
      polylines.add(tempPolyline);
    });

    if (_mapController != null) {
      final lat = (startPoint!.latitude + endPoint!.latitude) / 2 - 0.0005;
      final lng = (startPoint!.longitude + endPoint!.longitude) / 2;
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: 17),
          ),
        );
      } catch (_) {}
    }
  }

  /// ✅ 추천 경로 찾기 & 지도에 표시
  Future<void> _recommendAndShow() async {
    if (startPoint == null || endPoint == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지도를 두 번 탭해서 출발지와 도착지를 먼저 지정해 주세요.')),
      );
      return;
    }

    final best = await RouteRecommender.recommendBestRoute(
      start: startPoint!,
      end: endPoint!,
    );

    if (!mounted) return;

    if (best == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추천할 수 있는 경로가 없습니다. (평점 1 포함/근접 경로 없음)')),
      );
      return;
    }

    final List<LatLng> pts = List<LatLng>.from(best['points']);
    final avg = best['avgRate'] as double;
    final dist = best['distance'] as double;

    // 기존 추천 폴리라인 제거 후 추가
    setState(() {
      polylines.removeWhere((p) => p.polylineId.value == 'recommended');
      polylines.add(Polyline(
        polylineId: const PolylineId('recommended'),
        points: pts,
        color: Colors.purpleAccent,
        width: 10,
        zIndex: 999,
      ));
    });

    // 화면 맞춤
    if (_mapController != null && pts.isNotEmpty) {
      final bounds = _boundsFromLatLngList(pts);
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text('추천 경로: ★ ${avg.toStringAsFixed(1)}  /  ${dist.toStringAsFixed(0)} m'),
      ),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (final latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(x0!, y0!),
      northeast: LatLng(x1!, y1!),
    );
  }

  void _resetSelection() {
    setState(() {
      polylines.removeWhere((p) => p.polylineId.value == 'temp');
      startPoint = null;
      endPoint = null;
      circles.clear();
    });
  }

  void _onMapTap(LatLng pos) {
    final adjustedPos = LatLng(pos.latitude + 0.00001, pos.longitude - 0.00001);

    setState(() {
      if (startPoint == null) {
        startPoint = adjustedPos;
        circles.add(
          Circle(
            circleId: const CircleId('start'),
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
            circleId: const CircleId('end'),
            center: adjustedPos,
            radius: 5,
            fillColor: Colors.red.withAlpha((255 * 0.8).round()),
            strokeColor: Colors.red,
            strokeWidth: 1,
          ),
        );
        // ✅ 출발/도착 지정 완료 → 임시 경로 띄우면서 바텀시트 띄우기
        _getRoute();
        _showRouteOptionSheet();
      }
    });
  }

  /// ✅ 추천 경로/피드백 등록 선택 바텀시트
  Future<void> _showRouteOptionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '무엇을 할까요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('선택한 출발지와 도착지로…'),
                const SizedBox(height: 16),
                // 추천 경로 쓸거면 여기에 아래 elevated 버튼 재할당 필요

                // 피드백 등록
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_comment),
                    label: const Text('피드백 등록'),
                    onPressed: () async {
                      Navigator.pop(context, true);
                      // _getRouteAndSave 기능을 여기서 따로 작성해서 사용
                      final saved = await showNewBottomSheet(
                        context: context,
                        coords: polylines
                            .firstWhere((p) => p.polylineId.value == 'temp')
                            .points,
                        onRouteSaved: (coords, rate, features) async {
                          await _saveNewRoute(coords, rate, features);
                        },
                      );

                      if (saved != true) {
                        _resetSelection();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context,false);
                  },
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        );
      },
    );
    // ✅ 바텀시트 닫힌 뒤 결과 처리
    if (result != true) {
      _resetSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: _onMapTap,
        circles: circles,
        polylines: polylines,
        // ✅ 친구 프로필 마커 표시
        markers: _friendMarkers.union(_featureMarkers),
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.8880, 128.6106),
          zoom: 17,
        ),
      ),
    );
  }
}
