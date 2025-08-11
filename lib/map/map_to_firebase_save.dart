import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart'; // user_email, user_savedPlaces

class SavePlace extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String comment;
  final int rating;
  final String name;
  final String phone;
  final String time;
  final String address;
  final String googlePlaceId;
  final Map<String, dynamic>? extraData; // features 등 추가 데이터
  final Function(Marker) onSaveComplete;
  final bool saveToUserSavedPlaces;

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
    required this.googlePlaceId,
    required this.onSaveComplete,
    this.extraData,
    this.saveToUserSavedPlaces = false,
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

      // 이메일 그대로 사용(없으면 uid로 폴백)
      final String feedbackDocId =
      (user.email != null && user.email!.trim().isNotEmpty)
          ? user.email!.trim()
          : user.uid;

      // places/{googlePlaceId}
      final placeRef = firestore.collection('places').doc(googlePlaceId);

      // 장소 문서가 없으면 생성
      final docSnap = await placeRef.get();
      if (!docSnap.exists) {
        await placeRef.set({
          'latitude': latitude,
          'longitude': longitude,
          'name': name,
          'phone': phone,
          'time': time,
          'address': address,
          'avgRating': rating.toDouble(),
        });
      }

      // 피드백 데이터
      final Map<String, dynamic> feedbackData = {
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'userName': user.displayName ?? '익명',
        'rating': rating,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // extraData(features 등) 병합
      if (extraData != null && extraData!.isNotEmpty) {
        feedbackData.addAll(extraData!);
      }

      // 피드백 저장: places/{placeId}/feedbacks/{user.email or uid}
      // 같은 사용자가 다시 저장하면 merge로 갱신
      await placeRef
          .collection('feedbacks')
          .doc(feedbackDocId)
          .set(feedbackData, SetOptions(merge: true));

      // 평균 평점 업데이트
      final feedbacksSnapshot = await placeRef.collection('feedbacks').get();
      if (feedbacksSnapshot.docs.isNotEmpty) {
        final total = feedbacksSnapshot.docs
            .map((d) => (d.data()['rating'] as num?) ?? 0)
            .fold<num>(0, (a, b) => a + b);
        final avg = total / feedbacksSnapshot.docs.length;
        await placeRef.update({'avgRating': avg});
      }

      // 사용자 saved_places 에 추가(옵션)
      if (saveToUserSavedPlaces) {
        final createdAt = FieldValue.serverTimestamp();
        await firestore
            .collection('users')
            .doc(user_email) // 기존 앱 로직 유지
            .collection('saved_places')
            .doc(googlePlaceId)
            .set({
          'createdAt': createdAt,
          'latitude': latitude,
          'longitude': longitude,
        });

        user_savedPlaces.add({
          'id': googlePlaceId,
          'createdAt': createdAt,
          'latitude': latitude,
          'longitude': longitude,
        });
      }

      // 지도 마커 생성
      final marker = Marker(
        markerId: MarkerId(googlePlaceId),
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
