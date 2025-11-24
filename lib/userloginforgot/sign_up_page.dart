import 'package:flutter/material.dart';
import 'login_page.dart';
import 'email_otp_verification_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:tomatonator/homepage/homepage_app.dart';

const Color tomatoRed = Color(0xFFE53935);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false; // track ongoing signup
  String? _error; // last error message
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onChanged);
    _emailCtrl.addListener(_onChanged);
    _passwordCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  bool get _allFilled =>
      _usernameCtrl.text.isNotEmpty &&
      _emailCtrl.text.isNotEmpty &&
      _passwordCtrl.text.isNotEmpty;

  // Send OTP via Supabase and navigate to OTP verification.
  Future<void> _handleSignup() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text;

      // Use Supabase's built-in OTP functionality
      final supabase = Supabase.instance.client;
      final exists = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (exists != null) {
        setState(() => _error = 'Email already in use. Please log in or use a different email.');
        return;
      }
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {
          'username': username,
          // Store password temporarily in metadata for later use
          'temp_password': password,
        },
      );

      if (!mounted) return;
      final ctx = OtpContext(
        flow: OtpFlow.registration,
        email: email,
        username: username,
        password: password,
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EmailOtpVerificationPage(otpContext: ctx)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignup() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) {
        setState(() => _loading = false);
        return;
      }

      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      try {
        if (gAuth.idToken != null) {
          await Supabase.instance.client.auth.signInWithIdToken(
            provider: Provider.google,
            idToken: gAuth.idToken!,
            accessToken: gAuth.accessToken,
          );
        }
      } catch (_) {}

      if (Supabase.instance.client.auth.currentUser == null) {
        final email = FirebaseAuth.instance.currentUser?.email ?? gUser.email;
        if (email.isEmpty) {
          throw Exception('Google account has no email; cannot create Supabase session');
        }

        final syntheticPassword = 'google-oauth-${gUser.id}-${email.hashCode}';
        try {
          await Supabase.instance.client.auth.signUp(
            email: email,
            password: syntheticPassword,
            data: {'username': 'User'},
          );
        } catch (_) {}
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: syntheticPassword,
          );
        } catch (e) {
          throw Exception('Supabase login failed after Google sign-in: $e');
        }
      }

      try {
        final supaUser = Supabase.instance.client.auth.currentUser;
        if (supaUser != null) {
          final existing = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('id', supaUser.id)
              .maybeSingle();
          if (existing == null) {
            final rng = Random();
            final username = 'User${rng.nextInt(900000) + 100000}';
            await Supabase.instance.client.from('profiles').upsert({
              'id': supaUser.id,
              'username': username,
              'email': FirebaseAuth.instance.currentUser?.email ?? gUser.email,
              'phone_number': null,
              'provider': 'google',
              'is_verified': true,
              'last_login': DateTime.now().toUtc().toIso8601String(),
            });
          }
        }
      } catch (_) {}

      if (Supabase.instance.client.auth.currentUser == null) {
        throw Exception('Logged into Google (Firebase) but not into Supabase');
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
      );
    } catch (e) {
      setState(() => _error = 'Google sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

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

  Widget _buildTopTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: active ? tomatoRed : Colors.grey[400],
              ),
            ),
            Container(
              height: 3,
              margin: const EdgeInsets.only(top: 4),
              color: active ? tomatoRed : Colors.transparent,
            )
          ],
        ),
      ),
    );
  }

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
              Row(
                children: [
                  _buildTopTab(
                    label: 'Log in',
                    active: false,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const LoginPage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          transitionsBuilder: (_, __, ___, child) => child,
                        ),
                      );
                    },
                  ),
                  _buildTopTab(
                    label: 'Sign up',
                    active: true,
                    onTap: () {
                      // stay (still clickable)
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Username
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 6),
                child: Text(
                  'Username',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              TextField(
                controller: _usernameCtrl,
                decoration: _fieldDecoration('Enter your username'),
              ),

              const SizedBox(height: 28),

              // Email
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 6),
                child: Text(
                  'Email',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Enter your email'),
              ),

              const SizedBox(height: 28),

              // Password
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 6),
                child: Text(
                  'Password',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                decoration: _fieldDecoration('Enter your password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Continue button – integrates Supabase signup
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allFilled && !_loading ? _handleSignup : null,
                  style: _continueStyle,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 15),

              if (_error != null) ...[
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
                const SizedBox(height: 15),
              ],

              // OR divider
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFFBDBDBD),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Or',
                      style: TextStyle(color: Color(0xFFBDBDBD)),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Color(0xFFBDBDBD),
                      thickness: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Google button (placeholder asset)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _googleSignup,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.black54, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: Image.asset(
                    'assets/login page/devicon_google.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bottom link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: tomatoRed,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
