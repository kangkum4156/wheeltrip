// lib/feedback/feedback_add.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wheeltrip/map/map_to_firebase_save.dart';
import 'package:wheeltrip/feedback/feedback_option_button.dart';
import 'package:wheeltrip/feedback/feedback_photo_service.dart'; // photoUrls 배열에 추가

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

  double uploadProgress = 0;

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

                // ✅ 현재 "내 피드백"의 photoUrls 미리보기(가로 썸네일 리스트)
                _MyFeedbackPhotoStrip(googlePlaceId: googlePlaceId),

                const SizedBox(height: 8),

                // 업로드 진행률 (진행 중일 때만 표시)
                if (uploadProgress > 0 && uploadProgress < 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: LinearProgressIndicator(value: uploadProgress),
                  ),

                // 사진 추가(한 번에 1장씩 → 여러 번 누르면 여러 장)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('사진 추가'),
                    onPressed: () async {
                      await addOnePhotoToMyFeedback(
                        context: context,
                        googlePlaceId: googlePlaceId,
                        onProgress: (p) => setState(() => uploadProgress = p),
                      );
                      setState(() => uploadProgress = 0);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 저장 버튼
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
                      await onSaveComplete();
                      Navigator.pop(context);
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

/// 내 피드백 문서의 photoUrls를 실시간으로 가로 썸네일 스트립으로 표시
class _MyFeedbackPhotoStrip extends StatelessWidget {
  final String googlePlaceId;
  const _MyFeedbackPhotoStrip({super.key, required this.googlePlaceId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final feedbackDocId =
    (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email!.trim()
        : user.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('places')
          .doc(googlePlaceId)
          .collection('feedbacks')
          .doc(feedbackDocId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final urls = (data['photoUrls'] is List)
            ? List<String>.from(
          (data['photoUrls'] as List).where((e) => e is String && e.trim().isNotEmpty),
        )
            : <String>[];

        if (urls.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                urls[i],
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, p) =>
                p == null ? child : const SizedBox(width: 72, height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (c, e, s) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
