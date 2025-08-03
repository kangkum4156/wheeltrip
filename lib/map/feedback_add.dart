import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/map/map_to_firebase_save.dart';

void showFeedbackAddSheet({
  required BuildContext context,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required Future<void> Function() onSaveComplete,
}) {
  TextEditingController memoController = TextEditingController();
  int selectedEmotion = 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16.0)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('📍 주소: $address'),
                const SizedBox(height: 4),
                Text('📞 전화번호: $phone'),
                const SizedBox(height: 4),
                Text('🕒 운영 시간:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    saveToUserSavedPlaces: true, // ★ 추가: 저장 시 users/{email}/saved_places에도 등록
                    onSaveComplete: (marker) async {
                      await onSaveComplete();
                      Navigator.pop(context);
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}
