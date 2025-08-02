import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/signin/main_login.dart';
import 'package:wheeltrip/map/map_view.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeBody();
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut(); // Firebase 로그아웃
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 뒤로가기 불가
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: const MapView(),
    );
  }
}
