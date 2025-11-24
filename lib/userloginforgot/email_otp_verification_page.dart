import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../homepage/homepage_app.dart';
import 'set_new_pass.dart';
import '../services/profile_service.dart';
import '../utilities/logger.dart';

const Color tomatoRed = Color(0xFFE53935);

enum OtpFlow { registration, forgotPassword }

class OtpContext {
  final OtpFlow flow;
  final String email;
  final String? username; // required for registration flow
  final String? password; // registration password; not used in forgot flow here

  OtpContext({
    required this.flow,
    required this.email,
    this.username,
    this.password,
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _otpCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _isValidOtp => _otpCtrl.text.trim().length == 6;

  InputDecoration get _fieldDecoration => InputDecoration(
        hintText: 'Enter 6-digit code',
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  ButtonStyle get _verifyButtonStyle => ElevatedButton.styleFrom(
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

  Future<void> _resendOtp() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithOtp(
        email: widget.otpContext.email,
        shouldCreateUser: widget.otpContext.flow == OtpFlow.registration,
        data: widget.otpContext.flow == OtpFlow.registration && 
              widget.otpContext.username != null &&
              widget.otpContext.password != null
            ? {
                'username': widget.otpContext.username,
                'temp_password': widget.otpContext.password,
              }
            : null,
      );
      
    } catch (e) {
      setState(() => _error = 'Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verifyAndProceed() async {
    if (_verifying || !_isValidOtp) return;
    
    final input = _otpCtrl.text.trim();
    setState(() {
      _verifying = true;
      _error = null;
    });
    
    try {
      final supabase = Supabase.instance.client;
      
      // Verify OTP with Supabase
      final verifyRes = await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: widget.otpContext.email,
        token: input,
      );

      if (verifyRes.user == null) {
        throw Exception('OTP verification failed.');
      }

      if (widget.otpContext.flow == OtpFlow.registration) {
        final email = widget.otpContext.email;
        final password = widget.otpContext.password!;
        final username = widget.otpContext.username!;
        final userId = verifyRes.user!.id;

        // Set password for the newly created user
        try {
          if (password.isNotEmpty) {
            await supabase.auth.updateUser(UserAttributes(password: password));
          }
        } catch (e) {
          Logger.w('Failed to set password: $e');
        }

        // Insert/update profile with username
        try {
        await supabase.from('profiles').upsert({
            'id': userId,
          'email': email,
          'username': username,
          'is_verified': true,
          });
        } catch (e) {
          Logger.w('Failed to create profile: $e');
          // Try to update user metadata with username as fallback
          try {
            await supabase.auth.updateUser(
              UserAttributes(data: {'username': username}),
            );
          } catch (_) {
            // Ignore metadata update errors
          }
        }

        // Refresh profile service
        try {
          await ProfileService.instance.refreshCurrentUserProfile();
        } catch (e) {
          Logger.w('Failed to refresh profile: $e');
        }

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
            builder: (_) => SetNewPasswordPage(
              userId: verifyRes.user!.id,
              email: widget.otpContext.email,
            ),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid') || msg.contains('expired')) {
        setState(() => _error = 'Invalid or expired OTP. Please try again or resend.');
      } else {
        setState(() => _error = 'Verification failed. Please try again.');
      }
      Logger.e('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForgot = widget.otpContext.flow == OtpFlow.forgotPassword;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isForgot ? 'Verify OTP' : 'Verify Email',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const SizedBox(height: 32),
              // Header text
              Text(
                'Enter verification code',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit code to\n${widget.otpContext.email}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // OTP Input Field
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 6),
                child: Text(
                  'Verification Code',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            TextField(
              controller: _otpCtrl,
                keyboardType: TextInputType.number,
              maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: _fieldDecoration.copyWith(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.grey[400],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: tomatoRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: tomatoRed),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_verifying || !_isValidOtp) ? null : _verifyAndProceed,
                  style: _verifyButtonStyle,
                  child: _verifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 24),
              
              // Resend OTP
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
            TextButton(
              onPressed: _resending ? null : _resendOtp,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
              child: _resending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Resend',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tomatoRed,
                              ),
                            ),
            ),
          ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
