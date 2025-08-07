import 'dart:async';
import 'package:wheeltrip/realtime_location/location_uploader.dart';

class LocationTracker {
  static Timer? _timer;

  static void start() {
    _timer?.cancel(); // 혹시 모를 중복 방지
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      updateRealtimeLocation();
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
