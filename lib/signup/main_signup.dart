import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:wheeltrip/signin/firebase_service_login.dart'; // isEmailDuplicate 사용

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _counterEmailController = TextEditingController();

  String? _selectedMode; // "휠체어" | "보호자"
  File? _profileImage;   // 로컬 선택 파일
  bool _submitting = false;
  double _uploadProgress = 0; // 0~1 (0이면 미표시)

  // 사진 고르기
  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _profileImage = File(picked.path));
  }

  // Storage 업로드 후 다운로드 URL 반환
  Future<String?> _uploadProfileImage(String email) async {
    if (_profileImage == null) return null;
    try {
      final file = _profileImage!;
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$email.jpg');

      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });

      await task;
      final url = await ref.getDownloadURL();
      setState(() => _uploadProgress = 0);
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 업로드 실패: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모드를 선택하세요.")),
      );
      return;
    }

    final email = _emailController.text.trim();
    final counterEmail = _counterEmailController.text.trim();

    // 중복 체크
    if (await isEmailDuplicate(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미 등록된 이메일입니다.")),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // 상대 이메일이 입력된 경우 존재하는지 확인
      if (counterEmail.isNotEmpty) {
        final chk = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: counterEmail)
            .limit(1)
            .get();

        if (chk.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("상대 이메일이 유효하지 않습니다.")),
            );
          }
          setState(() => _submitting = false);
          return;
        }
      }

      // Firebase Auth 계정 생성
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // 프로필 이미지 업로드(선택)
      final profileUrl = await _uploadProfileImage(email);

      // Firestore 사용자 문서 저장
      final userData = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": email,
        "mode": _selectedMode,
        "counter_email": counterEmail.isNotEmpty ? [counterEmail] : <String>[],
        "location": null,
        "token": null,
        "profileImageUrl": profileUrl, // 프로필 URL
        "createdAt": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection("users")
          .doc(cred.user!.email) // doc id = 이메일
          .set(userData);

      // 상대 유저 문서에도 나의 이메일을 연결(arrayUnion)
      if (counterEmail.isNotEmpty) {
        final counterQuery = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: counterEmail)
            .limit(1)
            .get();

        if (counterQuery.docs.isNotEmpty) {
          final counterDocId = counterQuery.docs.first.id;
          await FirebaseFirestore.instance
              .collection("users")
              .doc(counterDocId)
              .update({
            "counter_email": FieldValue.arrayUnion([email]),
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("회원가입 완료")),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입 실패: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입 중 오류 발생: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _counterEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 프로필 이미지
                GestureDetector(
                  onTap: canSubmit ? _pickProfileImage : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage:
                        _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null
                            ? const Icon(Icons.person, size: 44)
                            : null,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (_uploadProgress > 0 && _uploadProgress < 1) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _uploadProgress),
                ],
                const SizedBox(height: 20),

                // 이름
                TextFormField(
                  controller: _nameController,
                  enabled: canSubmit,
                  decoration: const InputDecoration(labelText: "이름"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "이름을 입력하세요." : null,
                ),
                const SizedBox(height: 10),

                // 전화번호
                TextFormField(
                  controller: _phoneController,
                  enabled: canSubmit,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "전화번호"),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return "전화번호를 입력하세요.";
                    if (t.length != 11) return "하이픈 없이 11자리로 입력하세요.";
                    if (!RegExp(r'^[0-9]+$').hasMatch(t)) return "숫자만 입력하세요.";
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // 이메일
                TextFormField(
                  controller: _emailController,
                  enabled: canSubmit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "이메일"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "이메일을 입력하세요." : null,
                ),
                const SizedBox(height: 10),

                // 비밀번호
                TextFormField(
                  controller: _passwordController,
                  enabled: canSubmit,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "비밀번호"),
                  validator: (v) =>
                  (v == null || v.length < 6) ? "비밀번호는 6자 이상 입력하세요." : null,
                ),
                const SizedBox(height: 20),

                // 모드 선택
                DropdownButtonFormField<String>(
                  value: _selectedMode,
                  decoration: const InputDecoration(labelText: "모드 선택"),
                  items: const [
                    DropdownMenuItem(value: "휠체어", child: Text("휠체어 모드")),
                    DropdownMenuItem(value: "보호자", child: Text("보호자 모드")),
                  ],
                  onChanged: canSubmit ? (v) => setState(() => _selectedMode = v) : null,
                  validator: (v) => v == null ? "모드를 선택하세요." : null,
                ),
                const SizedBox(height: 10),

                // 상대 이메일 (선택)
                TextFormField(
                  controller: _counterEmailController,
                  enabled: canSubmit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "상대 이메일 (선택 입력 가능)",
                    hintText: "연결하고 싶은 상대방 이메일",
                  ),
                ),
                const SizedBox(height: 20),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _register : null,
                    child: _submitting
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text("회원가입"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
