// delete_account.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:wheeltrip/signin/main_login.dart';

class DeleteAccountPage extends StatefulWidget {
  final String email;
  const DeleteAccountPage({super.key, required this.email});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _pwController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _deleteFlow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ensureRecentLogin(widget.email, _pwController.text.trim());
      await _deleteAll(widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정이 삭제되었습니다.')),
      );

      // 삭제/로그아웃 이후 LoginScreen으로 스택 교체
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  // 이메일/비번 사용자만 재인증 (그 외 공급자는 스킵)
  Future<void> _ensureRecentLogin(String email, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      final isPasswordUser = methods.contains('password');
      if (isPasswordUser) {
        if (password.isEmpty) {
          throw Exception('최근 로그인 필요: 비밀번호를 입력해주세요.');
        }
        final cred =
        EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(cred);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }

  // Realtime DB: /real_location 에서 email == 사용자 노드들 제거 (쿼리 + 풀스캔 폴백)
  Future<void> _deleteRealtimeLocations(String email) async {
    // 필요 시 특정 URL 사용:
    // final db = FirebaseDatabase.instanceFor(databaseURL: 'https://<project>-default-rtdb.<region>.firebasedatabase.app');
    final db = FirebaseDatabase.instance;
    final root = db.ref();
    final ref = root.child('real_location');

    // 1) equalTo로 잡히는 키들 삭제
    final qSnap = await ref.orderByChild('email').equalTo(email).get();
    final updates = <String, Object?>{};
    for (final c in qSnap.children) {
      updates['/real_location/${c.key}'] = null;
    }
    if (updates.isNotEmpty) {
      await root.update(updates);
    }

    // 2) 혹시 누락 대비 풀스캔 폴백
    final all = await ref.get();
    final updatesFallback = <String, Object?>{};
    for (final c in all.children) {
      final em = c.child('email').value?.toString();
      if (em == email) {
        updatesFallback['/real_location/${c.key}'] = null;
      }
    }
    if (updatesFallback.isNotEmpty) {
      await root.update(updatesFallback);
    }
  }

  // places/routes 피드백 삭제 후 평균/특징 재계산
  Future<void> _recalcAggregates({
    required DocumentReference parentRef,
    required bool isRoute, // routes면 true, places면 false
  }) async {
    final fbSnap = await parentRef.collection('feedbacks').get();

    double sum = 0.0;
    int count = 0;
    final Map<String, int> featureCounts = {};

    for (final d in fbSnap.docs) {
      final data = d.data();
      final rating = (data['rating'] as num?)?.toDouble();
      if (rating != null) {
        sum += rating;
        count += 1;
      }
      final feats =
          (data['features'] as List?)?.whereType<String>() ?? const [];
      for (final f in feats) {
        featureCounts[f] = (featureCounts[f] ?? 0) + 1;
      }
    }

    if (count > 0) {
      final avg = double.parse((sum / count).toStringAsFixed(2));
      await parentRef.set({
        (isRoute ? 'avgRate' : 'avgRating'): avg,
        'featureCounts': featureCounts,
      }, SetOptions(merge: true));
    } else {
      // 피드백이 0개면 필드 제거(원한다면 0.0 유지로 바꿔도 됨)
      await parentRef.set({
        (isRoute ? 'avgRate' : 'avgRating'): FieldValue.delete(),
        'featureCounts': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  // 사용자 문서의 서브컬렉션 정리
  Future<void> _deleteUserSubcollections(DocumentReference userDocRef) async {
    // // 사용자 요청: guardian_requests 도 함께 정리
    const subcols = ['my_routes', 'saved_places', 'guardian_requests'];
    for (final name in subcols) {
      final qs = await userDocRef.collection(name).get();
      for (final d in qs.docs) {
        await d.reference.delete();
      }
    }
  }

  Future<void> _deleteAll(String email) async {
    final fs = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    final photoUrls = <String>{};

    // 1) users/{email}에서 프로필 URL 수집
    final userDocRef = fs.collection('users').doc(email);
    final userSnap = await userDocRef.get();
    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final u = data['profileImageUrl'] as String?;
      if (u != null && u.isNotEmpty) photoUrls.add(u);
    }

    // 2) 모든 users 문서의 counter_email 배열에서 내 이메일 제거
    //    + 각 문서의 guardian_requests/{내이메일} 문서도 삭제 (문서가 없으면 no-op)
    final usersSnap = await fs.collection('users').get();
    WriteBatch batch = fs.batch();
    int cnt = 0;

    Future<void> commitIfFull() async {
      // Firestore 배치 한도는 500 write → 안전 버퍼로 450에서 커밋
      if (cnt >= 450) {
        await batch.commit();
        batch = fs.batch();
        cnt = 0;
      }
    }

    for (final d in usersSnap.docs) {
      // counter_email 배열에서 제거
      batch.update(d.reference, {
        'counter_email': FieldValue.arrayRemove([email]),
      });
      cnt++;

      // guardian_requests/{삭제하려는유저이메일} 문서 삭제
      final grDoc = d.reference.collection('guardian_requests').doc(email);
      batch.delete(grDoc);
      cnt++;

      await commitIfFull();
    }
    await batch.commit();

    // 3) places/*/feedbacks/{email} 삭제 + photoUrls 수집 + 재계산
    final placesSnap = await fs.collection('places').get();
    for (final p in placesSnap.docs) {
      final fbRef = p.reference.collection('feedbacks').doc(email);
      final fbSnap = await fbRef.get();
      if (fbSnap.exists) {
        final fb = fbSnap.data() as Map<String, dynamic>;
        final urls =
            (fb['photoUrls'] as List?)?.whereType<String>() ??
                const Iterable<String>.empty();
        photoUrls.addAll(urls);
        await fbRef.delete();
        await _recalcAggregates(parentRef: p.reference, isRoute: false);
      }
    }

    // 4) routes/*/feedbacks/{email} 삭제 + photoUrls 수집 + 재계산
    final routesSnap = await fs.collection('routes').get();
    for (final r in routesSnap.docs) {
      final fbRef = r.reference.collection('feedbacks').doc(email);
      final fbSnap = await fbRef.get();
      if (fbSnap.exists) {
        final fb = fbSnap.data() as Map<String, dynamic>;
        final urls =
            (fb['photoUrls'] as List?)?.whereType<String>() ??
                const Iterable<String>.empty();
        photoUrls.addAll(urls);
        await fbRef.delete();
        await _recalcAggregates(parentRef: r.reference, isRoute: true);
      }
    }

    // 5) Realtime Database 정리
    await _deleteRealtimeLocations(email);

    // 6) Storage: 모은 URL 전부 + profile_images/{email}.jpg 삭제
    for (final url in photoUrls) {
      try {
        final ref = storage.refFromURL(url);
        await ref.delete();
      } catch (_) {} // 이미 삭제/잘못된 URL 가능
    }
    try {
      final ref = storage.ref().child('profile_images').child('$email.jpg');
      await ref.delete();
    } catch (_) {}

    // 7) 유저 서브컬렉션 정리 후 사용자 문서 삭제
    try {
      await _deleteUserSubcollections(userDocRef);
    } catch (_) {}
    try {
      await userDocRef.delete(); // 유저 문서 자체 삭제
    } catch (_) {}

    // 8) Auth 계정 삭제 (마지막)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == email) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? e.code);
      }
    }

    // 9) 로그아웃
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 삭제')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이메일: ${widget.email}'),
            const SizedBox(height: 12),
            TextField(
              controller: _pwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 (이메일/비번 로그인 시 필요)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '계정을 삭제하면 작성한 피드백/사진, 위치 로그, 사용자 문서가 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(color: Colors.red),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: Text(_busy ? '삭제 중...' : '영구 삭제'),
                onPressed: _busy
                    ? null
                    : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('정말 삭제할까요?'),
                      content:
                      const Text('모든 데이터가 삭제됩니다. 되돌릴 수 없습니다.'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await _deleteFlow();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
