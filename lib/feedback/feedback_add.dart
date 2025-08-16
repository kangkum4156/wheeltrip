import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:wheeltrip/map/map_to_firebase_save.dart'; // SavePlace 위젯(기존)
import 'package:wheeltrip/feedback/feedback_option_button.dart';

// ✅ 지연 업로드용 헬퍼들
import 'package:wheeltrip/feedback/pending_photo.dart';
import 'package:wheeltrip/feedback/feedback_photo_service.dart'
    show pickAndCompressOnePhoto, uploadPendingPhotos, upsertFeedbackDocument;

void showFeedbackAddSheet({
  required BuildContext context,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required String googlePlaceId,
  required Future<void> Function() onSaveComplete,
}) {
  final TextEditingController memoController = TextEditingController();
  int selectedEmotion = 5;
  final List<String> selectedFeatures = [];

  // 작성 중 추가한(아직 업로드하지 않은) 사진들
  final List<PendingPhoto> pendingPhotos = [];

  // 등록(제출) 단계에서의 전체 진행률
  double submitProgress = 0.0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: MediaQuery.of(context).viewInsets.add(
            const EdgeInsets.all(16.0),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 장소 기본 정보
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('📍 주소: $address'),
                const SizedBox(height: 4),
                Text('📞 전화번호: $phone'),
                const SizedBox(height: 4),
                const Text('🕒 운영 시간:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(openingHours),
                const SizedBox(height: 8),

                const Divider(),

                const SizedBox(height: 8),
                const Text('💬 메모:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '메모를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('😀 편의도 평가 :', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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

                const SizedBox(height: 12),

                // ✅ 작성 중 로컬 사진 미리보기(아직 업로드하지 않음)
                if (pendingPhotos.isNotEmpty)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pendingPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              pendingPhotos[i].bytes,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // ❌ 개별 삭제 버튼(원하면 유지)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
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

                const SizedBox(height: 8),

                // 제출(등록) 단계 진행률
                if (submitProgress > 0 && submitProgress < 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: LinearProgressIndicator(value: submitProgress),
                  ),

                // 사진 추가(작성 중: 로컬만 저장 → 미리보기 표시)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('사진 추가'),
                    onPressed: () async {
                      final picked = await pickAndCompressOnePhoto();
                      if (picked != null) {
                        setState(() => pendingPhotos.add(picked));
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ 등록 버튼: SavePlace 완료 콜백에서 업로드 & Firestore 병합
                Center(
                  child: SavePlace(
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                    comment: memoController.text,
                    rating: selectedEmotion,
                    name: name,
                    phone: phone,
                    address: address,
                    time: openingHours,
                    googlePlaceId: googlePlaceId,
                    saveToUserSavedPlaces: true,
                    extraData: selectedFeatures.isNotEmpty
                        ? {"features": selectedFeatures}
                        : {},
                    onSaveComplete: (marker) async {
                      // 여기서만 실제 업로드 & Firestore photoUrls 반영
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && pendingPhotos.isNotEmpty) {
                        final feedbackDocId =
                        (user.email != null && user.email!.trim().isNotEmpty)
                            ? user.email!.trim()
                            : user.uid;

                        try {
                          // 1) 사진 일괄 업로드(전체 진행률 표시)
                          final newUrls = await uploadPendingPhotos(
                            googlePlaceId: googlePlaceId,
                            pending: pendingPhotos,
                            onProgress: (p) {
                              if (context.mounted) {
                                setState(() => submitProgress = p);
                              }
                            },
                          );

                          // 2) Firestore에 photoUrls 합치기(merge)
                          await upsertFeedbackDocument(
                            googlePlaceId: googlePlaceId,
                            feedbackDocId: feedbackDocId,
                            data: const {}, // comment/rating은 SavePlace가 이미 저장
                            photoUrlsToAdd: newUrls,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('사진 업로드 실패: $e')),
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
                      }

                      // 외부 콜백 수행(지도 갱신 등)
                      await onSaveComplete();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
