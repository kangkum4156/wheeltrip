import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/signin/main_login.dart';
import 'package:wheeltrip/map/map_view.dart';
import 'package:wheeltrip/alarm/emergency_button.dart';
import 'package:wheeltrip/realtime_location/location_tracker.dart';

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  @override
  void initState() {
    super.initState();
    LocationTracker.start(); // ✅ 위치 자동 전송 시작
  }

  @override
  void dispose() {
    LocationTracker.stop(); // ✅ 화면 나갈 때 타이머 정리
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
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
      body: Stack(
        children: const [
          MapView(),
          EmergencyButton(),
        ],
      ),
    );
  }
}
