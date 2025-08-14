// lib/feedback/feedback_photo_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pending_photo.dart';

/// (A) 사진 1장 선택 → 압축 → 메모리 보관(업로드 X)
Future<PendingPhoto?> pickAndCompressOnePhoto() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;

  final tmpDir = await getTemporaryDirectory();
  final outPath = '${tmpDir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final compressed = await FlutterImageCompress.compressAndGetFile(
    x.path, outPath, minWidth: 1280, minHeight: 1280, quality: 75, format: CompressFormat.jpeg,
  );
  if (compressed == null) return null;

  final bytes = await File(compressed.path).readAsBytes();
  return PendingPhoto(bytes: bytes, localId: DateTime.now().millisecondsSinceEpoch.toString());
}

/// (B) 제출 시: 보관중인 사진들 일괄 업로드 -> URL들 반환
Future<List<String>> uploadPendingPhotos({
  required String googlePlaceId,
  required List<PendingPhoto> pending,
  void Function(double progress)? onProgress, // 전체 진행률(0~1)
}) async {
  final user = FirebaseAuth.instance.currentUser!;
  final uid = user.uid;
  final storage = FirebaseStorage.instance;

  final urls = <String>[];
  for (int i = 0; i < pending.length; i++) {
    final photo = pending[i];
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = storage.ref('places/$googlePlaceId/photos/$uid/$ts.jpg');

    final task = ref.putData(
      photo.bytes,
      SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public,max-age=86400'),
    );

    // 개별 진행률을 전체 진행률로 환산(대략)
    task.snapshotEvents.listen((s) {
      if (onProgress != null && s.totalBytes > 0) {
        final per = s.bytesTransferred / s.totalBytes;
        final overall = (i + per) / pending.length;
        onProgress(overall);
      }
    });

    await task;
    urls.add(await ref.getDownloadURL());
  }
  return urls;
}

/// (C) Firestore 저장(새 문서 생성 또는 병합 업데이트)
Future<void> upsertFeedbackDocument({
  required String googlePlaceId,
  required String feedbackDocId,
  required Map<String, dynamic> data,            // comment/rating/features 등
  required List<String> photoUrlsToAdd,          // 이번에 업로드한 새 URL들
}) async {
  final ref = FirebaseFirestore.instance
      .collection('places').doc(googlePlaceId)
      .collection('feedbacks').doc(feedbackDocId);

  final payload = <String, dynamic>{
    ...data,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  if (photoUrlsToAdd.isNotEmpty) {
    payload['photoUrls'] = FieldValue.arrayUnion(photoUrlsToAdd);
  }

  await ref.set(payload, SetOptions(merge: true));
}
