import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:wheeltrip/road/road_feedback_options.dart';

typedef OnRouteSavedCallback = Future<void> Function(
   String routeId, int rate, List<String> features);

Future<bool?> showAddRoadFeedbackBottomSheet({
  required String routeId,
  required BuildContext context,
  required OnRouteSavedCallback onRouteSaved,
}) {
  int selectedRate = 3; // 기본 평점
  List<String> selectedFeatures = [];

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "경로 평가하기",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 별점 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    int starIndex = index + 1;
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        selectedRate >= starIndex
                            ? Icons.star
                            : Icons.star_border,
                        color: selectedRate >= starIndex
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedRate = starIndex;
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // features 체크박스
                RoadFeedbackOptions(
                  selectedFeatures: selectedFeatures,
                  isEditable: true,
                  onFeaturesChanged: (features) {
                    setState(() {
                      selectedFeatures
                        ..clear()
                        ..addAll(features);
                    });
                  },
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    await onRouteSaved(routeId, selectedRate, selectedFeatures);
                    Navigator.pop(context, true);
                  },
                  child: const Text("평가 저장"),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> addRoadFeedback(
    String routeId,
    int rate,
    List<String> features,
    ) async {
  try {
    final routeRef = FirebaseFirestore.instance.collection('routes').doc(routeId);
    final feedbackRef = FirebaseFirestore.instance
        .collection('routes')
        .doc(routeId)
        .collection('feedbacks')
        .doc(user_email);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user_email).collection('my_routes').doc(routeId);

    await feedbackRef.set({
      'rate': rate,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) 현재 avgRate와 rateCount 불러오기
    final routeSnapshot = await routeRef.get();
    if (!routeSnapshot.exists) {
      throw Exception("해당 routeId 문서가 없습니다.");
    }

    final data = routeSnapshot.data() ?? {};
    final double currentAvg = (data['avgRate'] ?? 0).toDouble();
    final int currentCount = (data['rateCount'] ?? 0) as int;

    // 3) 새로운 평균 계산
    final double totalScore = currentAvg * currentCount + rate;
    final int newCount = currentCount + 1;
    final double newAvg = totalScore / newCount;

    // 기본 카운트 대상 feature
    const defaultFeatures = ['경사로', '인도', '차도'];

    // features 안에 있는 기본 feature만 카운트 증가
    final featureCounts = <String, dynamic>{};
    for (var f in defaultFeatures) {
      if (features.contains(f)) {
        featureCounts['featureCounts.$f'] = FieldValue.increment(1);
      }
    }

    // 4) 문서 업데이트
    await routeRef.update({
      'avgRate': newAvg,
      'rateCount': newCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (featureCounts.isNotEmpty) {
      await routeRef.update(featureCounts);
    }

    await userRef.set({
      'rate': rate,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("피드백 저장 성공");
  } catch (e) {
    print("피드백 저장 실패: $e");
  }
}