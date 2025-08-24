import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RouteIconService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final iconMap = {
    "경사로": Icons.terrain_rounded,
    "계단": Icons.stairs_rounded,
    "넓은 길": Icons.add_road,
  };

  Future<Set<Marker>> getRouteMarkers() async {
    final Set<Marker> markers = {};

    final routesSnapshot = await _firestore.collection('routes').get();

    for (var routeDoc in routesSnapshot.docs) {
      final data = routeDoc.data();

      final List<dynamic> points = data['points'] ?? [];
      if (points.isEmpty) continue;

      // 중앙 인덱스 point
      final midpoint = _getMidPoint(points);

      // 표시 순서 명시
      final iconsOrder = ["경사로", "계단", "넓은 길"];

      final featureCounts = Map<String, dynamic>.from(data['featureCounts'] ?? {});

      // iconsOrder 기준으로 activeFeatures 필터링
      final icons = iconsOrder
          .where((feature) => featureCounts[feature] != null && featureCounts[feature] > 0)
          .map((f) => iconMap[f]!)
          .toList();

      if (icons.isEmpty) continue;

      final markericon = await createMarkerFromIcons(icons);

      markers.add(Marker(
        markerId: MarkerId(routeDoc.id),
        position: midpoint,
        icon: markericon,
        consumeTapEvents: false,
        infoWindow: const InfoWindow(title: '', snippet: ''),
      ));
    }

    return markers;
  }

  LatLng _getMidPoint(List<dynamic> points) {
    if (points.isEmpty) {
      throw ArgumentError("points 리스트가 비어있습니다.");
    }

    final midIndex = points.length ~/ 2;

    if (points.length.isOdd) {
      // ✅ 홀수 → 딱 중앙
      final midPoint = points[midIndex];
      return LatLng(midPoint['lat'], midPoint['lng']);
    } else {
      // ✅ 짝수 → 중앙 두 점 확인
      final p1 = points[midIndex - 1];
      final p2 = points[midIndex];
      final midLat = (p1['lat'] + p2['lat']) / 2;
      final midLng = (p1['lng'] + p2['lng']) / 2;
      return LatLng(midLat, midLng);
    }
  }

}

Future<BitmapDescriptor> createMarkerFromIcons(
    List<IconData> icons, {
      int size = 15,
      double spacing = 2,
    }) async {
  final totalWidth = (icons.length * size + (icons.length - 1) * spacing).toInt();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final paint = Paint();
  final textPainter = TextPainter(textDirection: TextDirection.ltr);

  for (int i = 0; i < icons.length; i++) {
    final dx = i * (size + spacing);

    // 둥근 모서리 사각형 배경
    paint.color = Colors.blue;
    final rect = Rect.fromLTWH(dx.toDouble(), 0, size.toDouble(), size.toDouble());
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3)); // 12는 모서리 반지름
    canvas.drawRRect(rrect, paint);

    // 아이콘
    final icon = icons[i];
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.8,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        dx + (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(totalWidth, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  return BitmapDescriptor.bytes(bytes);
}