import 'package:flutter/material.dart';
import 'package:wheeltrip/body/home_body.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:wheeltrip/signin/find_passward_login.dart';
import 'package:wheeltrip/signin/firebase_service_login.dart';
import 'package:wheeltrip/signup/main_signup.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FindPassword()),
                );
              },
              child: const Text("비밀번호를 잊으셨나요?"),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();

              print('🔍 로그인 시도 - 이메일: $email / 비밀번호: $password');

              final result = await signIn(email, password);
              switch (result) {
                case 0:
                  print("❌ 로그인 실패");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("로그인 실패. 이메일과 비밀번호를 확인하세요.")),
                  );
                  break;
                case 1:
                  print("✅ 로그인 성공");
                  user_email = email;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeBody()),
                  );
                  break;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Sign In'),
          ),
          ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Sign Up')
          )
        ],
      ),
    );
  }
}