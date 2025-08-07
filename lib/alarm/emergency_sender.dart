import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmergencySender {
  static const String functionUrl = 'https://sendemergencyalert-agrnrnefua-du.a.run.app';
  static Future<String> sendEmergencyAlert(BuildContext context) async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null || user.email == null) {
        return '로그인된 사용자가 없습니다.';
      }

      final userEmail = user.email!;

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': userEmail}),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('❌ 서버 응답 오류: ${response.statusCode} / ${response.body}');
        return '비상 요청 전송 실패 (서버 오류)';
      }
    } catch (e) {
      print('❌ 예외 발생: $e');
      return '비상 요청 중 오류가 발생했습니다.';
    }
  }
}
