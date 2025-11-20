// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:tomatonator/services/auth_service.dart';
import 'package:tomatonator/homepage/homepage_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      if (!mounted) return;
      // Navigate to Homepage and clear previous auth screens from stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
        (route) => false,
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Google Sign-In via Firebase, then go to Homepage on success.
  Future<void> _googleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // Force account picker by clearing cached selection first.
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // or: await googleSignIn.disconnect();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();
      if (gUser == null) {
        setState(() => _loading = false);
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
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Homepage()),
      );
    } catch (e) {
      setState(() => _error = 'Google sign-in failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google sign-in succeeded, but app login failed. Please ensure Supabase Google provider is enabled or try again.'
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
              const SizedBox(height: 40),
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
                  onPressed: _allFilled && !_loading ? _handleLogin : null,
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
                      : const Text('Continue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
                  onPressed: _googleLogin,
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
              if (_error != null) ...[
                const SizedBox(height: 16),
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