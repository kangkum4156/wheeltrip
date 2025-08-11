// lib/feedback/feedback_photo_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// 1장 선택 → 압축 → Storage → Firestore 내 피드백 문서의 photoUrls 배열에 추가.
/// 성공 시 업로드된 URL을 반환, 취소/실패 시 null.
Future<String?> addOnePhotoToMyFeedback({
  required BuildContext context,
  required String googlePlaceId,
  void Function(double progress)? onProgress,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
    return null;
  }

  try {
    // 1) 이미지 선택
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    // 2) 압축(1280px, jpg 75)
    final raw = File(picked.path);
    final tmpDir = await getTemporaryDirectory();
    final outPath =
        '${tmpDir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      raw.path,
      outPath,
      minWidth: 1280,
      minHeight: 1280,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) {
      throw '이미지 압축에 실패했습니다.';
    }

    // 3) Storage 업로드
    final uid = user.uid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'places/$googlePlaceId/photos/$uid/$ts.jpg';
    final ref = FirebaseStorage.instance.ref().child(storagePath);

    final task = ref.putFile(
      File(compressed.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=86400',
      ),
    );

    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0 && onProgress != null) {
        onProgress(s.bytesTransferred / s.totalBytes);
      }
    });

    await task;
    final url = await ref.getDownloadURL();

    // 4) Firestore: 내 피드백 문서의 photoUrls 배열에 추가(merge)
    final feedbackDocId =
    (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email!.trim()
        : uid;

    final feedbackRef = FirebaseFirestore.instance
        .collection('places')
        .doc(googlePlaceId)
        .collection('feedbacks')
        .doc(feedbackDocId);

    await feedbackRef.set({
      'photoUrls': FieldValue.arrayUnion([url]), // ✅ 배열로만 저장
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('사진이 추가되었습니다.')));
    return url;
  } on FirebaseException catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('업로드 실패(${e.code})')));
    return null;
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    return null;
  }
}
