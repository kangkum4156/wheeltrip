import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Set<Marker>> loadMarkersFromFirestore(Function showBottomSheet) async {
  final snapshot = await FirebaseFirestore.instance.collection('places').get();
  return snapshot.docs.map((doc) {
    final data = doc.data();
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat == null || lng == null) return null;

    return Marker(
      markerId: MarkerId(doc.id),
      position: LatLng(lat.toDouble(), lng.toDouble()),
      onTap: () => showBottomSheet(data),
    );
  }).whereType<Marker>().toSet();
}