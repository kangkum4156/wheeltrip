import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/data/const_data.dart';

/// 로그인
Future<int> signIn(String email, String password) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    final user = userCredential.user;
    if (user != null) {
      // Firestore → 전역 변수 저장
      await loadUserData(email);
      return 1;
    } else {
      return 0;
    }
  } on FirebaseAuthException catch (e) {
    return 0;
  } catch (e) {
    return 0;
  }
}

///email 중복 확인
Future<bool> isEmailDuplicate(String email) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(email).get();
  return doc.exists;
}

///비밀번호 재설정 이메일 전송
Future<void> sendPasswordResetEmail(String email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    print("비밀번호 재설정 이메일 전송 완료");
  } catch (e) {
    print("비밀번호 재설정 실패: $e");
    rethrow;
  }
}

///아이디(이메일) 찾기 기능
Future<String?> findEmailByNameAndPhone(String name, String phone) async {
  print("DEBUG: 검색 중 - name: $name, phone: $phone");
  final snapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .get();

  if (snapshot.docs.isEmpty) return null;

  return snapshot.docs.first.id; // 문서 ID = 이메일
}

/// 로그인한 유저 정보 불러오기
Future<void> loadUserData(String email) async {
  final snapshot =
      await FirebaseFirestore.instance
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
    user_counterEmail = data['counter_email'];
    user_location = data['location'];

    final savedPlacesSnapshot =
        await userDoc.reference.collection('saved_places').get();
    final List<Map<String, dynamic>> savedPlaces =
        savedPlacesSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

    user_savedPlaces = savedPlaces;
    print('저장 개수 : ${savedPlaces.length}');
  }
}
