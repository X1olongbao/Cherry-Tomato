import 'package:flutter/material.dart';
import 'login_page.dart';
import 'email_otp_verification_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:tomatonator/homepage/homepage_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  bool get _isPasswordValid => _passwordCtrl.text.length >= 8;

  bool get _canContinue =>
      _usernameCtrl.text.isNotEmpty &&
      _emailCtrl.text.isNotEmpty &&
      _isPasswordValid &&
      !_loading;

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

      if (!_isPasswordValid) {
        setState(() => _error = 'Password must be at least 8 characters.');
        return;
      }

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
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('seen_onboarding_v1_${user.id}', true);
        }
      } catch (_) {}
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
        (route) => false,
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
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: EdgeInsets.only(left: 8.w, bottom: 6.h),
        child: Text(
          text,
          style: TextStyle(fontSize: 16.sp, color: Colors.black),
        ),
      );

  ButtonStyle get _continueStyle => ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: active ? tomatoRed : Colors.grey[400],
              ),
            ),
            Container(
              height: 3.h,
              margin: EdgeInsets.only(top: 4.h),
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
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 48.h),
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
              SizedBox(height: 40.h),

              // Username
              _fieldLabel('Username'),
              TextField(
                controller: _usernameCtrl,
                decoration: _fieldDecoration('Enter your username'),
              ),

              SizedBox(height: 28.h),

              // Email
              _fieldLabel('Email'),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Enter your email'),
              ),

              SizedBox(height: 28.h),

              // Password
              _fieldLabel('Password'),
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
              if (_passwordCtrl.text.isNotEmpty && !_isPasswordValid)
                Padding(
                  padding: EdgeInsets.only(left: 8.w, top: 6.h),
                  child: Text(
                    'Password must be at least 8 characters.',
                    style: TextStyle(color: tomatoRed, fontSize: 13.sp),
                  ),
                ),

              SizedBox(height: 40.h),

              // Continue button – integrates Supabase signup
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue ? _handleSignup : null,
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
                      : Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 15.h),

              if (_error != null) ...[
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: tomatoRed),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: tomatoRed),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15.h),
              ],

              // OR divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFFBDBDBD),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Or',
                      style: TextStyle(color: const Color(0xFFBDBDBD), fontSize: 14.sp),
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

              SizedBox(height: 15.h),

              // Google button (placeholder asset)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _googleSignup,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: const BorderSide(color: Colors.black54, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  icon: Image.asset(
                    'assets/login page/devicon_google.png',
                    width: 24,
                    height: 24,
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // Bottom link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        color: tomatoRed,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
