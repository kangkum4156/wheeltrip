import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 이름 가져오기용

Future<void> updateRealtimeLocation() async {
  // 위치 권한 확인
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception("❌ 위치 권한이 거부되었습니다.");
    }
  }

  // 현재 위치
  final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  // 로그인한 사용자 정보
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("로그인 상태가 아닙니다.");

  // Firestore에서 사용자 이름 가져오기
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
  final name = userDoc.data()?['name'] ?? '이름없음';

  // Realtime DB에 저장
  await FirebaseDatabase.instance.ref('real_location/${user.uid}').set({
    'name': name,
    'email': user.email,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  print('📍 위치 + 이름이 전송되었습니다!');
}
