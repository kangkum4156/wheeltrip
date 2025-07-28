import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/mode/select_mode.dart';


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Firestore에서 mode 필드 유무 확인
  Future<bool> _hasModeField(String email) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
    final data = doc.data();
    return data != null && data.containsKey('mode');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return FutureBuilder<bool>(
      future: _hasModeField(user.email!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hasMode = snapshot.data ?? false;
        return hasMode ? const HomeBody() : const SelectMode();
      },
    );
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        backgroundColor: Colors.blue, // 앱바 색상 (원하면 수정 가능)
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              '환영합니다!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'HomeBody 화면입니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
