import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class BgLocationTaskHandler extends TaskHandler {
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await _ensurePerms();

    // 15~30초 권장
    const period = Duration(seconds: 20);
    _timer = Timer.periodic(period, (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _upload(pos);
      } catch (_) {/* ignore */}
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _timer?.cancel();
  }

  static Future<void> _ensurePerms() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    }
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied ||
        status == LocationPermission.deniedForever) {
      status = await Geolocator.requestPermission();
    }
    if (status == LocationPermission.whileInUse) {
      // '항상 허용' 유도 (안드10+)
      await Geolocator.requestPermission();
    }
  }

  static Future<void> _upload(Position p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final emailKey =
    (user.email ?? user.uid).trim().toLowerCase().replaceAll('.', '(dot)');

    final ref = FirebaseDatabase.instance.ref('realtime_location/$emailKey');
    await ref.set({
      'lat': p.latitude,
      'lng': p.longitude,
      'acc': p.accuracy,
      't': DateTime.now().toIso8601String(),
    });
  }
}
