// lib/feedback/feedback_delete.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart'; // // user_email, user_savedPlaces

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

  // // 피드백 문서 ID: 이메일(없으면 uid)
  final feedbackDocId = (user.email != null && user.email!.trim().isNotEmpty)
      ? user.email!.trim()
      : user.uid;

  final placeRef   = fs.collection('places').doc(googlePlaceId);
  final feedbackRef = placeRef.collection('feedbacks').doc(feedbackDocId);
  final savedRef   = fs
      .collection('users')
      .doc(user_email) // // 앱에서 사용하는 사용자 문서 키(문자열) — 기존 로직 유지
      .collection('saved_places')
      .doc(googlePlaceId);

  try {
    // // 1) 피드백 문서에서 photoUrls 읽기
    final docSnap = await feedbackRef.get();
    List<String> photoUrls = const <String>[];
    if (docSnap.exists) {
      final data = docSnap.data();
      if (data != null && data['photoUrls'] is List) {
        photoUrls = List<String>.from(
          (data['photoUrls'] as List)
              .where((e) => e is String && e.toString().trim().isNotEmpty),
        );
      }
    }

    // // 2) Storage 파일 삭제 (권한: rules에서 delete 허용 필요)
    // // 실패해도 전체 플로우는 계속 진행; 각 파일 개별 try-catch
    for (final url in photoUrls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        // // 이미 지워졌거나 권한 문제일 수 있음 — 필요 시 로깅만
        // debugPrint('Storage delete failed: $e');
      }
    }

    // // 3) Firestore 문서 및 저장 장소 항목 동시 삭제
    final batch = fs.batch();
    batch.delete(feedbackRef);
    batch.delete(savedRef);
    await batch.commit();

    // // 4) 평균 평점 재계산
    final left = await placeRef.collection('feedbacks').get();
    if (left.docs.isEmpty) {
      await placeRef.update({'avgRating': 0.0});
    } else {
      final ratings = left.docs
          .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
          .toList();
      final sum = ratings.fold<double>(0.0, (a, b) => a + b);
      final avg = ratings.isEmpty ? 0.0 : sum / ratings.length;
      await placeRef.update({'avgRating': avg});
    }

    // // 5) 로컬 상태 동기화
    user_savedPlaces.removeWhere((e) => e['id'] == googlePlaceId);

    // // 6) UI 갱신
    await onMarkerReset();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('피드백과 사진이 삭제되었습니다.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('삭제 실패: $e')),
    );
  }
}
