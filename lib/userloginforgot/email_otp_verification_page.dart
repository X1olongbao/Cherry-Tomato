import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../homepage/homepage_app.dart';
import 'set_new_pass.dart';

enum OtpFlow { registration, forgotPassword }

class OtpContext {
  final OtpFlow flow;
  final String email;
  final String? username; // required for registration flow
  final String? password; // registration password; not used in forgot flow here
  String otp; // mutable for resend
  String expiryIso; // mutable for resend

  OtpContext({
    required this.flow,
    required this.email,
    this.username,
    this.password,
    required this.otp,
    required this.expiryIso,
  });
}

class EmailOtpVerificationPage extends StatefulWidget {
  final OtpContext otpContext;

  const EmailOtpVerificationPage({super.key, required this.otpContext});

  @override
  State<EmailOtpVerificationPage> createState() => _EmailOtpVerificationPageState();
}

class _EmailOtpVerificationPageState extends State<EmailOtpVerificationPage> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  String _generateOtpCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _resendOtp() async {
    setState(() => _resending = true);
    try {
      final newCode = _generateOtpCode();
      final newExpiry = DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String();

      final response = await Supabase.instance.client.functions.invoke(
        'send_otp_email',
        body: {
          'email': widget.otpContext.email,
          'passcode': newCode,
          'expiry': newExpiry,
        },
      );

      final status = response.status ?? 200;
      if (status < 200 || status >= 300) {
        throw Exception('Failed to resend OTP. Status: $status');
      }

      widget.otpContext.otp = newCode;
      widget.otpContext.expiryIso = newExpiry;
      _showSnack('OTP resent. Please check your email.');
    } catch (e) {
      _showSnack('Resend failed: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verifyAndProceed() async {
    final input = _otpCtrl.text.trim();
    if (input.isEmpty || input.length != 6) {
      _showSnack('Enter the 6-character OTP.');
      return;
    }

    final expected = widget.otpContext.otp;
    final expiry = DateTime.tryParse(widget.otpContext.expiryIso);
    final now = DateTime.now().toUtc();

    if (expiry == null) {
      _showSnack('Invalid expiry. Please resend OTP.');
      return;
    }
    if (expiry.isBefore(now)) {
      _showSnack('OTP expired. Please resend OTP.');
      return;
    }
    if (input != expected) {
      _showSnack('Invalid OTP. Please try again.');
      return;
    }

    setState(() => _verifying = true);
    try {
      final supabase = Supabase.instance.client;
      if (widget.otpContext.flow == OtpFlow.registration) {
        final email = widget.otpContext.email;
        final password = widget.otpContext.password!;
        final username = widget.otpContext.username!;

        // Create Supabase Auth user
        final signUpRes = await supabase.auth.signUp(email: email, password: password);
        if (signUpRes.user == null) {
          throw Exception('Sign up failed.');
        }

        // Insert into profiles; mark verified and clear any code fields
        await supabase.from('profiles').upsert({
          'id': signUpRes.user!.id,
          'email': email,
          'username': username,
          'is_verified': true,
          'verification_code': null,
          'code_expiry': null,
        });

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Homepage()),
          (route) => false,
        );
      } else {
        // For forgot password, navigate to SetNewPasswordPage to change password AFTER OTP verification.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SetNewPasswordPage(userId: '', email: widget.otpContext.email),
          ),
        );
      }
    } catch (e) {
      _showSnack('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isForgot = widget.otpContext.flow == OtpFlow.forgotPassword;
    return Scaffold(
      appBar: AppBar(title: Text(isForgot ? 'Verify OTP (Forgot Password)' : 'Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter the 6-character code sent to ${widget.otpContext.email}.'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpCtrl,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                hintText: 'e.g. A1B2C3',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _verifying ? null : _verifyAndProceed,
              child: _verifying
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resending ? null : _resendOtp,
              child: _resending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}