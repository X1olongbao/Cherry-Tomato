import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utilities/logger.dart';
import '../services/verification_service.dart';
import 'otp_input.dart';
import '../homepage/homepage_app.dart';
import 'set_new_pass.dart';

const Color tomatoRed = Color(0xFFE53935);

enum VerificationMode { register, reset }

class VerificationCodePage extends StatefulWidget {
  const VerificationCodePage({
    super.key,
    required this.email,
    required this.mode,
    this.username,
    this.password,
  });

  final String email;
  final VerificationMode mode;
  final String? username; // for register
  final String? password; // for register

  @override
  State<VerificationCodePage> createState() => _VerificationCodePageState();
}

class _VerificationCodePageState extends State<VerificationCodePage> {
  String _code = '';
  bool _valid = false;
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    if (!_valid || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('profiles')
          .select('id, email, verification_code, code_expiry')
          .eq('email', widget.email)
          .maybeSingle();
      if (row == null) {
        throw Exception('No profile found for ${widget.email}');
      }
      final String? dbCode = row['verification_code'] as String?;
      final String? expiresAtStr = row['code_expiry'] as String?;
      if (dbCode == null || expiresAtStr == null) {
        throw Exception('No active verification code for ${widget.email}');
      }
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        throw Exception('Verification code has expired');
      }
      if (dbCode.toUpperCase() != _code.toUpperCase()) {
        throw Exception('Verification code is incorrect');
      }

      // Clear code and mark verified via client
      final userId = row['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw Exception('No user ID bound to email');
      }
      await VerificationService.instance.clearCodeForUser(userId);

      if (widget.mode == VerificationMode.register) {
        // Email verified; sign the user in (user created via admin before)
        final password = widget.password ?? '';
        if (password.isEmpty) {
          throw Exception('Missing password for registration');
        }
        await client.auth.signInWithPassword(
          email: widget.email,
          password: password,
        );
        // Update last login client-side after auth
        final supaUser = client.auth.currentUser;
        if (supaUser != null) {
          await client.from('profiles').upsert({
            'id': supaUser.id,
            'last_login': DateTime.now().toIso8601String(),
          });
        }
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Homepage()),
          (route) => false,
        );
      } else {
        // reset mode: navigate to set new password
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetNewPasswordPage(
              userId: userId,
              email: widget.email,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.e('Verification failed: $e');
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Verification failed')),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              Text(
                widget.mode == VerificationMode.register
                    ? 'Email verification'
                    : 'Password reset verification',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-character code sent to ${widget.email}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 2),
              const Text('Use letters and numbers',
                  style: TextStyle(color: Colors.black45)),
              const SizedBox(height: 40),
              OtpInput(
                length: 6,
                autoFocusFirst: true,
                allowAlphanumeric: true,
                onChanged: (v) => setState(() {
                  _code = v;
                  _valid = v.length == 6 && v.trim().isNotEmpty;
                }),
                onCompleted: (v) => setState(() {
                  _code = v;
                  _valid = true;
                }),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _valid ? tomatoRed : const Color(0xFFFFC5C8),
                    foregroundColor:
                        _valid ? Colors.white : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _valid && !_verifying ? _verify : null,
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}