import 'package:flutter/material.dart';
import 'package:tomatonator/homepage.dart';
import 'sign_up_page.dart';
import 'forgot_pass_page.dart';

const Color tomatoRed = Color(0xFFE53935);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onChanged);
    _passwordCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  bool get _allFilled =>
      _emailCtrl.text.isNotEmpty && _passwordCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  ButtonStyle get _continueStyle => ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: Colors.white,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tomatoRed.withValues(alpha: 0.2);
          }
          return tomatoRed;
        }),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );

  Widget _buildTopTab(
          {required String label,
          required bool active,
          required VoidCallback onTap}) =>
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: active ? tomatoRed : Colors.grey[400])),
              Container(
                  height: 3,
                  margin: const EdgeInsets.only(top: 4),
                  color: active ? tomatoRed : Colors.transparent),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Row(children: [
                _buildTopTab(label: 'Log in', active: true, onTap: () {}),
                _buildTopTab(
                  label: 'Sign up',
                  active: false,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SignUpPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        transitionsBuilder: (_, __, ___, child) => child,
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 80),
              const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 6),
                  child: Text('Email',
                      style: TextStyle(fontSize: 16, color: Colors.black))),
              TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration('Enter your email')),
              const Padding(
                  padding: EdgeInsets.only(left: 8.0, top: 28, bottom: 6),
                  child: Text('Password',
                      style: TextStyle(fontSize: 16, color: Colors.black))),
              TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: _fieldDecoration('Enter your password')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage())),
                  style: TextButton.styleFrom(
                      foregroundColor: tomatoRed,
                      textStyle: const TextStyle(fontSize: 16)),
                  child: const Text('Forgot Password?',
                      style: TextStyle(color: tomatoRed, fontSize: 16)),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allFilled
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Homepage()))
                      : null,
                  style: _continueStyle,
                  child: const Text('Continue',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
              const Row(children: [
                Expanded(
                    child: Divider(color: Color(0xFFBDBDBD), thickness: 1)),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child:
                        Text('Or', style: TextStyle(color: Color(0xFFBDBDBD)))),
                Expanded(
                    child: Divider(color: Color(0xFFBDBDBD), thickness: 1)),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Image.asset('assets/login page/devicon_google.png',
                      width: 24, height: 24),
                  label: const Text('Continue with Google',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.black54, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Don\'t have an account? ',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignUpPage())),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Sign up',
                      style: TextStyle(
                          color: tomatoRed,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
