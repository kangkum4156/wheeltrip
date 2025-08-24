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
    required List<String> features,
    required String? routeId,
  }) async {
    final routesRef = _firestore.collection('routes');
    final usersRoutesRef = _firestore.collection('users').doc(userEmail).collection('my_routes');

    const defaultFeatures = ['경사로', '계단', '넓은 길'];

    // routes 컬렉션에 routeId를 docID로 사용
    final newRouteDoc = routesRef.doc(routeId);

    // routes에 새 문서 생성 (ID 자동 생성)
    await newRouteDoc.set({
      'points': coords.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'avgRate': rate.toDouble(),
      'rateCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // features 안에 있는 기본 feature(경사로, 인도, 차도)만 카운트 증가 + 없으면 0으로 설정
    final featureCounts = <String, dynamic>{};
    for (var f in defaultFeatures) {
      if (features.contains(f)) {
        featureCounts['featureCounts.$f'] = FieldValue.increment(1);
      }
      else{
        featureCounts['featureCounts.$f']=FieldValue.increment(0);
      }
    }

    if (featureCounts.isNotEmpty) {
      await newRouteDoc.update(featureCounts);
    }

    // feedbacks 서브컬렉션에 user_email 문서로 피드백 저장
    await newRouteDoc.collection('feedbacks').doc(userEmail).set({
      'rate': rate,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // users/{userEmail}/my_routes에도 같은 문서 저장 (routeId를 docID로)
    await usersRoutesRef.doc(routeId).set({
      'rate': rate,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': routeId,
      'avgRate': rate.toDouble(),
    };
  }

  static Future<bool> checkUserFeedbackExists({
    required String? userEmail,
    required String routeId,
  }) async {
    final doc = await _firestore
        .collection('routes')
        .doc(routeId)
        .collection('feedbacks')
        .doc(userEmail)
        .get();
    return doc.exists;
  }

  static Future<List<Map<String, dynamic>>> loadFeedbacks(String routeId) async {
    final snapshot = await _firestore
        .collection('routes')
        .doc(routeId)
        .collection('feedbacks')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'userEmail': doc.id,
        'rate': data['rate'] ?? 0,
        'features': List<String>.from(data['features'] ?? []),
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'userName': data['userName'] ?? '',
      };
    }).toList();
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

  static Future<List<String>?> getUserFeatures({
    required String? userEmail,
    required String routeId,
  }) async {
    final userRouteDoc = await _firestore
        .collection('users')
        .doc(userEmail)
        .collection('my_routes')
        .doc(routeId)
        .get();

    if (!userRouteDoc.exists) return null;

    final data = userRouteDoc.data();
    if (data == null) return null;

    final features = data['features'];

    if (features is List) {
      return features.whereType<String>().toList();
    }

    return null;
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
