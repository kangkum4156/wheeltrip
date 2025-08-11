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
          final listHeight = screen.height * 0.35; // 피드백 리스트 고정 높이

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
                /// 📌 평균 평점
                Text("평균 평점: ${avgRate.toStringAsFixed(1)}"),

                const SizedBox(height: 8),

                /// 📌 평가 버튼 구간 — 직접 구현
                if (feedbackExists) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        child: const Text('수정하기'),
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
                      const SizedBox(width: 16),
                      ElevatedButton(
                        child: const Text('삭제하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              content: const Text('내 피드백을 삭제할까요?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await deleteRoadFeedback(routeId);
                            reloadRoutes();
                          }
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton(
                    child: const Text('경로 평가하기'),
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

                const SizedBox(height: 10),
                const Text(
                  '📋 등록된 피드백',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                /// 📌 피드백 리스트 고정 영역
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    itemCount: allFeedbacks.length,
                    itemBuilder: (context, index) {
                      final fb = allFeedbacks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            "${fb['userName']} (${fb['userEmail']})",
                          ),
                          subtitle: Text(
                            "별점: ${fb['rate']} - 특성: ${fb['features'].join(', ')}",
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