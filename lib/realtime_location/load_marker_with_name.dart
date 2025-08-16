// lib/map/real_time_map_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 공용 프로필 마커 유틸 사용
import 'package:wheeltrip/profile/profile_marker.dart';

class RealTimeMapController extends StatefulWidget {
  final Set<Marker> initialMarkers;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(LatLng)? onTap;

  const RealTimeMapController({
    super.key,
    required this.initialMarkers,
    this.onMapCreated,
    this.onTap,
  });

  @override
  State<RealTimeMapController> createState() => _RealTimeMapControllerState();
}

class _RealTimeMapControllerState extends State<RealTimeMapController> {
  final Completer<GoogleMapController> _controller = Completer();
  late final DatabaseReference _locationRef;
  StreamSubscription<DatabaseEvent>? _locationSub;

  // ✅ 친구(연결된 사람) 마커 관리
  Set<Marker> _realtimeMarkers = {};
  Set<String> _allowedEmails = {};

  // ✅ 공용 마커 헬퍼 (파란 테두리, 기본 프로필 포함)
  late final ProfileMarkerCache _profileMarkers;

  @override
  void initState() {
    super.initState();
    _profileMarkers = ProfileMarkerCache();
    _locationRef = FirebaseDatabase.instance.ref("real_location");
    _initAndSubscribe();
  }

  Future<void> _initAndSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    final myEmail = user?.email;
    if (myEmail == null || myEmail.isEmpty) return;

    try {
      // 나를 counter_email 배열에 가진 상대만 표시
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('counter_email', arrayContains: myEmail)
          .get();

      _allowedEmails = q.docs.map((d) => d.id.toLowerCase()).toSet();
      _allowedEmails.remove(myEmail.toLowerCase());

      // ✅ 상대 프로필 URL 미리 캐시(없으면 null 저장)
      await _profileMarkers.warmProfileUrls(_allowedEmails);

      await _locationSub?.cancel();
      _locationSub = _locationRef.onValue.listen(_onLocationEvent);
    } catch (e) {
      debugPrint('Failed to load allowed emails: $e');
      if (!mounted) return;
      setState(() {
        _allowedEmails = {};
        _realtimeMarkers = {};
      });
    }
  }

  Future<void> _onLocationEvent(DatabaseEvent event) async {
    final snap = event.snapshot;
    if (!snap.exists || snap.value is! Map) {
      if (!mounted) return;
      setState(() => _realtimeMarkers = {});
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
        final icon = await _profileMarkers.markerFor(email, size: 112);
        return Marker(
          markerId: MarkerId('rt_$email'),
          position: LatLng(lat, lng),
          icon: icon,
          // 이메일은 표시하지 않음(요청 사항)
          infoWindow: InfoWindow(title: name),
          anchor: const Offset(0.5, 0.5),
          zIndex: 100.0, // 위에 보이도록
        );
      }());
    }

    final built = await Future.wait(futures);
    for (final m in built) {
      if (m != null) next.add(m);
    }

    if (!mounted) return;
    setState(() => _realtimeMarkers = next);
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combined = <Marker>{...widget.initialMarkers, ..._realtimeMarkers};
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.8880, 128.6106),
        zoom: 16,
      ),
      markers: combined,
      onMapCreated: (controller) {
        _controller.complete(controller);
        widget.onMapCreated?.call(controller);
      },
      onTap: widget.onTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
