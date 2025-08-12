import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/road/road_feedback_add.dart';
import 'package:wheeltrip/road/road_feedback_edit.dart';
import 'package:wheeltrip/road/road_feedback_delete.dart';
import 'package:wheeltrip/road/road_save_load.dart';
import 'package:wheeltrip/data/const_data.dart';

Future<void> onPolylineTap({
  required BuildContext context,
  required String routeId,
  required List<LatLng> coords,
  required double avgRate,
  required String? userEmail,
  required Future<void> Function() reloadRoutes,
} ) async {
  int myRate = await RoadFirestoreService.getUserRateForRoute(
    userEmail: user_email,
    routeId: routeId,
  );

  List<String>? myFeatures = await RoadFirestoreService.getUserFeatures(
    userEmail: user_email,
    routeId: routeId,
  );

  bool feedbackExists = await RoadFirestoreService.checkUserFeedbackExists(
    userEmail: user_email,
    routeId: routeId,
  );

  List<Map<String, dynamic>> allFeedbacks =
  await RoadFirestoreService.loadFeedbacks(routeId);

  final myFeedbacks = allFeedbacks.where((fb) => fb['userEmail'] == user_email).toList();
  final otherFeedbacks = allFeedbacks.where((fb) => fb['userEmail'] != user_email).toList();

  // 두 리스트 합치기
  final feedbackList = [...myFeedbacks, ...otherFeedbacks];

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
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final screen = MediaQuery.of(context).size;
          final listHeight = screen.height * 0.35;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: ListView(
              controller: scrollController,
              children: [
                /// 📌 헤더
                Row(
                  children: [
                    const Icon(Icons.feedback, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    const Text(
                      "경로 피드백",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.star, color: Colors.amber),
                    Text(
                      avgRate.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// 📌 평가 버튼 영역
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (feedbackExists) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('수정하기'),
                          onPressed: () {
                            Navigator.pop(context);
                            showEditFeedbackBottomSheet(
                              context: context,
                              initialRate: myRate,
                              initialFeatures: myFeatures,
                              onFeedbackUpdated: (updatedRate, updatedFeatures) async {
                                await updateRoadFeedback(routeId, updatedRate, updatedFeatures);
                                reloadRoutes();
                              },
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('삭제하기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("삭제 확인"),
                                  content: const Text("내 피드백을 삭제할까요?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false), // Alert만 닫기
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true), // Alert만 닫기
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await deleteRoadFeedback(routeId);
                                reloadRoutes();

                                // 여기서 바텀시트 닫기
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_comment),
                          label: const Text('경로 평가하기'),
                          onPressed: () {
                            Navigator.pop(context);
                            showAddRoadFeedbackBottomSheet(
                              routeId: routeId,
                              context: context,
                              onRouteSaved: (routeId, rate, features) async {
                                await addRoadFeedback(routeId, rate, features);
                                reloadRoutes();
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),

                /// 📌 피드백 리스트 타이틀
                const Text(
                  '📋 등록된 피드백',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                /// 📌 피드백 리스트
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    itemCount: feedbackList.length,
                    itemBuilder: (context, index) {
                      final fb = feedbackList[index];
                      final isMyFeedback = (fb['userEmail'] == user_email);

                      return Card(
                        color: isMyFeedback ? Colors.yellow[100] : null,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                fb['userName'] ?? '익명',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              Text("${fb['rate']}"),
                            ],
                          ),
                          subtitle: Text(
                            "특성: ${fb['features'].join(', ')}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      );
                    },
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