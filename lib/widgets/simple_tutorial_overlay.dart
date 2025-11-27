import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Simple tutorial overlay with arrow pointer
class SimpleTutorialOverlay extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final GlobalKey? arrowTargetKey;
  final bool showArrowAbove;
  final bool centerCard;
  final String? imagePath;
  final Widget? customWidget;

  const SimpleTutorialOverlay({
    super.key,
    required this.title,
    required this.description,
    required this.onNext,
    this.onSkip,
    this.arrowTargetKey,
    this.showArrowAbove = false,
    this.centerCard = true,
    this.imagePath,
    this.customWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.7),
          ),
        ),

        // Tutorial card - always centered
        _buildPositionedCard(),
      ],
    );
  }

  Widget _buildPositionedCard() {
    // Always center the card vertically and horizontally
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20.w),
        constraints: BoxConstraints(maxWidth: 340.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE53935),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Custom widget (like mode buttons) if provided
            if (customWidget != null) ...[
              SizedBox(height: 16.h),
              customWidget!,
            ],
            
            // Image if provided
            if (imagePath != null) ...[
              SizedBox(height: 16.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.asset(
                  imagePath!,
                  height: 150.h,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40.sp,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            SizedBox(height: 20.h),

            // Buttons - centered
            Column(
              children: [
                // Main action button - centered
                Center(
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 32.w,
                        vertical: 12.h,
                      ),
                    ),
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Skip button below if provided
                if (onSkip != null) ...[
                  SizedBox(height: 8.h),
                  Center(
                    child: TextButton(
                      onPressed: onSkip,
                      child: Text(
                        'Skip Tutorial',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }



}
