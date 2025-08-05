import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/signin/firebase_service_login.dart';

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

  String? _selectedMode;

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

    if (await isEmailDuplicate(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미 등록된 이메일입니다.")),
      );
      return;
    }

    try {
      // 상대 이메일 유효성 체크 (입력했을 경우만)
      if (counterEmail.isNotEmpty) {
        final counterUser = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: counterEmail)
            .limit(1)
            .get();

        if (counterUser.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("이메일이 유효하지 않습니다.")),
          );
          return;
        }
      }

      // Firebase Auth 회원 생성
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // ✅ Firestore에 저장할 데이터 (배열로 무조건 저장)
      final userData = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": email,
        "mode": _selectedMode,
        "counter_email": counterEmail.isNotEmpty ? [counterEmail] : [],
        "location": null,
        "token": null,
      };

      // 내 정보 저장
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.email)
          .set(userData);

      // ✅ 상대 유저 문서에도 나를 배열로 추가 (arrayUnion)
      if (counterEmail.isNotEmpty) {
        final counterUserDoc = await FirebaseFirestore.instance
            .collection("users")
            .where("email", isEqualTo: counterEmail)
            .limit(1)
            .get();

        if (counterUserDoc.docs.isNotEmpty) {
          final counterDocId = counterUserDoc.docs.first.id;
          await FirebaseFirestore.instance
              .collection("users")
              .doc(counterDocId)
              .update({
            "counter_email": FieldValue.arrayUnion([email])
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("회원가입 완료")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("회원가입 중 오류 발생: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 이름
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "이름"),
                  validator: (value) =>
                  value!.isEmpty ? "이름을 입력하세요." : null,
                ),
                const SizedBox(height: 10),

                // 전화번호
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: "전화번호"),
                  validator: (value) => value!.length != 11
                      ? "올바르지 않은 형식입니다."
                      : null,
                ),
                const SizedBox(height: 10),

                // 이메일
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "이메일"),
                  validator: (value) =>
                  value!.isEmpty ? "이메일을 입력하세요." : null,
                ),
                const SizedBox(height: 10),

                // 비밀번호
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "비밀번호"),
                  validator: (value) =>
                  value!.length < 6 ? "6자 이상 입력하세요." : null,
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
                  onChanged: (value) {
                    setState(() {
                      _selectedMode = value;
                    });
                  },
                  validator: (value) =>
                  value == null ? "모드를 선택하세요." : null,
                ),
                const SizedBox(height: 10),

                // 상대 이메일 (선택사항)
                TextFormField(
                  controller: _counterEmailController,
                  decoration: const InputDecoration(
                      labelText: "상대 이메일 (선택 입력 가능)"),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _register,
                  child: const Text("회원가입"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
