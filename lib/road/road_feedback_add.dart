import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart';

typedef OnRouteSavedCallback = Future<void> Function(
   String routeId, int rate, List<String> features);

Future<bool?> showAddRoadFeedbackBottomSheet({
  required String routeId,
  required BuildContext context,
  required OnRouteSavedCallback onRouteSaved,
}) {
  int selectedRate = 3; // 기본 평점
  List<String> selectedFeatures = [];

  final List<String> featureOptions = ['경사로', '차도', '인도'];

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
          void toggleFeature(String feature) {
            if (selectedFeatures.contains(feature)) {
              selectedFeatures.remove(feature);
            } else {
              selectedFeatures.add(feature);
            }
            setState(() {});
          }

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
                Wrap(
                  alignment: WrapAlignment.center,
                  children: featureOptions.map((feature) {
                    final isSelected = selectedFeatures.contains(feature);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => toggleFeature(feature),
                          ),
                          Text(feature),
                        ],
                      ),
                    );
                  }).toList(),
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

    // 4) 문서 업데이트
    await routeRef.update({
      'avgRate': newAvg,
      'rateCount': newCount,
      'updatedAt': FieldValue.serverTimestamp(),
    });

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