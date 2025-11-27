import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'onboarding1_page.dart';
import '../utilities/smooth_page_route.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(height: 60.h),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/landing page/CHERRY TOMATO LOGO-01 1.png',
                  width: 270.w,
                  height: 270.w,
                ),
                SizedBox(height: 24.h),
                Text(
                  'Cherry Tomato',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE53935),
                  ),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    'Boost your learning and productivity with the Pomodoro Technique',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 40.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      createSmoothRoute(const Onboarding1Page()),
                    );
                  },
                  borderRadius: BorderRadius.circular(50),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/landing page/arrow button.png',
                        width: 32.w,
                        height: 32.w,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
