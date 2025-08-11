import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/feedback/feedback_add.dart';
import 'package:wheeltrip/feedback/feedback_edit.dart';
import 'package:wheeltrip/feedback/feedback_option_button.dart';

void showFeedbackViewSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required Future<void> Function() onMarkerReset,
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
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 장소 기본 정보
                Text(name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('📍 주소: $address'),
                Text('📞 전화번호: $phone'),
                const SizedBox(height: 4),
                Text('🕒 운영 시간:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(openingHours),
                const SizedBox(height: 8),

                /// 평균 평점
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('places')
                      .doc(googlePlaceId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final data =
                    snapshot.data!.data() as Map<String, dynamic>?;
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

                /// 피드백 추가/수정 버튼
                if (user != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('places')
                        .doc(googlePlaceId)
                        .collection('feedbacks')
                        .where('userId', isEqualTo: user.uid)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasFeedback =
                          snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                      if (hasFeedback) {
                        final feedbackDoc = snapshot.data!.docs.first;
                        return Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text("피드백 수정하기"),
                            onPressed: () {
                              Navigator.pop(context);
                              showEditFeedbackSheet(
                                context: context,
                                googlePlaceId: googlePlaceId,
                                feedbackId: feedbackDoc.id,
                                existingData: feedbackDoc.data()
                                as Map<String, dynamic>,
                              );
                            },
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
                const Text('📋 등록된 피드백',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),

                /// 피드백 리스트
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('places')
                        .doc(googlePlaceId)
                        .collection('feedbacks')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('아직 등록된 피드백이 없습니다.'));
                      }

                      final feedbacks = snapshot.data!.docs;
                      final currentUserId =
                          FirebaseAuth.instance.currentUser?.uid;

                      final sortedFeedbacks = [ // 내 피드백이 가장 위로 올라오도록
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
                        controller: scrollController,
                        itemCount: sortedFeedbacks.length,
                        itemBuilder: (context, index) {
                          final fb = sortedFeedbacks[index].data()
                          as Map<String, dynamic>;
                          final rating = fb['rating'] ?? 0;
                          final comment = fb['comment'] ?? '';
                          final features =
                          List<String>.from(fb['features'] ?? []);
                          final time = fb['timestamp'] != null
                              ? (fb['timestamp'] as Timestamp).toDate()
                              : null;
                          final isMyFeedback =
                              fb['userId'] == currentUserId;

                          return Card(
                            color: isMyFeedback
                                ? Colors.yellow[200]
                                : null,
                            margin:
                            const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  /// 1행: 평점 + 메모
                                  Row(
                                    children: [
                                      Icon(Icons.star,
                                          color: Colors.orange,
                                          size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$rating/5",
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(comment)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  /// 2행: 선택된 features 버튼들 (보기 전용)
                                  if (features.isNotEmpty)
                                    FeedbackOptionButton(
                                      selectedFeatures: features,
                                      isEditable: false,
                                      onFeaturesChanged: (_) {},
                                    ),
                                  if (features.isNotEmpty)
                                    const SizedBox(height: 4),

                                  /// 3행: 날짜 (우측 하단)
                                  if (time != null)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        '${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                /// 닫기 버튼
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
