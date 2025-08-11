import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteFirebase extends StatefulWidget {
  const DeleteFirebase({super.key});

  @override
  State<DeleteFirebase> createState() => _DeleteFirebaseState();
}

class _DeleteFirebaseState extends State<DeleteFirebase> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 삭제 완료 후 하단 스낵바 표시 함수
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showConfirmDialog(
    String title,
    Future<void> Function() onConfirm,
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("삭제 확인"),
            content: Text("$title을(를) 정말 삭제하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("취소"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await onConfirm();
                },
                child: const Text("삭제", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _deletePlaces() async {
    final snapshot = await _firestore.collection('places').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    _showSnackBar("places 컬렉션 전체 삭제 완료");
  }

  Future<void> _deleteRoutes() async {
    final snapshot = await _firestore.collection('routes').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    _showSnackBar("routes 컬렉션 전체 삭제 완료");
  }

  Future<void> _deleteUserSubCollections() async {
    final usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      final myRoutes = await userDoc.reference.collection('my_routes').get();
      for (var doc in myRoutes.docs) {
        await doc.reference.delete();
      }

      final savedPlaces =
          await userDoc.reference.collection('saved_places').get();
      for (var doc in savedPlaces.docs) {
        await doc.reference.delete();
      }
    }
    _showSnackBar("모든 유저의 my_routes, saved_places 삭제 완료");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firebase 데이터 삭제")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            MaterialButton(
              onPressed: () => _showConfirmDialog("places 컬렉션", _deletePlaces),
              color: Colors.red,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("places 삭제"),
            ),
            MaterialButton(
              onPressed: () => _showConfirmDialog("routes 컬렉션", _deleteRoutes),
              color: Colors.green,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("routes 삭제"),
            ),
            MaterialButton(
              onPressed:
                  () => _showConfirmDialog(
                    "모든 유저의 my_routes, saved_places",
                    _deleteUserSubCollections,
                  ),
              color: Colors.blue,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("user sub 삭제"),
            ),
          ],
        ),
      ),
    );
  }
}
