import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/friend/callable.dart';

class FriendListScreen extends StatelessWidget {
  const FriendListScreen({super.key});

  Stream<List<_FriendRow>> _friendsStream() {
    final me = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();

    final q = FirebaseFirestore.instance
        .collection('users')
        .where('counter_email', arrayContains: me);

    return q.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return _FriendRow(
          email: (data['email'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          photoUrl: (data['profileImageUrl'] ?? '').toString(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 목록')),
      body: StreamBuilder<List<_FriendRow>>(
        stream: _friendsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('오류: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('연결된 친구가 없습니다.'));
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (f.photoUrl.isNotEmpty) ? NetworkImage(f.photoUrl) : null,
                  child: f.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(f.name.isNotEmpty ? f.name : f.email),
                subtitle: Text(f.email),
                trailing: IconButton(
                  tooltip: '연결 해제',
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('친구 삭제'),
                        content: Text('${f.email} 님과의 연결을 해제할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      await CallableGuardianService.removeFriend(f.email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${f.email} 님과의 연결을 해제했습니다.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('삭제 실패: $e')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FriendRow {
  final String email;
  final String name;
  final String photoUrl;
  _FriendRow({required this.email, required this.name, required this.photoUrl});
}
