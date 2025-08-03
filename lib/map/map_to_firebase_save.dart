import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart'; // user_email 사용

class SavePlace extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String comment;
  final int rating;
  final String name;
  final String phone;
  final String time;
  final String address;
  final Function(Marker) onSaveComplete;
  final bool saveToUserSavedPlaces; // ★ 추가

  const SavePlace({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.comment,
    required this.rating,
    required this.name,
    required this.phone,
    required this.time,
    required this.address,
    required this.onSaveComplete,
    this.saveToUserSavedPlaces = false, // 기본 false
  });

  Future<void> savePlace(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      // 1. 장소 존재 여부 확인
      QuerySnapshot existing = await firestore
          .collection('places')
          .where('latitude', isEqualTo: latitude)
          .where('longitude', isEqualTo: longitude)
          .limit(1)
          .get();

      DocumentReference placeRef;
      String placeId;

      if (existing.docs.isEmpty) {
        placeRef = await firestore.collection('places').add({
          'latitude': latitude,
          'longitude': longitude,
          'name': name,
          'phone': phone,
          'time': time,
          'address': address,
          'avgRating': rating.toDouble(),
        });
        placeId = placeRef.id;
      } else {
        placeRef = existing.docs.first.reference;
        placeId = placeRef.id;
      }

      // 2. feedback 저장
      await placeRef.collection('feedbacks').add({
        'userId': user.uid,
        'userName': user.displayName ?? '익명',
        'rating': rating,
        'comment': comment,
        'photoUrl': '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. 평균 평점 업데이트
      final feedbacksSnapshot = await placeRef.collection('feedbacks').get();
      if (feedbacksSnapshot.docs.isNotEmpty) {
        final total = feedbacksSnapshot.docs
            .map((doc) => (doc['rating'] as int))
            .reduce((a, b) => a + b);
        final avg = total / feedbacksSnapshot.docs.length;
        await placeRef.update({'avgRating': avg});
      }

      // 4. ★ 사용자의 saved_places에 placeId만 저장
      if (saveToUserSavedPlaces) {
        await firestore
            .collection('users')
            .doc(user_email)
            .collection('saved_places')
            .doc(placeId)
            .set({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. 마커 생성 후 콜백
      final marker = Marker(
        markerId: MarkerId(placeId),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: name,
          snippet: '$comment\n평점: $rating/5\n전화번호: $phone',
        ),
      );

      onSaveComplete(marker);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('피드백이 저장되었습니다.')),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.bookmark_add),
      label: const Text('피드백 저장'),
      onPressed: () => savePlace(context),
    );
  }
}
