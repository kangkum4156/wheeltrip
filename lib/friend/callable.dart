// lib/friend/callable.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/friend/request.dart';

class EmailNorm {
  static String norm(String s) => s.trim().toLowerCase();
  static bool isValid(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}

class CallableGuardianService {
  CallableGuardianService._();

  static final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 공통 유틸 ---

  static String _meEmailOrThrow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw '로그인이 필요합니다.';
    final me = EmailNorm.norm(user.email ?? '');
    if (me.isEmpty) throw '사용자 이메일을 확인할 수 없습니다.';
    return me;
  }

  static Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      final callable = _functions.httpsCallable(name);
      await callable.call(data);
    } on FirebaseFunctionsException catch (e) {
      // 서버 HttpsError가 여기로 매핑됨
      throw '[${e.code}] ${e.message ?? '요청 실패'}';
    } catch (e) {
      throw '알 수 없는 오류: $e';
    }
  }

  // --- 기능들 ---

  /// 초대 보내기
  static Future<void> sendInvite(String toEmailRaw) async {
    final me = _meEmailOrThrow();
    final to = EmailNorm.norm(toEmailRaw);

    if (to.isEmpty) throw '상대 이메일을 입력하세요.';
    if (!EmailNorm.isValid(to)) throw '올바른 이메일 형식이 아닙니다.';
    if (me == to) throw '본인에게 초대할 수 없습니다.';

    await _call('sendGuardianInvite', {'from': me, 'to': to});
  }

  /// 초대 응답
  /// [action] 은 'accepted' 또는 'declined'
  static Future<void> respondInvite({
    required String fromEmailRaw,
    required String action,
  }) async {
    final me = _meEmailOrThrow(); // 수신자
    final from = EmailNorm.norm(fromEmailRaw);

    if (!EmailNorm.isValid(from)) throw '올바른 보낸 사람 이메일이 아닙니다.';
    if (action != 'accepted' && action != 'declined') {
      throw 'action은 accepted 또는 declined 여야 합니다.';
    }

    await _call('respondGuardianInvite', {
      'from': from,
      'to': me,
      'action': action,
    });
  }

  /// 내게 온 PENDING 초대 스트림
  static Stream<List<GuardianRequest>> myPendingInvites() {
    final me = _meEmailOrThrow();
    final q = _firestore
        .collection('users')
        .doc(me)
        .collection('guardian_requests')
        .where('status', isEqualTo: 'pending');

    return q.snapshots().map(
          (s) => s.docs.map(GuardianRequest.fromDoc).toList(growable: false),
    );
  }

  /// 친구(보호자) 연결 해제 — 양쪽 counter_email에서 서로 제거
  static Future<void> removeFriend(String otherEmailRaw) async {
    final me = _meEmailOrThrow();
    final other = EmailNorm.norm(otherEmailRaw);

    if (other.isEmpty) throw '상대 이메일이 올바르지 않습니다.';
    if (!EmailNorm.isValid(other)) throw '올바른 이메일 형식이 아닙니다.';
    if (me == other) throw '본인은 삭제할 수 없습니다.';

    // 서버는 removeFriend / removeGuardianLink 둘 다 동일 동작
    await _call('removeGuardianLink', {'me': me, 'other': other});
  }
}
