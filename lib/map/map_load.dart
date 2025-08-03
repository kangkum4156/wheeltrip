import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Set<Marker>> loadMarkersFromFirestore(
    List<Map<String, dynamic>> savedPlaces,
    Function(LatLng) onLatLngTap,
    ) async {
  return savedPlaces.map((place) {
    final lat = place['latitude'];
    final lng = place['longtitude'];

    if (lat == null || lng == null) return null;

    final position = LatLng(lat.toDouble(), lng.toDouble());

    return Marker(
        markerId: MarkerId(place['id']??'${lat}_$lng'), /// ID 없을 경우 좌표처리
        position: position,
        onTap: () {
          onLatLngTap(position); /// 마커 누르면 지도 탭처럼 처리
        }
    );
  }).whereType<Marker>().toSet();
}