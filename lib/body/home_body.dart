import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wheeltrip/signin/main_login.dart';
import 'package:wheeltrip/map/map_view.dart';
import 'package:wheeltrip/alarm/emergency_button.dart';
import 'package:wheeltrip/realtime_location/location_tracker.dart';
import 'package:wheeltrip/bar/menu.dart';
import 'package:wheeltrip/road/road_screen.dart';

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  int _selectedModeIndex = 0; // 0: MapView, 1: RoadScreen

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedModeIndex = 0;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            _selectedModeIndex == 0
                                ? Colors.blue[800]
                                : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text(
                        'Map 모드',
                        style: TextStyle(
                          fontSize: _selectedModeIndex == 0 ? 20 : 13,
                          color:
                              _selectedModeIndex == 0
                                  ? Colors.white
                                  : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedModeIndex = 1;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            _selectedModeIndex == 1
                                ? Colors.blue[800]
                                : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text(
                        'Road 모드',
                        style: TextStyle(
                          fontSize: _selectedModeIndex == 1 ? 20 : 13,
                          color:
                              _selectedModeIndex == 1
                                  ? Colors.white
                                  : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 모드에 따라 MapView 또는 RoadScreen 보여주기
          if (_selectedModeIndex == 0) const MapView(),
          if (_selectedModeIndex == 1) const RoadScreen(),

          // 항상 보이는 EmergencyButton
          const EmergencyButton(),
        ],
      ),
    );
  }
}
