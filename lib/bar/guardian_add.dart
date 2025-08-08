import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuardianAdd {
  /// Firestore users/{내이메일} 문서의 counter_email(List)에 email을 추가
  static Future<void> addGuardianEmail(String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw '로그인이 필요합니다.';
    }

    final myEmail = user.email?.trim();
    if (myEmail == null || myEmail.isEmpty) {
      throw '사용자 이메일을 확인할 수 없습니다.';
    }

    final target = email.trim();
    if (target.isEmpty) {
      throw '이메일을 입력하세요.';
    }
    if (target.toLowerCase() == myEmail.toLowerCase()) {
      throw '본인을 보호자로 추가할 수 없습니다.';
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myEmail) // 문서 ID가 이메일인 구조
          .update({
        'counter_email': FieldValue.arrayUnion([target]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(myEmail)
            .set({
          'counter_email': [target],
        }, SetOptions(merge: true));
      } else {
        throw '추가 실패: ${e.message ?? e.code}';
      }
    }
  }
}
