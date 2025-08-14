// lib/feedback/feedback_edit.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:wheeltrip/feedback/feedback_option_button.dart';

// ✅ 지연 업로드용 헬퍼들
import 'package:wheeltrip/feedback/pending_photo.dart';
import 'package:wheeltrip/feedback/feedback_photo_service.dart'
    show pickAndCompressOnePhoto, uploadPendingPhotos, upsertFeedbackDocument;

void showEditFeedbackSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String feedbackId,                    // 기존 문서 ID (이메일 또는 UID)
  required Map<String, dynamic> existingData,    // 기존 문서 데이터
}) {
  final TextEditingController memoController =
  TextEditingController(text: existingData['comment'] ?? '');
  int selectedEmotion = (existingData['rating'] as int?) ?? 5;

  // 기존 저장된 시설 옵션
  final List<String> selectedFeatures =
  List<String>.from(existingData['features'] ?? const <String>[]);

  // ✅ 기존 등록 사진(URL) 목록 (서버에 이미 존재)
  final List<String> localPhotoUrls = (existingData['photoUrls'] is List)
      ? List<String>.from(
    (existingData['photoUrls'] as List)
        .where((e) => e is String && e.toString().trim().isNotEmpty),
  )
      : <String>[];

  // ✅ 이번 수정에서 새로 추가(아직 업로드하지 않은) 로컬 사진 바이트
  final List<PendingPhoto> pendingPhotos = [];

  // 제출(수정 완료) 단계의 전체 진행률(0~1)
  double submitProgress = 0.0;

  // 평균 평점 재계산
  Future<void> updateAverageRating(String placeId) async {
    final placeRef = FirebaseFirestore.instance.collection('places').doc(placeId);
    final feedbacksSnapshot = await placeRef.collection('feedbacks').get();
    if (feedbacksSnapshot.docs.isEmpty) {
      await placeRef.update({'avgRating': 0.0});
    } else {
      final ratings = feedbacksSnapshot.docs
          .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
          .toList();
      final total = ratings.fold<double>(0.0, (a, b) => a + b);
      final avg = ratings.isEmpty ? 0.0 : total / ratings.length;
      await placeRef.update({'avgRating': avg});
    }
  }

  // 기존 사진 1장 삭제: Storage 파일 삭제 + Firestore 배열에서 제거
  Future<void> deleteOnePhotoUrl(BuildContext ctx, String url) async {
    try {
      // 1) Storage 삭제
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (_) {
        // 이미 없을 수 있으니 무시(로그만 필요시 남기기)
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

                // 📷 [1] 기존에 등록된 사진(URL) 썸네일
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
                                loadingBuilder: (c, child, p) => p == null
                                    ? child
                                    : const SizedBox(
                                  width: 78,
                                  height: 78,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
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
                            // 삭제 버튼(기존 사진만)
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
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('취소')),
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('삭제')),
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

                const SizedBox(height: 8),

                // 📷 [2] 이번 수정에서 새로 추가(로컬)한 사진 썸네일
                if (pendingPhotos.isNotEmpty)
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pendingPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              pendingPhotos[i].bytes,
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // 로컬 썸네일 제거 버튼
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(() => pendingPhotos.removeAt(i)),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 제출(수정 완료) 단계 진행률
                if (submitProgress > 0 && submitProgress < 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(value: submitProgress),
                  ),

                // 사진 추가(지연 업로드: 로컬만 저장)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('사진 추가'),
                    onPressed: () async {
                      final p = await pickAndCompressOnePhoto();
                      if (p != null) {
                        setState(() => pendingPhotos.add(p));
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

                // 저장(수정 완료)
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("수정 완료"),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인이 필요합니다.')),
                        );
                      }
                      return;
                    }

                    try {
                      // 1) (있다면) 새로 추가한 로컬 사진들을 일괄 업로드
                      List<String> newUrls = const <String>[];
                      if (pendingPhotos.isNotEmpty) {
                        newUrls = await uploadPendingPhotos(
                          googlePlaceId: googlePlaceId,
                          pending: pendingPhotos,
                          onProgress: (p) {
                            if (context.mounted) {
                              setState(() => submitProgress = p);
                            }
                          },
                        );
                      }

                      // 2) Firestore 문서 업데이트(기존 문서에 병합)
                      final updateData = <String, dynamic>{
                        'comment': memoController.text,
                        'rating': selectedEmotion,
                        'timestamp': FieldValue.serverTimestamp(),
                      };

                      if (selectedFeatures.isNotEmpty) {
                        updateData['features'] = selectedFeatures;
                      } else {
                        updateData['features'] = FieldValue.delete();
                      }

                      // - 데이터 필드 업데이트
                      await FirebaseFirestore.instance
                          .collection('places')
                          .doc(googlePlaceId)
                          .collection('feedbacks')
                          .doc(feedbackId)
                          .set(updateData, SetOptions(merge: true));

                      // - 새 사진 URL들 병합
                      if (newUrls.isNotEmpty) {
                        await upsertFeedbackDocument(
                          googlePlaceId: googlePlaceId,
                          feedbackDocId: feedbackId,
                          data: const {},
                          photoUrlsToAdd: newUrls,
                        );
                      }

                      // 3) 평균 평점 재계산
                      await updateAverageRating(googlePlaceId);

                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('수정 실패: $e')),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() {
                          submitProgress = 0.0;
                          pendingPhotos.clear();
                        });
                      }
                    }
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
