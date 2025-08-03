import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/map/feedback_add.dart'; // 피드백 등록 화면 불러오기

void showFeedbackViewSheet({
  required BuildContext context,
  required String placeId,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
}) {
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
                // 장소 기본 정보
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('📍 주소: $address'),
                Text('📞 전화번호: $phone'),
                const SizedBox(height: 4),
                Text('🕒 운영 시간:', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(openingHours),
                const SizedBox(height: 8),

                // 평균 평점
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('places')
                      .doc(placeId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
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

                // "피드백 추가하기" 버튼
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_comment),
                    label: const Text("피드백 추가하기"),
                    onPressed: () {
                      Navigator.pop(context); // 기존 보기 바텀시트 닫기
                      showFeedbackAddSheet(
                        context: context,
                        name: name,
                        address: address,
                        latLng: latLng,
                        phone: phone,
                        openingHours: openingHours,
                        onSaveComplete: () async {
                          // 저장 후 다시 보기 바텀시트 열기
                          showFeedbackViewSheet(
                            context: context,
                            placeId: placeId,
                            name: name,
                            address: address,
                            latLng: latLng,
                            phone: phone,
                            openingHours: openingHours,
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                const Text('📋 등록된 피드백', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),

                // 등록된 피드백 리스트
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('places')
                        .doc(placeId)
                        .collection('feedbacks')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('아직 등록된 피드백이 없습니다.'));
                      }
                      final feedbacks = snapshot.data!.docs;
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: feedbacks.length,
                        itemBuilder: (context, index) {
                          final fb = feedbacks[index].data() as Map<String, dynamic>;
                          final userName = fb['userName'] ?? '익명';
                          final rating = fb['rating'] ?? 0;
                          final comment = fb['comment'] ?? '';
                          final time = fb['timestamp'] != null
                              ? (fb['timestamp'] as Timestamp).toDate()
                              : null;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(userName.isNotEmpty ? userName[0] : '?'),
                              ),
                              title: Text('$userName - ${rating}/5'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment),
                                  if (time != null)
                                    Text(
                                      '${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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

                // 닫기 버튼
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
