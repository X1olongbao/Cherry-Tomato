import 'package:flutter/material.dart';
import 'email_otp_verification_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color tomatoRed = Color(0xFFE53935);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _validEmail {
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^.+@.+\..+$').hasMatch(v);
  }

  void _goNext() {
    setState(() => _showErrors = true);
    if (!_validEmail) return;
    _startEmailCodeFlow();
  }

  Future<void> _startEmailCodeFlow() async {
    final email = _emailCtrl.text.trim();
    try {
      // Use Supabase's built-in OTP functionality for password reset
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Don't create user if doesn't exist
      );

      if (!mounted) return;
      final ctx = OtpContext(
        flow: OtpFlow.forgotPassword,
        email: email,
        username: null,
        password: null,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EmailOtpVerificationPage(otpContext: ctx)),
      );
    } catch (e) {
      final err = e.toString();
      final notFound = err.contains('404') || 
                       err.toLowerCase().contains('not found') ||
                       err.toLowerCase().contains('user not found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notFound ? 'No account found with this email' : 'Failed to send OTP: $err',
          ),
        ),
      );
    }
  }

  InputDecoration get _decoration => InputDecoration(
        hintText: 'Enter your email',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: tomatoRed, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        errorText: !_showErrors
            ? null
            : (_emailCtrl.text.isEmpty
                ? 'Email required'
                : (_validEmail ? null : 'Invalid email')),
      );

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: Colors.white,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return tomatoRed.withValues(alpha: 0.25);
          }
          return tomatoRed;
        }),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom back arrow image from assets (Vector.png)
                SizedBox(
                  height: 32,
                  width: 32,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset('assets/Forgot pass/Vector.png',
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Forgot password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please enter your email to reset your password',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 6),
                  child: Text('Email',
                      style: TextStyle(fontSize: 14, color: Colors.black)),
                ),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration,
                  onSubmitted: (_) => _goNext(),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _validEmail ? _goNext : null,
                    style: _btnStyle,
                    child: const Text('Next',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
