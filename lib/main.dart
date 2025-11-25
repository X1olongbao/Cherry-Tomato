import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'landingpage/landing_page.dart';
import 'homepage/homepage_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utilities/init.dart';
import 'utilities/usage_lifecycle_host.dart';

class CherryTomatoApp extends StatelessWidget {
  const CherryTomatoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'Cherry Tomato',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: Supabase.instance.client.auth.currentUser != null
            ? const Homepage()
            : const LandingPage(),
      ),
    );
  }
}

// Ensure backend (Supabase, SQLite, Sync) is initialized before the app starts
// so that authentication and session storage are ready for UI interactions.
Future<void> main() async {
  await initializeBackend();
  runApp(const UsageLifecycleHost(child: CherryTomatoApp()));
}
