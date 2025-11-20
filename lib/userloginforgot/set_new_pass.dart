import 'package:flutter/material.dart';
import 'pass_success.dart' as success_page;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utilities/logger.dart';

const Color tomatoRed = Color(0xFFE53935);

class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key, required this.userId, required this.email});

  final String userId;
  final String email;

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _show1 = false;
  bool _show2 = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _pass1.addListener(() => setState(() {}));
    _pass2.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  bool get _validLength => _pass1.text.trim().length >= 8;
  bool get _match => _pass1.text == _pass2.text && _pass2.text.isNotEmpty;
  bool get _formValid => _validLength && _match;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formValid) return;
    try {
      final client = Supabase.instance.client;
      // Requires an active session for the target user.
      await client.auth.updateUser(UserAttributes(password: _pass1.text));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const success_page.PasswordResetSuccessPage()),
      );
    } catch (e) {
      Logger.e('Password update failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update password: ${e.toString().contains('401') ? 'Please sign in first.' : e}',
          ),
        ),
      );
    }
  }

  InputDecoration _decoration(
      {required String hint,
      required bool show,
      required VoidCallback onToggle}) {
    String? error;
    if (_submitted) {
      if (hint.startsWith('Enter')) {
        if (!_validLength) error = 'Min 8 characters';
      } else {
        // re-enter field
        if (!_match) error = 'Passwords do not match';
      }
    }
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: IconButton(
        icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: Colors.black54),
        onPressed: onToggle,
        splashRadius: 18,
      ),
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
      errorText: error,
    );
  }

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: Colors.white,
  ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (!_formValid) return tomatoRed.withValues(alpha: 0.35);
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
                const SizedBox(height: 18),
                const Text(
                  'Set a new password',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create a new password. Ensure it differs from\nprevious ones for security',
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.black87, height: 1.3),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 6),
                  child: Text('Password',
                      style: TextStyle(fontSize: 13, color: Colors.black)),
                ),
                TextField(
                  controller: _pass1,
                  obscureText: !_show1,
                  decoration: _decoration(
                    hint: 'Enter you new password',
                    show: _show1,
                    onToggle: () => setState(() => _show1 = !_show1),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 6),
                  child: Text('Password',
                      style: TextStyle(fontSize: 13, color: Colors.black)),
                ),
                TextField(
                  controller: _pass2,
                  obscureText: !_show2,
                  decoration: _decoration(
                    hint: 'Re-enter your new password',
                    show: _show2,
                    onToggle: () => setState(() => _show2 = !_show2),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _formValid
                        ? _submit
                        : () => setState(() => _submitted = true),
                    style: _btnStyle,
                    child: const Text('Update Password',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
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
