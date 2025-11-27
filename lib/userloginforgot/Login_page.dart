// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tomatonator/services/auth_service.dart';
import 'package:tomatonator/homepage/homepage_app.dart';
import 'package:tomatonator/userloginforgot/email_otp_verification_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
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
  bool _loading = false; // track ongoing login
  String? _error; // last error message
  bool _showPassword = false;

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

  // Perform Supabase email/password login and navigate to Homepage on success.
  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = AuthService.instance.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          await prefs.setBool('seen_onboarding_v1_$uid', true);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
        (route) => false,
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
      if (!mounted) return;
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Google Sign-In via Firebase, then go to Homepage on success.
  Future<void> _googleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Force account picker by clearing cached selection first.
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // or: await googleSignIn.disconnect();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) {
        // User cancelled the sign-in
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null; // Don't show error for user cancellation
          });
        }
        return; // aborted
      }
      
      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Ensure a Supabase session exists using Google id token if supported; otherwise, provision and sign in.
      try {
        if (gAuth.idToken != null) {
          await Supabase.instance.client.auth.signInWithIdToken(
            provider: Provider.google,
            idToken: gAuth.idToken!,
            accessToken: gAuth.accessToken,
          );
        }
      } catch (_) {
        // Ignore and continue to fallback
      }

      // If Supabase still has no current user, fallback to synthetic email/password.
      if (Supabase.instance.client.auth.currentUser == null) {
        final email = FirebaseAuth.instance.currentUser?.email ?? gUser.email;
        if (email.isEmpty) {
          throw Exception('Google account has no email; cannot create Supabase session');
        }

        final syntheticPassword = 'google-oauth-${gUser.id}-${email.hashCode}';
        // Try sign up, tolerate duplicate email
        try {
          await AuthService.instance.signUp(
            email: email,
            password: syntheticPassword,
            username: 'User',
          );
        } catch (_) {
          // If already registered or other non-fatal signup error, proceed to sign in
        }
        // Ensure we sign in to create an active Supabase session
        try {
          await AuthService.instance.signIn(
            email: email,
            password: syntheticPassword,
          );
        } catch (e) {
          // Unable to establish Supabase session (likely email confirmation required)
          throw Exception('Supabase login failed after Google sign-in: $e');
        }
      }

      // Create profile for new Google users if missing.
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
      } catch (_) {
        // Non-fatal
      }

      // Navigate only if Supabase session exists
      if (Supabase.instance.client.auth.currentUser == null) {
        throw Exception('Logged into Google (Firebase) but not into Supabase');
      }
      
      // Mark onboarding as seen for this user
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          await prefs.setBool('seen_onboarding_v1_$uid', true);
        }
      } catch (_) {}
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
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
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: active ? tomatoRed : Colors.grey[400])),
              Container(
                  height: 3.h,
                  margin: EdgeInsets.only(top: 4.h),
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
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 48.h),
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
              SizedBox(height: 40.h),
              Padding(
                  padding: EdgeInsets.only(left: 8.w, bottom: 6.h),
                  child: Text('Email',
                      style: TextStyle(fontSize: 16.sp, color: Colors.black))),
              TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration('Enter your email')),
              Padding(
                  padding: EdgeInsets.only(left: 8.w, top: 28.h, bottom: 6.h),
                  child: Text('Password',
                      style: TextStyle(fontSize: 16.sp, color: Colors.black))),
              TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  decoration: _fieldDecoration('Enter your password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                        size: 24.sp,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  )),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage())),
                  style: TextButton.styleFrom(
                      foregroundColor: tomatoRed,
                      textStyle: TextStyle(fontSize: 16.sp)),
                  child: Text('Forgot Password?',
                      style: TextStyle(color: tomatoRed, fontSize: 16.sp)),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allFilled && !_loading ? _handleLogin : null,
                  style: _continueStyle,
                  child: _loading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('Continue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16.sp)),
                ),
              ),
              SizedBox(height: 32.h),
              Row(children: [
                const Expanded(
                    child: Divider(color: Color(0xFFBDBDBD), thickness: 1)),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child:
                        Text('Or', style: TextStyle(color: const Color(0xFFBDBDBD), fontSize: 14.sp))),
                const Expanded(
                    child: Divider(color: Color(0xFFBDBDBD), thickness: 1)),
              ]),
              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _googleLogin,
                  icon: Image.asset('assets/login page/devicon_google.png',
                      width: 24.w, height: 24.h),
                  label: Text('Continue with Google',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: const BorderSide(color: Colors.black54, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r)),
                  ),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: tomatoRed, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: tomatoRed, fontSize: 14.sp),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16.h),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Don\'t have an account? ',
                    style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignUpPage())),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('Sign up',
                      style: TextStyle(
                          color: tomatoRed,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
