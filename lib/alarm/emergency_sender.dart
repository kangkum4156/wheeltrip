import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmergencySender {
  static const String fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE'; // 🔑 서버 키 넣기

  static Future<String> sendEmergencyAlert(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;


      // ✅ 현재 로그인된 사용자 가져오기
      final user = auth.currentUser;

      if (user == null || user.email == null) {
        return '로그인된 사용자가 없습니다.';
      }

      final currentUserEmail = user.email!;

      // ✅ 로그인된 사용자의 Firestore 문서 가져오기
      final currentUserSnapshot = await firestore.collection('users').doc(currentUserEmail).get();
      final data = currentUserSnapshot.data();

      if (data == null || !data.containsKey('counter_email')) {
        return '보호자 이메일이 등록되어 있지 않습니다.';
      }

      final counterEmail = data['counter_email'];

      // ✅ counter_email의 토큰 가져오기
      final counterSnapshot = await firestore.collection('users').doc(counterEmail).get();
      final counterData = counterSnapshot.data();

      if (counterData == null || !counterData.containsKey('token')) {
        return '보호자 기기의 알림 토큰이 없습니다.';
      }

      final token = counterData['token'];

      // ✅ FCM 푸시 알림 전송
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$fcmServerKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': '🚨 비상 호출',
            'body': '$currentUserEmail 님이 긴급 호출을 보냈습니다!',
          },
          'priority': 'high',
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'sender_email': currentUserEmail,
          },
        }),
      );

      if (response.statusCode == 200) {
        return '비상 요청이 전송되었습니다.';
      } else {
        print('❌ 푸시 전송 실패: ${response.body}');
        return '비상 요청 전송 실패';
      }
    } catch (e) {
      print('❌ 예외 발생: $e');
      return '비상 요청 중 오류가 발생했습니다.';
    }
  }
}
