// lib/road/route_recommender.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ✅ Tmap 도보 경로 사용 (피드백이 없는 기본 경로 후보용)
import 'package:wheeltrip/road/road_tmap.dart';

/// 경로(Polyline) 단위로 저장된 Firestore 'routes' + Tmap 기본 경로를 기반으로
/// - Firestore 경로: 평점 1점 포함 경로 제외 (subcollection feedbacks에서 rate==1 존재 시 제외)
/// - Tmap 기본 경로: avgRate=0 으로 후보에 포함(피드백 미반영)
/// - 후보 필터: 출발/도착과 유사한(근접) 경로만 후보로 사용 (Firestore 경로만 해당)
/// - 정렬: 평균 평점 내림차순, 같으면 총거리 오름차순
class RouteRecommender {
  /// start/end 에서 각각 첫/마지막 포인트까지의 허용 거리(m) — Firestore 경로 후보 필터용
  static const double endpointToleranceMeters = 200.0;

  /// 추천 경로를 반환: { id, avgRate(double), distance(double, m), points(List<LatLng>) }
  static Future<Map<String, dynamic>?> recommendBestRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final List<Map<String, dynamic>> candidates = [];

    // 1) Firestore 저장 경로들에서 후보 수집
    final routesSnap = await FirebaseFirestore.instance.collection('routes').get();

    for (final doc in routesSnap.docs) {
      final data = doc.data();
      final double avgRate = (data['avgRate'] ?? 0).toDouble();
      final List<dynamic> rawPoints = (data['points'] ?? []) as List<dynamic>;
      if (rawPoints.length < 2) continue;

      final List<LatLng> points = rawPoints
          .map((p) => LatLng(
        (p['lat'] as num).toDouble(),
        (p['lng'] as num).toDouble(),
      ))
          .toList();

      // a) 출발/도착 근접 필터 (정/역방향 모두 허용)
      final bool forwardOk =
          _distanceMeters(start, points.first) <= endpointToleranceMeters &&
              _distanceMeters(end, points.last) <= endpointToleranceMeters;
      final bool reverseOk =
          _distanceMeters(start, points.last) <= endpointToleranceMeters &&
              _distanceMeters(end, points.first) <= endpointToleranceMeters;

      if (!(forwardOk || reverseOk)) continue;

      // b) 평점 1점 포함 경로 제외 (avgRate만으로는 부족 → subcollection 조회)
      final oneStar = await _hasOneStar(doc.id);
      if (oneStar) continue;

      // c) 후보에 추가
      final double totalDist = _polylineLengthMeters(points);
      if (avgRate <= 0 && totalDist <= 0) continue; // 방어

      candidates.add({
        'id': doc.id,
        'avgRate': avgRate,
        'distance': totalDist,
        'points': (reverseOk && !forwardOk)
            ? List<LatLng>.from(points.reversed)
            : points,
      });
    }

    // 2) Tmap 기본 경로(피드백 없는 길)도 후보로 추가 (avgRate=0)
    try {
      final tmapPoints = await TmapService.getWalkingRoute(start, end);
      if (tmapPoints.isNotEmpty) {
        final double dist = _polylineLengthMeters(tmapPoints);
        candidates.add({
          'id': 'tmap_direct',      // 구분용 가짜 id
          'avgRate': 0.0,           // 피드백 미반영
          'distance': dist,
          'points': tmapPoints,
        });
      }
    } catch (_) {
      // Tmap 실패 시 무시하고 진행
    }

    if (candidates.isEmpty) return null;

    // 3) 정렬: 1순위 평균 평점 내림차순, 2순위 총거리 오름차순
    candidates.sort((a, b) {
      final int rateComp =
      (b['avgRate'] as double).compareTo(a['avgRate'] as double);
      if (rateComp != 0) return rateComp;
      return (a['distance'] as double).compareTo(b['distance'] as double);
    });

    return candidates.first;
  }

  /// routes/{routeId}/feedbacks 에 rate == 1 이 존재하는지 빠르게 체크
  static Future<bool> _hasOneStar(String routeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('routes')
        .doc(routeId)
        .collection('feedbacks')
        .where('rate', isEqualTo: 1)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// 두 좌표 사이 거리(m)
  static double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0; // meters
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final sa = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) *
            cos(_deg2rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(sa), sqrt(1 - sa));
    return R * c;
  }

  /// 폴리라인 전체 길이(m)
  static double _polylineLengthMeters(List<LatLng> pts) {
    double sum = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += _distanceMeters(pts[i], pts[i + 1]);
    }
    return sum;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
