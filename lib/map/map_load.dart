import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Set<Marker>> loadMarkersFromFirestore(
    Function(LatLng) onLatLngTap, // 마커 클릭도 지도처럼 처리
    ) async {
  final snapshot = await FirebaseFirestore.instance.collection('places').get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    final lat = data['latitude'];
    final lng = data['longitude'];

    if (lat == null || lng == null) return null;

    final position = LatLng(lat.toDouble(), lng.toDouble());

    return Marker(
      markerId: MarkerId(doc.id),
      position: position,
      onTap: () {
        onLatLngTap(position); // 👈 마커 누르면 지도 탭처럼 처리
      },
    );
  }).whereType<Marker>().toSet();
}
