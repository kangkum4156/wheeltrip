import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  late final StreamSubscription<DatabaseEvent> _locationSub;
  Set<Marker> _realtimeMarkers = {};

  @override
  void initState() {
    super.initState();

    _locationRef = FirebaseDatabase.instance.ref("real_location");

    _locationSub = _locationRef.onValue.listen((DatabaseEvent event) {
      final snapshot = event.snapshot;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final Set<Marker> updatedRealtimeMarkers = {};

        for (final entry in data.entries) {
          final uid = entry.key;
          if (uid == currentUser?.uid) continue;

          final userData = Map<String, dynamic>.from(entry.value);
          final latitude = userData['latitude'];
          final longitude = userData['longitude'];
          final name = userData['name'] ?? '이름 없음';

          if (latitude != null && longitude != null) {
            updatedRealtimeMarkers.add(
              Marker(
                markerId: MarkerId(uid),
                position: LatLng(latitude.toDouble(), longitude.toDouble()),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: name),
              ),
            );
          }
        }

        setState(() {
          _realtimeMarkers = updatedRealtimeMarkers;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combinedMarkers = <Marker>{};
    combinedMarkers.addAll(widget.initialMarkers); // 정적 마커
    combinedMarkers.addAll(_realtimeMarkers); // 실시간 마커

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.8880, 128.6106),
        zoom: 16,
      ),
      markers: combinedMarkers,
      onMapCreated: (controller) {
        _controller.complete(controller);
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
      onTap: widget.onTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
