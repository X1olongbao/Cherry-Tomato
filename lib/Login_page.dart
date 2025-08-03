import 'package:flutter/material.dart';

const Color tomatoRed = Color(0xFFE53935);

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48,),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: tomatoRed,
                            ),
                          ),
                          Container(
                            height: 3,
                            margin: const EdgeInsets.only(top: 4),
                            color: tomatoRed,
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                          Container(
                            height: 3,
                            margin: const EdgeInsets.only(top: 4),
                            color: Colors.transparent,
                          )
                        ],
                      )
                    )
                  ],
                ),
                const SizedBox(height: 100),
                // Email label
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 6),
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Email field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                // Password label
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, top: 28, bottom: 6),
                  child: Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Password field
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password functionality
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: tomatoRed,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                    color: tomatoRed, 
                    fontSize: 16,
                    ),
                  ),
                  ),
                ),     
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {}, // sasusunod ka na logic
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tomatoRed.withOpacity(0.2),
                      foregroundColor: tomatoRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF), 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {}, //wala pa logic google login
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {}, //direcet to sign up
                      child: Text(
                        'Sign up',
                        style: TextStyle(
                          color: tomatoRed,
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
