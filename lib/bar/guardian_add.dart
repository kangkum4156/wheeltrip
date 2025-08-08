import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuardianAdd {
  static String _norm(String s) => s.trim().toLowerCase();

  static Future<void> addGuardianEmail(String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw '로그인이 필요합니다.';
    }

    final myEmailRaw = user.email ?? '';
    final targetRaw  = email;

    final me    = _norm(myEmailRaw);
    final other = _norm(targetRaw);

    if (me.isEmpty) throw '사용자 이메일을 확인할 수 없습니다.';
    if (other.isEmpty) throw '이메일을 입력하세요.';
    if (me == other) throw '본인을 보호자로 추가할 수 없습니다.';

    final users = FirebaseFirestore.instance.collection('users');
    final meRef = users.doc(me);
    final otherRef = users.doc(other);

    final myDoc = await meRef.get();
    if (myDoc.exists) {
      final counterList = (myDoc.data()?['counter_email'] as List?) ?? [];
      if (counterList.map((e) => e.toString().toLowerCase()).contains(other)) {
        throw '이미 추가된 보호자입니다.';
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      meRef,
      {
        'email': me,
        'counter_email': FieldValue.arrayUnion([other]),
      },
      SetOptions(merge: true),
    );

    batch.set(
      otherRef,
      {
        'email': other,
        'counter_email': FieldValue.arrayUnion([me]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
