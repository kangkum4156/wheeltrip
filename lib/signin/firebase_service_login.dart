import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ FCM 추가
import 'package:wheeltrip/data/const_data.dart';

/// 로그인
Future<int> signIn(String email, String password) async {
  try {
    // 🔐 Firebase 인증으로 로그인 시도
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    final user = userCredential.user;

    if (user != null) {
      // ✅ Firestore에서 유저 데이터 로드 → 전역 변수 저장
      await loadUserData(email);

      // ✅ 로그인 후 FCM 토큰 저장
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .set({'token': token}, SetOptions(merge: true));
        print('✅ 로그인 후 FCM 토큰 저장 완료: $token');
      }

      return 1; // 로그인 성공
    } else {
      return 0; // 로그인 실패
    }
  } on FirebaseAuthException catch (e) {
    print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
    return 0;
  } catch (e) {
    print('❌ 기타 오류: $e');
    return 0;
  }
}

/// 이메일 중복 확인
Future<bool> isEmailDuplicate(String email) async {
  final doc =
  await FirebaseFirestore.instance.collection('users').doc(email).get();
  return doc.exists;
}

/// 비밀번호 재설정 이메일 전송
Future<void> sendPasswordResetEmail(String email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    print("📩 비밀번호 재설정 이메일 전송 완료");
  } catch (e) {
    print("❌ 비밀번호 재설정 실패: $e");
    rethrow;
  }
}

/// 아이디(이메일) 찾기 기능
Future<String?> findEmailByNameAndPhone(String name, String phone) async {
  print("🔍 이메일 찾기: name: $name, phone: $phone");

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('name', isEqualTo: name)
      .where('phone', isEqualTo: phone)
      .get();

  if (snapshot.docs.isEmpty) return null;

  return snapshot.docs.first.id; // 문서 ID = 이메일
}

/// 로그인한 유저 정보 불러오기
Future<void> loadUserData(String email) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();

  if (snapshot.docs.isNotEmpty) {
    final userDoc = snapshot.docs.first;
    final data = userDoc.data();

    user_email = data['email'];
    user_name = data['name'];
    user_phone = data['phone'];
    user_mode = data['mode'];
    user_counterEmail = List<String>.from(data['counter_email'] ?? []);
    user_location = data['location'];

    // 저장 장소 목록 로딩
    final savedPlacesSnapshot =
    await userDoc.reference.collection('saved_places').get();

    final List<Map<String, dynamic>> savedPlaces =
    savedPlacesSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    user_savedPlaces = savedPlaces;

    print('✅ 저장된 장소 개수: ${savedPlaces.length}');
  }
}

Future<void> addCounterEmail(String myEmail, String newCounterEmail) async {
  final userRef =
  FirebaseFirestore.instance.collection('users').doc(myEmail);

  try {
    // Firestore 트랜잭션으로 중복 확인 및 배열 업데이트
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception("사용자 문서가 존재하지 않음");
      }

      final data = snapshot.data()!;
      final List<dynamic> counterEmails = data['counter_email'] ?? [];

      // 이미 존재하는 경우 무시
      if (counterEmails.contains(newCounterEmail)) {
        print("⚠️ 이미 등록된 보호자입니다.");
        return;
      }

      counterEmails.add(newCounterEmail);

      transaction.update(userRef, {'counter_email': counterEmails});
      print("✅ 보호자 이메일 추가 완료");
    });
  } catch (e) {
    print("❌ 보호자 추가 실패: $e");
  }
}

