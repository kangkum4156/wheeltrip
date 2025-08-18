import 'package:flutter/material.dart';
import 'package:wheeltrip/friend/callable.dart';
import 'package:wheeltrip/friend/request.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('받은 친구 초대')),
      body: StreamBuilder<List<GuardianRequest>>(
        stream: CallableGuardianService.myPendingInvites(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('오류: ${snap.error}', textAlign: TextAlign.center),
            ));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('받은 초대가 없습니다.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = items[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(r.from),
                subtitle: Text('상태: ${r.status}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '수락',
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        try {
                          await CallableGuardianService.respondInvite(
                            fromEmailRaw: r.from,
                            action: 'accepted',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${r.from} 님과 연결되었습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('에러: $e')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: '거절',
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () async {
                        try {
                          await CallableGuardianService.respondInvite(
                            fromEmailRaw: r.from,
                            action: 'declined',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${r.from} 님 초대를 거절했습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('에러: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
