import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/data/const_data.dart';

Future<void> deleteRoadFeedback(String routeId) async {

  final fs = FirebaseFirestore.instance;

  final routeRef = fs.collection('routes').doc(routeId);
  final feedbackRef = routeRef.collection('feedbacks').doc(user_email);
  final userRef = fs.collection('users').doc(user_email).collection('my_routes').doc(routeId);

  try {
    await userRef.delete();

    // 1) 피드백 문서 삭제
    await feedbackRef.delete();

    // 2) 남은 피드백 전체 조회
    final feedbacksSnapshot = await routeRef.collection('feedbacks').get();

    if (feedbacksSnapshot.docs.isEmpty) {
      // 남은 피드백 없으면 평균 0, count 0 처리
      await routeRef.delete();
      print('남은 피드백 없어서 route 문서 삭제 완료');
      return;
    } else {
      // 남은 피드백의 rate 합계와 개수 구하기
      final totalRate = feedbacksSnapshot.docs
          .map((doc) => (doc.data()['rate'] as num?) ?? 0)
          .fold<num>(0, (a, b) => a + b);
      final count = feedbacksSnapshot.docs.length;

      final avgRate = totalRate / count;

      await routeRef.update({
        'avgRate': avgRate,
        'rateCount': count,
      });
    }

    print('피드백 삭제 및 평균 평점 업데이트 완료');
  } catch (e) {
    print('피드백 삭제 실패: $e');
    rethrow;
  }
}
