import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

///회원가입 - firebase auth로 계정 생성 후, firesotre에 사용자 정보 저장
Future <void> registerToFirestore({
  required String name,
  required String phone,
  required String email,
  required String password,
})
async {
  try {
    /// 1. Firebase Authentication에 계정 생성
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    String uid = userCredential.user!.uid;

    /// 2. Firestore에 사용자 정보 저장
    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'name': name,
      'phone': phone,
      'isApproved': false, // 기본값: 승인되지 않음
    });
  } catch (e) {
    print('회원가입 중 오류 발생: $e');
    rethrow; // 위쪽에서 오류 처리 가능하도록 다시 던짐
  }
}

/// 로그인
Future<int> signIn(String email, String password) async {
  try {
    // Firebase 인증만 수행
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    final user = userCredential.user;
    return user != null ? 1 : 0;
  } on FirebaseAuthException catch (e) {
    return 0; // 로그인 실패
  } catch (e) {
    return 0; // 예외 처리
  }
}

///email 중복 확인
Future<bool> isEmailDuplicate(String email) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
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
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('name', isEqualTo: name)
      .where('phone', isEqualTo: phone)
      .get();

  if (snapshot.docs.isEmpty) return null;

  return snapshot.docs.first.id; // 문서 ID = 이메일
}