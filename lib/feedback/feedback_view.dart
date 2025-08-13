import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:wheeltrip/feedback/feedback_add.dart';
import 'package:wheeltrip/feedback/feedback_edit.dart';
import 'package:wheeltrip/feedback/feedback_option_button.dart';
import 'package:wheeltrip/feedback/feedback_delete_service.dart'; // 삭제 서비스

void showFeedbackViewSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required Future<void> Function() onMarkerReset, // MapView 갱신 콜백
}) {
  final user = FirebaseAuth.instance.currentUser;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final screen = MediaQuery.of(context).size;
          final listHeight = screen.height * 0.35; // 내부 피드백 리스트 영역 높이

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    // 장소 기본 정보
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('📍 주소: $address'),
                    Text('📞 전화번호: $phone'),
                    const SizedBox(height: 4),
                    const Text(
                      '🕒 운영 시간:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(openingHours),
                    const SizedBox(height: 8),

                    // 평균 평점
                    StreamBuilder<DocumentSnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('places')
                              .doc(googlePlaceId)
                              .snapshots(),
                      builder: (context, snapshot) {
                        final data =
                            snapshot.data?.data() as Map<String, dynamic>?;
                        final avgRating = (data?['avgRating'] ?? 0).toDouble();
                        return Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange),
                            Text(avgRating.toStringAsFixed(1)),
                          ],
                        );
                      },
                    ),

                    const Divider(height: 20),

                    // 피드백 추가/수정/삭제 (로그인 유저 전용)
                    if (user != null)
                      StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('places')
                                .doc(googlePlaceId)
                                .collection('feedbacks')
                                .where('userId', isEqualTo: user.uid)
                                .limit(1)
                                .snapshots(),
                        builder: (context, snapshot) {
                          final hasFeedback =
                              snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty;

                          if (hasFeedback) {
                            final feedbackDoc = snapshot.data!.docs.first;
                            return Center(
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text("피드백 수정하기"),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showEditFeedbackSheet(
                                        context: context,
                                        googlePlaceId: googlePlaceId,
                                        feedbackId: feedbackDoc.id,
                                        existingData:
                                            feedbackDoc.data()
                                                as Map<String, dynamic>,
                                      );
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_forever),
                                    label: const Text("내 피드백 삭제"),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text('삭제 확인'),
                                              content: const Text(
                                                '내 피드백과 저장된 장소 기록을 삭제할까요?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('취소'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('삭제'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (ok == true) {
                                        await deleteMyFeedback(
                                          context: context,
                                          googlePlaceId: googlePlaceId,
                                          onMarkerReset: onMarkerReset,
                                        );
                                        Navigator.pop(context); // 바텀시트 닫기
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_comment),
                                label: const Text("피드백 추가하기"),
                                onPressed: () {
                                  Navigator.pop(context);
                                  showFeedbackAddSheet(
                                    context: context,
                                    name: name,
                                    address: address,
                                    latLng: latLng,
                                    phone: phone,
                                    openingHours: openingHours,
                                    googlePlaceId: googlePlaceId,
                                    onSaveComplete: () async {
                                      await onMarkerReset();
                                      showFeedbackViewSheet(
                                        context: context,
                                        googlePlaceId: googlePlaceId,
                                        name: name,
                                        address: address,
                                        latLng: latLng,
                                        phone: phone,
                                        openingHours: openingHours,
                                        onMarkerReset: onMarkerReset,
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          }
                        },
                      ),

                    const SizedBox(height: 10),
                    const Text(
                      '📋 등록된 피드백',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 내부 스크롤러 충돌 방지: 고정 높이
                    SizedBox(
                      height: listHeight,
                      child: StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('places')
                                .doc(googlePlaceId)
                                .collection('feedbacks')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('아직 등록된 피드백이 없습니다.'),
                            );
                          }

                          final feedbacks = snapshot.data!.docs;
                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid;

                          final sortedFeedbacks = [
                            // 내 피드백이 가장 위로 올라오도록
                            ...feedbacks.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['userId'] == currentUserId;
                            }),
                            ...feedbacks.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['userId'] != currentUserId;
                            }),
                          ];

                          return ListView.builder(
                            itemCount: sortedFeedbacks.length,
                            itemBuilder: (context, index) {
                              final fb =
                                  sortedFeedbacks[index].data()
                                      as Map<String, dynamic>;
                              final rating = fb['rating'] ?? 0;
                              final comment = fb['comment'] ?? '';
                              final features = List<String>.from(
                                fb['features'] ?? [],
                              );
                              final time =
                                  fb['timestamp'] != null
                                      ? (fb['timestamp'] as Timestamp).toDate()
                                      : null;
                              final isMyFeedback =
                                  fb['userId'] == currentUserId;

                              // ✅ photoUrls 배열만 사용
                              final List<String> photoUrls =
                                  (fb['photoUrls'] is List)
                                      ? List<String>.from(
                                        (fb['photoUrls'] as List).where(
                                          (e) =>
                                              e is String &&
                                              e.trim().isNotEmpty,
                                        ),
                                      )
                                      : <String>[];

                              return Card(
                                color: isMyFeedback ? Colors.yellow[200] : null,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 1행: 평점 + 날짜
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$rating/5",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (time != null)
                                            Text(
                                              '${time.year}-${time.month}-${time.day}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 6),

                                      // 2행: 메모
                                      if (comment.isNotEmpty)
                                        Text(
                                          comment,
                                          style: const TextStyle(fontSize: 13),
                                        ),

                                      const SizedBox(height: 6),

                                      // 3행: 옵션 칩
                                      if (features.isNotEmpty)
                                        FeedbackOptionButton(
                                          selectedFeatures: features,
                                          isEditable: false,
                                          onFeaturesChanged: (_) {},
                                        ),

                                      // 4행: 사진들(있으면 맨 하단에 가로로) — 첫 장 포함 전부 썸네일
                                      if (photoUrls.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 76,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: photoUrls.length,
                                            separatorBuilder:
                                                (_, __) =>
                                                    const SizedBox(width: 6),
                                            itemBuilder: (context, i) {
                                              final url = photoUrls[i];
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  url,
                                                  width: 76,
                                                  height: 76,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (c, child, p) =>
                                                          p == null
                                                              ? child
                                                              : const SizedBox(
                                                                width: 76,
                                                                height: 76,
                                                                child: Center(
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                ),
                                                              ),
                                                  errorBuilder:
                                                      (c, e, s) => Container(
                                                        width: 76,
                                                        height: 76,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade200,
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          size: 20,
                                                        ),
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
