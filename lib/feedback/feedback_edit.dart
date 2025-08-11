import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wheeltrip/feedback/feedback_option_button.dart';
import 'package:wheeltrip/feedback/feedback_photo_service.dart'; // 사진 추가(1장씩, photoUrls에 union)

void showEditFeedbackSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String feedbackId,
  required Map<String, dynamic> existingData,
}) {
  final TextEditingController memoController =
  TextEditingController(text: existingData['comment'] ?? '');
  int selectedEmotion = existingData['rating'] ?? 5;

  // 기존 저장된 시설 옵션
  final List<String> selectedFeatures =
  List<String>.from(existingData['features'] ?? []);

  // 기존 사진 리스트 (photoUrls 기준)
  final List<String> localPhotoUrls = (existingData['photoUrls'] is List)
      ? List<String>.from(
    (existingData['photoUrls'] as List)
        .where((e) => e is String && e.trim().isNotEmpty),
  )
      : <String>[];

  // 업로드 진행률
  double uploadProgress = 0;

  // 평균 평점 재계산
  Future<void> updateAverageRating(String placeId) async {
    final placeRef = FirebaseFirestore.instance.collection('places').doc(placeId);
    final feedbacksSnapshot = await placeRef.collection('feedbacks').get();
    if (feedbacksSnapshot.docs.isNotEmpty) {
      final total = feedbacksSnapshot.docs
          .map((doc) => (doc['rating'] as num).toDouble())
          .reduce((a, b) => a + b);
      final avg = total / feedbacksSnapshot.docs.length;
      await placeRef.update({'avgRating': avg});
    }
  }

  // 사진 1장 삭제: Storage 파일 삭제 + Firestore 배열에서 제거
  Future<void> deleteOnePhotoUrl(BuildContext ctx, String url) async {
    try {
      // 1) Storage 삭제 (url → ref)
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (_) {
        // Storage에 없을 수도 있으니 무시 (로그만 찍어도 됨)
      }

      // 2) Firestore 배열에서 제거
      await FirebaseFirestore.instance
          .collection('places')
          .doc(googlePlaceId)
          .collection('feedbacks')
          .doc(feedbackId)
          .update({'photoUrls': FieldValue.arrayRemove([url])});

      // 로컬에서도 제거
      localPhotoUrls.remove(url);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('사진을 삭제했습니다.')),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('사진 삭제 실패: $e')),
        );
      }
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
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "피드백 수정",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 📷 사진 리스트 (가로 스크롤 썸네일) + 추가/진행률
                if (localPhotoUrls.isNotEmpty)
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: localPhotoUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final url = localPhotoUrls[i];
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 78,
                                height: 78,
                                fit: BoxFit.cover,
                                loadingBuilder: (c, child, p) =>
                                p == null ? child : const SizedBox(
                                  width: 78, height: 78,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorBuilder: (c, e, s) => Container(
                                  width: 78,
                                  height: 78,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image, size: 20),
                                ),
                              ),
                            ),
                            // 삭제 버튼
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('사진 삭제'),
                                        content: const Text('이 사진을 삭제할까요?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await deleteOnePhotoUrl(context, url);
                                      setState(() {});
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.delete, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // 업로드 진행률
                if (uploadProgress > 0 && uploadProgress < 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(value: uploadProgress),
                  ),

                // 사진 추가 버튼
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('사진 추가'),
                    onPressed: () async {
                      final url = await addOnePhotoToMyFeedback(
                        context: context,
                        googlePlaceId: googlePlaceId,
                        onProgress: (p) => setState(() => uploadProgress = p),
                      );
                      setState(() => uploadProgress = 0);
                      if (url != null) {
                        // Firestore에 union 저장은 이미 됐고, 로컬에도 즉시 반영
                        setState(() => localPhotoUrls.add(url));
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // 메모
                const Text('메모', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // 편의도 평가
                const Text('편의도 평가', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final score = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => selectedEmotion = score),
                      child: Icon(
                        Icons.face,
                        size: 36,
                        color: selectedEmotion >= score ? Colors.orange : Colors.grey,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // 시설 정보
                const Text('🏷 시설 정보:', style: TextStyle(fontWeight: FontWeight.bold)),
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

                // 저장
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("수정 완료"),
                  onPressed: () async {
                    final updateData = <String, dynamic>{
                      'comment': memoController.text,
                      'rating': selectedEmotion,
                      'timestamp': FieldValue.serverTimestamp(),
                      // photoUrls는 추가/삭제 시점에 각각 실시간 반영했으므로 여기서 별도 수정 불필요
                    };

                    // features 반영
                    if (selectedFeatures.isNotEmpty) {
                      updateData['features'] = selectedFeatures;
                    } else {
                      updateData['features'] = FieldValue.delete();
                    }

                    // 피드백 문서 업데이트
                    await FirebaseFirestore.instance
                        .collection('places')
                        .doc(googlePlaceId)
                        .collection('feedbacks')
                        .doc(feedbackId)
                        .update(updateData);

                    // 평균 평점 재계산
                    await updateAverageRating(googlePlaceId);

                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
