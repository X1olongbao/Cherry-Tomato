import 'package:flutter/material.dart';
import 'landing_page.dart';

class CherryTomatoApp extends StatelessWidget {
  const CherryTomatoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cherry Tomato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LandingPage(),
    );
  }
}

void main() => runApp(const CherryTomatoApp());
