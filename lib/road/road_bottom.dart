import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef OnRouteSavedCallback = Future<void> Function(List<LatLng> coords, int rate);

Future<bool?> showRateBottomSheet({
  required int myRate,
  required BuildContext context,
  required List<LatLng> coords,
  required OnRouteSavedCallback onRouteSaved,
  int? initialRate,
  double? avgRate,
}) {
  int selectedRate = initialRate ?? 3;

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
                SizedBox(height: 8),
                Text("이 경로의 편의도를 별점으로 평가해주세요."),
                if (avgRate != null) ...[
                  SizedBox(height: 8),
                  Text(
                    "평균 평점: ${avgRate.toStringAsFixed(1)}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                ],
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
                ElevatedButton(
                  onPressed: () async {
                    await onRouteSaved(coords, selectedRate);
                    Navigator.pop(context, true);
                  },
                  child: Text(myRate == 0 ? "저장" : "수정"),
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
