import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

typedef OnCrosspointTap = void Function(LatLng point, String name);

class RoadCrossMarkers {
  static final _firestore = FirebaseFirestore.instance;

  /// 마커 아이콘 생성
  static Future<BitmapDescriptor> _createCircleMarker({
    double size = 50,
    Color fillColor = Colors.blue,
    Color borderColor = Colors.white,
    double borderWidth = 3,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    // 내부 원
    paint.color = fillColor;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - borderWidth,
      paint,
    );

    // 테두리
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = borderColor;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - borderWidth, paint);

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// 교차로 마커 로드
  static Future<Set<Marker>> loadCrosspoints({
    LatLng? selectedStart,
    LatLng? selectedEnd,
    required OnCrosspointTap onTap,
  }) async {
    final snapshot = await _firestore.collection('crosspoints').get();
    final markers = <Marker>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      final name = data['name'] ?? '교차로';
      final pos = LatLng(lat, lng);

      final color = (selectedStart == pos)
          ? Colors.green
          : (selectedEnd == pos)
          ? Colors.red
          : Colors.blue;

      final icon = await _createCircleMarker(
        size: 35,
        fillColor: color,
        borderColor: Colors.white,
        borderWidth: 3,
      );

      markers.add(
        Marker(
          markerId: MarkerId("cross_${doc.id}"),
          position: pos,
          icon: icon,
          onTap: () => onTap(pos, name),
        ),
      );
    }

    return markers;
  }
}