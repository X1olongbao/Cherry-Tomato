import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'onboarding3_page.dart';
import 'get_started_page.dart';
import '../utilities/smooth_page_route.dart';

class Onboarding2Page extends StatelessWidget {
  const Onboarding2Page({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 24.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          createSmoothRoute(const GetStartedPage()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        minimumSize: Size(60.w, 40.h),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: const Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/onboarding 2/Group 214.png',
                  width: 270.w,
                  height: 270.w,
                ),
                SizedBox(height: 24.h),
                Text(
                  'Hit Your Targets',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE53935),
                  ),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    'Stay productive with modes like Classic, Long Study, or Quick Task',
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(18.w),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    createSmoothRoute(const Onboarding3Page()),
                  );
                },
                child: Image.asset(
                  'assets/onboarding 2/arrow button ob2.png',
                  width: 32.w,
                  height: 32.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
