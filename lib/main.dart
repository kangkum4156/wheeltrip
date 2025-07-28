import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wheeltrip/signin/main_login.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(), /// main_login에 책임을 보류 - current user 존재하면 바로 HomeBody로
    ),
  );
}
