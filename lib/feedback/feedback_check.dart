import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/feedback/feedback_add.dart';
import 'package:wheeltrip/feedback/feedback_edit.dart'; // 수정 모드 화면 만들면 여기에

/// 한 장소에 대해 현재 로그인한 사용자가 이미 피드백을 작성했는지 체크하고,
/// 작성했으면 수정 화면, 아니면 새 작성 화면을 띄움
Future<void> checkAndShowFeedbackForm({
  required BuildContext context,
  required String placeId,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 필요합니다.')),
    );
    return;
  }

  try {
    // 해당 장소 + 현재 사용자 피드백 존재 여부 확인
    final feedbackQuery = await FirebaseFirestore.instance
        .collection('places')
        .doc(placeId)
        .collection('feedbacks')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (feedbackQuery.docs.isNotEmpty) {
      // 이미 작성 → 수정 모드
      final existingFeedback = feedbackQuery.docs.first;
      final feedbackId = existingFeedback.id;
      final feedbackData = existingFeedback.data();

      // 수정 시트 열기
      showEditFeedbackSheet(
        context: context,
        googlePlaceId: placeId,
        feedbackId: feedbackId,
        existingData: feedbackData,
      );
    } else {
      // 작성한 적 없음 → 새로 작성
      showFeedbackAddSheet(
        context: context,
        name: name,
        address: address,
        latLng: latLng,
        phone: phone,
        openingHours: openingHours,
        googlePlaceId: placeId,
        onSaveComplete: () async {
          // 저장 후 다시 보기
          Navigator.pop(context); // 기존 보기 닫기
        },
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('피드백 확인 중 오류 발생: $e')),
    );
  }
}
