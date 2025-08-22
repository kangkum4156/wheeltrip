import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'alarm/notification_service.dart';
import 'package:wheeltrip/signin/main_login.dart'; // AuthWrapper 정의 파일
import 'realtime_location/bg_location_task.dart';

// v6.5.0: init()은 void 반환 → await 금지
void _initForeground() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'bg_location_channel',
      channelName: '백그라운드 위치 전송',
      channelDescription: '앱을 종료해도 위치를 업로드합니다.',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
      buttons: [NotificationButton(id: 'stop', text: '중지')],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15000,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();

  _initForeground(); // ✅ 그냥 호출만

  runApp(
    WithForegroundTask(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(), // AuthWrapper가 없다면 아래 주석의 더미로 임시 실행 가능
      ),
    ),
  );
}

// ForegroundTask 시작 엔트리
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BgLocationTaskHandler());
}

/*  // 만약 AuthWrapper가 아직 없다면 임시 더미 위젯으로 빌드 테스트 가능
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('AuthWrapper 자리')));
}
*/
