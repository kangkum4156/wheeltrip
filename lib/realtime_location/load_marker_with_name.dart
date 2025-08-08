import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  Set<Marker> _realtimeMarkers = {};
  Set<String> _allowedEmails = {};

  @override
  void initState() {
    super.initState();
    _locationRef = FirebaseDatabase.instance.ref("real_location");
    _initAndSubscribe();
  }

  Future<void> _initAndSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    final myEmail = user?.email;
    if (myEmail == null || myEmail.isEmpty) return;

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('counter_email', arrayContains: myEmail)
          .get();

      _allowedEmails = q.docs.map((d) => d.id.toLowerCase()).toSet();

      _allowedEmails.remove(myEmail.toLowerCase());

      await _locationSub?.cancel();
      _locationSub = _locationRef.onValue.listen(_onLocationEvent);
    } catch (e) {
      debugPrint('Failed to load allowed emails: $e');
      setState(() {
        _allowedEmails = {};
        _realtimeMarkers = {};
      });
    }
  }

  void _onLocationEvent(DatabaseEvent event) {
    final snap = event.snapshot;
    if (!snap.exists || snap.value is! Map) {
      setState(() => _realtimeMarkers = {});
      return;
    }

    final map = Map<String, dynamic>.from(snap.value as Map);
    final next = <Marker>{};

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

      next.add(
        Marker(
          markerId: MarkerId(entry.key),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: name),
        ),
      );
    }

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
