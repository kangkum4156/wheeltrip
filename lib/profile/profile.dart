import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _localImage;
  double _uploadProgress = 0; // 0~1

  User? get _user => FirebaseAuth.instance.currentUser;
  String get _docId => _user?.email ?? ''; // users/{email} 문서 사용

  Future<void> _pickAndUpload() async {
    if (_user == null) return;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _localImage = File(picked.path));

      // Storage 업로드
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${_user!.email}.jpg');

      final task = ref.putFile(
        _localImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });

      await task;
      final url = await ref.getDownloadURL();

      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_docId)
          .set({'profileImageUrl': url}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _uploadProgress = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadProgress = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    }
  }

  Future<void> _deletePhoto(String? currentUrl) async {
    if (_user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('프로필 사진 삭제'),
        content: const Text('현재 프로필 사진을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // Storage 파일 삭제(있다면)
      if (currentUrl != null && currentUrl.trim().isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(currentUrl);
          await ref.delete();
        } catch (_) {
          // 없을 수도 있으니 무시
        }
      } else {
        // 혹시 URL이 없더라도 경로로 시도
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${_user!.email}.jpg');
          await ref.delete();
        } catch (_) {}
      }

      // Firestore 필드 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_docId)
          .update({'profileImageUrl': FieldValue.delete()});

      if (!mounted) return;
      setState(() => _localImage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진을 삭제했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로필')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_docId)
            .snapshots(),
        builder: (context, snap) {
          final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
          final profileUrl = (data['profileImageUrl'] as String?);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 상단 - 프로필 사진 + 버튼
              Center(
                child: Column(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 프로필 사진
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _localImage != null
                              ? FileImage(_localImage!)
                              : (profileUrl != null && profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : null) as ImageProvider<Object>?,
                          child: (profileUrl == null && _localImage == null)
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        const SizedBox(width: 16), // 사진과 버튼 사이 간격

                        // 버튼들
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: '사진 변경',
                              onPressed: _pickAndUpload,
                              icon: const Icon(Icons.camera_alt),
                            ),
                            IconButton(
                              tooltip: '사진 삭제',
                              onPressed: () => _deletePhoto(profileUrl),
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (_uploadProgress > 0 && _uploadProgress < 1) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 아래는 간단한 정보 표시 (원하면 수정 가능 UI로 확장)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('이메일'),
                subtitle: Text(_user!.email ?? ''),
              ),
              if (data['name'] != null)
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('이름'),
                  subtitle: Text('${data['name']}'),
                ),
              if (data['phone'] != null)
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('전화번호'),
                  subtitle: Text('${data['phone']}'),
                ),
              if (data['mode'] != null)
                ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: const Text('모드'),
                  subtitle: Text('${data['mode']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
