import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/signin/main_login.dart';
import 'package:wheeltrip/map/map_view.dart';
import 'package:wheeltrip/alarm/emergency_button.dart';
import 'package:wheeltrip/realtime_location/location_tracker.dart';
import 'package:wheeltrip/bar/menu.dart';

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  @override
  void initState() {
    super.initState();
    LocationTracker.start();
  }

  @override
  void dispose() {
    LocationTracker.stop();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
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
          buildAppMenuButton(
            context: context,
            onLogout: () => _logout(context),
          ),
        ],
      ),
      body: const Stack(
        children: [
          MapView(),
          EmergencyButton(),
        ],
      ),
    );
  }
}
