import 'package:flutter/material.dart';
import 'onboarding1_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/landing page/CHERRY TOMATO LOGO-01 1.png',
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cherry Tomato',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Boost your learning and productivity with the Pomodoro Technique',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE53935),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Onboarding1Page()),
                  );
                },
                child: Image.asset(
                  'assets/landing page/arrow button.png',
                  width: 32,
                  height: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}