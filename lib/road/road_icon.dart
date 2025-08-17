import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RouteIconService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final iconMap = {
    "경사로": Icons.terrain,
    "차도": Icons.directions_car,
    "인도": Icons.directions_walk,
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

      // featureCounts에서 값이 1 이상인 것만 필터
      final Map<String, dynamic> featureCounts = Map<String, dynamic>.from(
          data['featureCounts'] ?? {});
      final List<String> activeFeatures = featureCounts.entries
          .where((entry) => (entry.value ?? 0) > 0)
          .map((entry) => entry.key)
          .toList();

      // 아이콘 결정
      final icons = activeFeatures
          .map((f) => iconMap[f] ?? Icons.help_outline)
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
    final midIndex = (points.length ~/ 2);
    final midPoint = points[midIndex];
    return LatLng(midPoint['lat'], midPoint['lng']);
  }
}

Future<BitmapDescriptor> createMarkerFromIcons(
    List<IconData> icons, {
      int size = 60,
      double spacing = 5,
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
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12)); // 12는 모서리 반지름
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