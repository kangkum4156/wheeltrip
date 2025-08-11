import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef OnNewRouteSavedCallback = Future<void> Function(List<LatLng> coords, int rate, List<String> features);

Future<bool?> showNewBottomSheet({
  required BuildContext context,
  required List<LatLng> coords,
  required OnNewRouteSavedCallback onRouteSaved,
}) {
  int selectedRate = 3; // 기본 평점 3점
  List<String> selectedFeatures = [];

  final List<String> featureOptions = ['경사로', '차도', '인도'];

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
          void toggleFeature(String feature) {
            if (selectedFeatures.contains(feature)) {
              selectedFeatures.remove(feature);
            } else {
              selectedFeatures.add(feature);
            }
            setState(() {});
          }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: featureOptions.map((feature) {
                    final isSelected = selectedFeatures.contains(feature);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (checked) {
                            toggleFeature(feature);
                          },
                        ),
                        Text(feature),
                        SizedBox(width: 12),
                      ],
                    );
                  }).toList(),
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
