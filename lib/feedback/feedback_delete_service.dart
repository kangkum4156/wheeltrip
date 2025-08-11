import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart'; // user_email, user_savedPlaces

Future<void> deleteMyFeedback({
  required BuildContext context,
  required String googlePlaceId,
  required Future<void> Function() onMarkerReset, // // MapView 갱신 콜백
}) async {
  final fs = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 필요합니다.')),
    );
    return;
  }

  // // 피드백 문서 ID는 이메일(없으면 uid)
  final feedbackDocId =
  (user.email != null && user.email!.trim().isNotEmpty)
      ? user.email!.trim()
      : user.uid;

  final placeRef = fs.collection('places').doc(googlePlaceId);
  final feedbackRef = placeRef.collection('feedbacks').doc(feedbackDocId);
  final savedRef = fs
      .collection('users')
      .doc(user_email) // // 앱에서 사용하는 사용자 문서 키(문자열) — 기존 로직 유지
      .collection('saved_places')
      .doc(googlePlaceId);

  try {
    // // 동시 삭제
    final batch = fs.batch();
    batch.delete(feedbackRef);
    batch.delete(savedRef);
    await batch.commit();

    // // 평균 평점 재계산
    final snap = await placeRef.collection('feedbacks').get();
    if (snap.docs.isEmpty) {
      await placeRef.update({'avgRating': 0.0});
    } else {
      final total = snap.docs
          .map((d) => (d.data()['rating'] as num?) ?? 0)
          .fold<num>(0, (a, b) => a + b);
      final avg = total / snap.docs.length;
      await placeRef.update({'avgRating': avg});
    }

    // // 로컬 저장소 동기화(전역 리스트 사용 시)
    user_savedPlaces.removeWhere((e) => e['id'] == googlePlaceId);

    // // MapView 갱신
    await onMarkerReset();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('피드백이 삭제되었습니다.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('삭제 실패: $e')),
    );
  }
}
