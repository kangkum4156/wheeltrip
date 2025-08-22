// lib/bar/menu.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:wheeltrip/profile/profile.dart';
import 'package:wheeltrip/bar/delete_firebase.dart';
import 'package:wheeltrip/friend/friend_list.dart';
import 'package:wheeltrip/friend/request.dart';
import 'package:wheeltrip/friend/callable.dart';

// main.dart에 선언된 startCallback()을 사용해 서비스 시작
import 'package:wheeltrip/main.dart' show startCallback;

/// 홈 AppBar에 붙일 메뉴 버튼 위젯
Widget buildAppMenuButton({
  required BuildContext context,
  required Future<void> Function() onLogout,
}) {
  return PopupMenuButton<_AppMenuAction>(
    tooltip: '메뉴',
    icon: const Icon(Icons.menu),
    onSelected: (action) async {
      switch (action) {
        case _AppMenuAction.manageAccount:
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          break;

        case _AppMenuAction.addFriend:
          final email = await _promptEmail(context, title: '친구 추가', hint: '상대 이메일(소문자)을 입력하세요');
          if (email != null && email.isNotEmpty) {
            try {
              await CallableGuardianService.sendInvite(email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('초대 전송 완료: $email')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('에러: $e')),
                );
              }
            }
          }
          break;

        case _AppMenuAction.friendRequests:
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
          break;

        case _AppMenuAction.friends:
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendListScreen()));
          break;

        case _AppMenuAction.bgLocation: // ✅ 백그라운드 위치 전송 설정 화면
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundLocationScreen()));
          break;

        case _AppMenuAction.logout:
          await onLogout();
          break;

        case _AppMenuAction.delete:
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteFirebase()));
          break;
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: _AppMenuAction.manageAccount,
        child: ListTile(
          leading: Icon(Icons.manage_accounts),
          title: Text('계정 관리'),
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.addFriend,
        child: ListTile(
          leading: Icon(Icons.person_add),
          title: Text('친구 추가'),
          subtitle: Text('상대에게 초대를 보냅니다'),
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.friendRequests,
        child: ListTile(
          leading: Icon(Icons.inbox),
          title: Text('친구 수락'),
          subtitle: Text('받은 초대 목록 보기'),
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.friends,
        child: ListTile(
          leading: Icon(Icons.group),
          title: Text('친구 목록'),
          dense: true,
        ),
      ),
      // ✅ 백그라운드 위치 전송 on/off 메뉴
      PopupMenuItem(
        value: _AppMenuAction.bgLocation,
        child: ListTile(
          leading: Icon(Icons.location_on),
          title: Text('백그라운드 위치 전송'),
          subtitle: Text('앱을 실행하지 않아도 위치 업로드'),
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.logout,
        child: ListTile(
          leading: Icon(Icons.logout),
          title: Text('로그아웃'),
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete),
          title: Text('삭제'),
          dense: true,
        ),
      ),
    ],
  );
}

enum _AppMenuAction {
  manageAccount,
  addFriend,
  friendRequests,
  friends,
  bgLocation, // ✅ 추가
  logout,
  delete,
}

Future<String?> _promptEmail(BuildContext context, {required String title, required String hint}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('확인')),
        ],
      );
    },
  );
}

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('받은 친구 초대')),
      body: StreamBuilder<List<GuardianRequest>>(
        // 🔑 받은 초대 실시간 구독
        stream: CallableGuardianService.myPendingInvites(),
        builder: (context, snap) {
          // ❗ 인덱스/권한 문제를 바로 볼 수 있도록 에러 출력
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('오류: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
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

/// ✅ 백그라운드 위치 전송 ON/OFF 화면
class BackgroundLocationScreen extends StatefulWidget {
  const BackgroundLocationScreen({super.key});

  @override
  State<BackgroundLocationScreen> createState() => _BackgroundLocationScreenState();
}

class _BackgroundLocationScreenState extends State<BackgroundLocationScreen> {
  bool _bgOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final on = p.getBool('bg_location_on') ?? false;
    setState(() {
      _bgOn = on;
      _loading = false;
    });
  }

  Future<void> _save(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bg_location_on', on);
  }

  Future<void> _start() async {
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
        notificationTitle: '실시간 위치 전송 중',
        notificationText: '앱을 종료해도 계속 전송됩니다.',
        callback: startCallback, // main.dart의 콜백
      );
    }
  }

  Future<void> _stop() async {
    await FlutterForegroundTask.stopService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('백그라운드 위치 전송')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('백그라운드에서 위치 전송'),
              subtitle: const Text('앱을 실행하지 않아도 주기적으로 위치를 업로드합니다'),
              value: _bgOn,
              onChanged: (v) async {
                setState(() => _bgOn = v);
                await _save(v);
                if (v) {
                  await _start();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('백그라운드 위치 전송 시작')),
                    );
                  }
                } else {
                  await _stop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('백그라운드 위치 전송 중지')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '안내',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Android 10+에서는 위치 권한을 "항상 허용"으로 설정해야 합니다.\n'
                  '• Android 13+에서는 알림 권한을 허용해야 서비스가 유지됩니다.\n'
                  '• 상단 알림이 보이는 동안 서비스는 실행 중입니다.',
            ),
          ],
        ),
      ),
    );
  }
}
