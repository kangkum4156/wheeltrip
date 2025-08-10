import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class RoadFirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  /// 새로운 경로 저장: routes + users/{userEmail}/my_routes 모두 저장
  static Future<Map<String, dynamic>> saveNewRoute({
    required String? userEmail,
    required List<LatLng> coords,
    required int rate,
  }) async {
    final routesRef = _firestore.collection('routes');
    final usersRoutesRef = _firestore.collection('users').doc(userEmail).collection('my_routes');

    // routes에 새 문서 생성 (ID 자동 생성)
    final newRouteDoc = await routesRef.add({
      'points': coords.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'avgRate': rate.toDouble(),
      'rateCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // users/{userEmail}/my_routes에도 같은 문서 저장 (routeId를 docID로)
    await usersRoutesRef.doc(newRouteDoc.id).set({
      'points': coords.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'rate': rate,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': newRouteDoc.id,
      'points': coords,
      'avgRate': rate.toDouble(),
      'rateCount': 1,
    };
  }

  /// 사용자 경로 평점 수정 또는 신규 저장
  /// routes 문서의 avgRate, rateCount 갱신 처리 (기존 평점 수정 시 기존 점수 차감 후 재계산)
  static Future<Map<String, dynamic>> saveOrUpdateUserRate({
    required String? userEmail,
    required String routeId,
    required List<LatLng> coords,
    required int newRate,
  }) async {
    final routesRef = _firestore.collection('routes').doc(routeId);
    final userRouteRef = _firestore.collection('users').doc(userEmail).collection('my_routes').doc(routeId);

    final routeDoc = await routesRef.get();
    if (!routeDoc.exists) {
      throw Exception('Route document not found');
    }

    final userRouteDoc = await userRouteRef.get();

    double avgRate = (routeDoc.data()?['avgRate'] ?? 0).toDouble();
    int rateCount = (routeDoc.data()?['rateCount'] ?? 0);

    int oldRate = 0;
    if (userRouteDoc.exists) {
      oldRate = userRouteDoc.data()?['rate'] ?? 0;
    }

    // 평균 평점 재계산
    double newAvgRate;
    if (oldRate == 0) {
      // 신규 평점 추가
      newAvgRate = ((avgRate * rateCount) + newRate) / (rateCount + 1);
      rateCount += 1;
    } else {
      // 기존 평점 수정
      newAvgRate = ((avgRate * rateCount) - oldRate + newRate) / rateCount;
    }

    // users/{userEmail}/my_routes에 저장 또는 업데이트
    await userRouteRef.set({
      'points': coords.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'rate': newRate,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // routes 문서에 평균 평점, 개수 업데이트
    await routesRef.update({
      'avgRate': newAvgRate,
      'rateCount': rateCount,
    });

    return {
      'id': routeId,
      'points': coords,
      'avgRate': newAvgRate,
      'rateCount': rateCount,
    };
  }

  /// routes 컬렉션 전체 로드 (평균평점, points 포함)
  static Future<List<Map<String, dynamic>>> loadRoutes() async {
    final snapshot = await _firestore.collection('routes').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final pointsData = data['points'] as List<dynamic>;
      List<LatLng> points = pointsData.map((p) => LatLng(p['lat'], p['lng'])).toList();

      return {
        'id': doc.id,
        'points': points,
        'avgRate': (data['avgRate'] ?? 0).toDouble(),
        'rateCount': (data['rateCount'] ?? 0),
      };
    }).toList();
  }

  /// 사용자가 해당 경로에 대해 평점을 이미 저장했는지 확인 + 기존 평점 반환 (0 이면 없음)
  static Future<int> getUserRateForRoute({
    required String? userEmail,
    required String routeId,
  }) async {
    final userRouteDoc = await _firestore.collection('users').doc(userEmail).collection('my_routes').doc(routeId).get();
    if (!userRouteDoc.exists) return 0;
    return userRouteDoc.data()?['rate'] ?? 0;
  }

  /// 평점에 따른 폴리라인 색상 반환
  static Color getPolylineColor(double avgRate) {
    int rounded = avgRate.round();
    switch (rounded) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      default:
        return Colors.red;
    }
  }
}
