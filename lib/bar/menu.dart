import 'package:flutter/material.dart';
import 'package:wheeltrip/bar/guardian_add.dart';
import 'package:wheeltrip/bar/delete_firebase.dart';

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
        case _AppMenuAction.addGuardian:
          final email = await _promptGuardianEmail(context);
          if (email != null && email.isNotEmpty) {
            try {
              await GuardianAdd.addGuardianEmail(email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('보호자 추가 완료: $email')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            }
          }
          break;
        case _AppMenuAction.logout:
          await onLogout();
          break;
        case _AppMenuAction.delete:
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DeleteFirebase()),
          );
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: _AppMenuAction.addGuardian,
        child: ListTile(
          leading: Icon(Icons.person_add),
          title: Text('보호자 추가'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.logout,
        child: ListTile(
          leading: Icon(Icons.logout),
          title: Text('로그아웃'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: _AppMenuAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete),
          title: Text('삭제'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
    ],
  );
}

enum _AppMenuAction { addGuardian, logout, delete}

/// 보호자 이메일 입력 다이얼로그
Future<String?> _promptGuardianEmail(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('보호자 추가'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: '보호자 이메일을 입력하세요',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      );
    },
  );
}
