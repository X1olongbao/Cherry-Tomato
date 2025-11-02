import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:tomatonator/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Perform Supabase email/password signup, save username metadata, then go to Login.
  Future<void> _handleSignup() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Save the entered username to Supabase auth user metadata
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'username': _usernameCtrl.text.trim()}),
        );
      } catch (_) {
        // Ignore metadata update errors; signup succeeded
      }
      if (!mounted) return;
      // Navigate back to Login so user can log in with new credentials
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please log in.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
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
                obscureText: true,
                decoration: _fieldDecoration('Enter your password').copyWith(
                  suffixIcon:
                      const Icon(Icons.visibility_off, color: Colors.grey),
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
                  onPressed: () {},
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
