import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/road/road_feedback_options.dart';

typedef OnNewRouteSavedCallback = Future<void> Function(List<LatLng> coords, int rate, List<String> features);

Future<bool?> showNewBottomSheet({
  required BuildContext context,
  required List<LatLng> coords,
  required OnNewRouteSavedCallback onRouteSaved,
}) {
  int selectedRate = 3; // 기본 평점 3점
  List<String> selectedFeatures = [];

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("새로운 경로를 평가해주세요."),
                SizedBox(height: 12),

                // 별점 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    int starIndex = index + 1;
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        selectedRate >= starIndex ? Icons.star : Icons.star_border,
                        color: selectedRate >= starIndex ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedRate = starIndex;
                        });
                      },
                    );
                  }),
                ),

                SizedBox(height: 16),

                // features 체크박스
                RoadFeedbackOptions(
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

                SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    await onRouteSaved(coords, selectedRate, selectedFeatures);
                    Navigator.pop(context, true);
                  },
                  child: Text("경로 생성하기"),
                ),

                SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}
