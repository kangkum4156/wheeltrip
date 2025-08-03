import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Set<Marker>> loadMarkersFromFirestore(
    Function(Map<String, dynamic>) onMarkerTap,
    ) async {
  final snapshot = await FirebaseFirestore.instance.collection('places').get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    final lat = data['latitude'];
    final lng = data['longitude'];

    if (lat == null || lng == null) return null;

    // Firestore 문서 ID를 함께 data에 추가
    final markerData = {
      'id': doc.id,
      ...data,
    };

    return Marker(
      markerId: MarkerId(doc.id),
      position: LatLng(lat.toDouble(), lng.toDouble()),
      onTap: () => onMarkerTap(markerData),
    );
  }).whereType<Marker>().toSet();
}
