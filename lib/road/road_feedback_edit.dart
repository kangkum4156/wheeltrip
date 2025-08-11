import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart';

Future<void> showEditFeedbackBottomSheet({
  required BuildContext context,
  required int initialRate,
  required List<String>? initialFeatures,
  required Future<void> Function(int updatedRate, List<String> updatedFeatures) onFeedbackUpdated,
}) {
  int selectedRate = initialRate;
  List<String> selectedFeatures = List.from(initialFeatures ?? []);
  final featureOptions = ['경사로', '차도', '인도'];

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void toggleFeature(String f) {
            if (selectedFeatures.contains(f)) {
              selectedFeatures.remove(f);
            } else {
              selectedFeatures.add(f);
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
                const Text('피드백 수정하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),

                // 별점 선택 (1~3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    int starNum = i + 1;
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        selectedRate >= starNum ? Icons.star : Icons.star_border,
                        color: selectedRate >= starNum ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => selectedRate = starNum);
                      },
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // features 체크박스
                Wrap(
                  alignment: WrapAlignment.center,
                  children: featureOptions.map((feature) {
                    final selected = selectedFeatures.contains(feature);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: selected,
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
                    await onFeedbackUpdated(selectedRate, selectedFeatures);
                    Navigator.pop(context);
                  },
                  child: const Text('수정 완료'),
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

Future<void> updateRoadFeedback(
    String routeId,
    int rate,
    List<String> features,
    ) async {
  final routeRef = FirebaseFirestore.instance.collection('routes').doc(routeId);
  final feedbackRef = routeRef.collection('feedbacks').doc(user_email);
  final userRef = FirebaseFirestore.instance.collection('users').doc(user_email).collection('my_routes').doc(routeId);

  try {
    // 1) 기존 피드백 불러오기
    final feedbackSnap = await feedbackRef.get();
    if (!feedbackSnap.exists) {
      throw Exception("업데이트할 피드백이 없습니다.");
    }
    final oldData = feedbackSnap.data()!;
    final int oldRate = (oldData['rate'] ?? 0) as int;

    // 2) 피드백 업데이트 (rate, features, updatedAt)
    await feedbackRef.update({
      'rate': rate,
      'features': features,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await userRef.set({
      'rate': rate,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });


    // 3) 현재 routes 문서 불러오기
    final routeSnap = await routeRef.get();
    if (!routeSnap.exists) {
      throw Exception("routeId 문서가 없습니다.");
    }

    final routeData = routeSnap.data()!;
    final double currentAvg = (routeData['avgRate'] ?? 0).toDouble();
    final int rateCount = (routeData['rateCount'] ?? 0) as int;

    // 4) 평균 재계산 (기존 평균 * count - oldRate + newRate) / count
    final double totalScore = currentAvg * rateCount - oldRate + rate;
    final double newAvg = totalScore / rateCount;

    // 5) routes 문서 업데이트
    await routeRef.update({
      'avgRate': newAvg,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print("피드백 수정 및 평균 업데이트 성공");
  } catch (e) {
    print("피드백 수정 실패: $e");
  }
}