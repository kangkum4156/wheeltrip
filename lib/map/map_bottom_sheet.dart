import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/map/map_to_firebase_save.dart';

void showPlaceBottomSheet({
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
        builder:
            (context, setState) => Padding(
              padding: MediaQuery.of(
                context,
              ).viewInsets.add(const EdgeInsets.all(16.0)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 주소
                    Text('📍 주소: $address'),
                    const SizedBox(height: 4),

                    // 전화번호
                    Text('📞 전화번호: $phone'),
                    const SizedBox(height: 4),

                    // 운영 시간
                    Text(
                      '🕒 운영 시간:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(openingHours),
                    const SizedBox(height: 8),

                    const Divider(),

                    // 메모 입력란
                    const SizedBox(height: 8),
                    Text(
                      '💬 메모:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: memoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '메모를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      '😀 편의도 평가 :',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final score = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedEmotion = score;
                            });
                          },
                          child: Icon(
                            Icons.face,
                            size: 36,
                            color:
                                selectedEmotion >= score
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: SavePlace(
                        latitude: latLng.latitude,
                        longitude: latLng.longitude,
                        info: memoController.text,
                        rate: selectedEmotion,
                        name: name,
                        phone: phone,
                        address: address,
                        time: openingHours,
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

// Firestore 마커 탭용 함수 (매개변수 context 포함)
void showPlaceBottomSheetForMarker({
  required BuildContext context,
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required String info,
  required int rate,
}) {
  final TextEditingController memoController = TextEditingController(text: info);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: MediaQuery.of(
          context,
        ).viewInsets.add(const EdgeInsets.all(16.0)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('📍 주소: $address'),
              Text('📞 전화번호: $phone'),
              Text(
                '🕒 운영 시간:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(openingHours),
              const SizedBox(height: 16),
              const Divider(),
              Text(
                '💬 메모:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: memoController,
                maxLines: 3,
                readOnly: false, // 수정 가능하게 함
                decoration: const InputDecoration(
                  hintText: '메모를 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '😀 편의도 평가 :',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final score = index + 1;
                  return Icon(
                    Icons.face,
                    size: 36,
                    color: rate >= score ? Colors.orange : Colors.grey,
                  );
                }),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
