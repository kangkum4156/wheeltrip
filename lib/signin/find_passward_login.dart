import 'package:flutter/material.dart';
import 'package:wheeltrip/signin/firebase_service_login.dart';

class FindPassword extends StatefulWidget {
  const FindPassword({super.key});

  @override
  State<FindPassword> createState() => _FindPasswordState();
}

class _FindPasswordState extends State<FindPassword> {
  final TextEditingController _controller = TextEditingController();
  bool _nextAvailable = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkFields);
  }

  void _checkFields() {
    setState(() {
      _nextAvailable = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "E-mail 입력",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "비밀번호 재설정 메일을 보내드립니다.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 300),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "email",
                border: UnderlineInputBorder(),
                suffixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextAvailable
                    ? () async {
                  final email = _controller.text.trim();
                  try {
                    await sendPasswordResetEmail(email);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("메일이 전송됨"),
                      ),
                    );

                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("메일 전송 실패"),
                      ),
                    );
                  }
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _nextAvailable ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text("Send Mail"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
