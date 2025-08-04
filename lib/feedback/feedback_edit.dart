import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void showEditFeedbackSheet({
  required BuildContext context,
  required String googlePlaceId,
  required String feedbackId,
  required Map<String, dynamic> existingData,
}) {
  TextEditingController memoController = TextEditingController(text: existingData['comment'] ?? '');
  int selectedEmotion = existingData['rating'] ?? 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("피드백 수정", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: memoController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final score = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => selectedEmotion = score),
                    child: Icon(Icons.face, size: 36, color: selectedEmotion >= score ? Colors.orange : Colors.grey),
                  );
                }),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("수정 완료"),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('places')
                      .doc(googlePlaceId)
                      .collection('feedbacks')
                      .doc(feedbackId)
                      .update({
                    'comment': memoController.text,
                    'rating': selectedEmotion,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
              )
            ],
          ),
        ),
      );
    },
  );
}
