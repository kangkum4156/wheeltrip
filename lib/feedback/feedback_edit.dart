import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/feedback/feedback_option_button.dart';

void showEditFeedbackSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String feedbackId,
  required Map<String, dynamic> existingData,
}) {
  TextEditingController memoController =
  TextEditingController(text: existingData['comment'] ?? '');
  int selectedEmotion = existingData['rating'] ?? 5;

  // 기존 저장된 시설 옵션 불러오기
  final List<String> selectedFeatures =
  List<String>.from(existingData['features'] ?? []);

  // 🔹 평균 평점 재계산 함수
  Future<void> updateAverageRating(String placeId) async {
    final placeRef =
    FirebaseFirestore.instance.collection('places').doc(placeId);

    final feedbacksSnapshot = await placeRef.collection('feedbacks').get();
    if (feedbacksSnapshot.docs.isNotEmpty) {
      final total = feedbacksSnapshot.docs
          .map((doc) => (doc['rating'] as num).toDouble())
          .reduce((a, b) => a + b);
      final avg = total / feedbacksSnapshot.docs.length;

      await placeRef.update({'avgRating': avg});
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding:
          MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("피드백 수정",
                    style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // 메모 입력
                TextField(
                  controller: memoController,
                  maxLines: 3,
                  decoration:
                  const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),

                // 편의도 평가
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final score = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => selectedEmotion = score),
                      child: Icon(Icons.face,
                          size: 36,
                          color: selectedEmotion >= score
                              ? Colors.orange
                              : Colors.grey),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // 시설 정보
                const Text(
                  '🏷 시설 정보:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                FeedbackOptionButton(
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

                const SizedBox(height: 16),

                // 저장 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("수정 완료"),
                  onPressed: () async {
                    final updateData = {
                      'comment': memoController.text,
                      'rating': selectedEmotion,
                      'timestamp': FieldValue.serverTimestamp(),
                    };

                    // features 반영
                    if (selectedFeatures.isNotEmpty) {
                      updateData['features'] = selectedFeatures;
                    } else {
                      updateData['features'] = FieldValue.delete();
                    }

                    // 1️⃣ 개별 피드백 수정
                    await FirebaseFirestore.instance
                        .collection('places')
                        .doc(googlePlaceId)
                        .collection('feedbacks')
                        .doc(feedbackId)
                        .update(updateData);

                    // 2️⃣ 평균 평점 재계산
                    await updateAverageRating(googlePlaceId);

                    Navigator.pop(context);
                  },
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}
