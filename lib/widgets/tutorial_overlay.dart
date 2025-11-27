import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Widget that creates a spotlight effect on a target widget
class TutorialOverlay extends StatefulWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final bool showSkip;
  final bool hideNextButton;
  final Alignment tooltipAlignment;

  const TutorialOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.onNext,
    this.onSkip,
    this.showSkip = true,
    this.hideNextButton = false,
    this.tooltipAlignment = Alignment.bottomCenter,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPulsing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    if (_isPulsing) return;
    
    setState(() => _isPulsing = true);
    
    // Pulse animation: scale up and down multiple times
    _pulseController.forward().then((_) {
      _pulseController.reverse().then((_) {
        _pulseController.forward().then((_) {
          _pulseController.reverse().then((_) {
            _pulseController.forward().then((_) {
              _pulseController.reverse().then((_) {
                setState(() => _isPulsing = false);
              });
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false, // We handle hit testing manually
      child: Stack(
        children: [
          // Custom widget that blocks touches except on spotlight
          Positioned.fill(
            child: _SpotlightBlocker(
              targetKey: widget.targetKey,
              onWrongTap: _triggerPulse,
              pulseAnimation: _pulseAnimation,
            ),
          ),
          
          // Tooltip (always on top, but doesn't block spotlight)
          _buildTooltip(context),
        ],
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final RenderBox? renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return const SizedBox.shrink();
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    double top = position.dy + size.height + 12.h;
    double? bottom;
    
    // If tooltip would go off screen, show it above
    if (top > MediaQuery.of(context).size.height - 100.h) {
      top = position.dy - 90.h;
      if (top < 0) {
        bottom = 12.h;
        top = MediaQuery.of(context).size.height - 100.h;
      }
    }

    return Positioned(
      top: bottom == null ? top : null,
      bottom: bottom,
      left: 20.w,
      right: 20.w,
      child: IgnorePointer(
        ignoring: false, // Allow taps on tooltip buttons
        child: Material(
          color: Colors.transparent,
          child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (widget.showSkip && widget.onSkip != null)
                    TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(35.w, 24.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
              if (!widget.hideNextButton) ...[
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      minimumSize: Size(60.w, 28.h),
                    ),
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final GlobalKey targetKey;
  final Color color;
  final double pulseScale;

  _SpotlightPainter({
    required this.targetKey,
    required this.color,
    this.pulseScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // If target not found, just paint full overlay
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = color,
      );
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    // Add padding around target with pulse scale
    final padding = 8.0 * pulseScale;
    final centerX = position.dx + targetSize.width / 2;
    final centerY = position.dy + targetSize.height / 2;
    final width = (targetSize.width + (padding * 2)) * pulseScale;
    final height = (targetSize.height + (padding * 2)) * pulseScale;
    
    final spotlightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height,
      ),
      Radius.circular(12 * pulseScale),
    );

    // Create path with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(spotlightRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = color);

    // Draw border around spotlight with pulse effect
    canvas.drawRRect(
      spotlightRect,
      Paint()
        ..color = pulseScale > 1.0 ? const Color(0xFFE53935) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = pulseScale > 1.0 ? 4 : 3,
    );
    
    // Add extra glow when pulsing
    if (pulseScale > 1.0) {
      canvas.drawRRect(
        spotlightRect,
        Paint()
          ..color = const Color(0xFFE53935).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.pulseScale != pulseScale;
  }
}

/// Widget that blocks touches except on the spotlight area
class _SpotlightBlocker extends StatelessWidget {
  final GlobalKey targetKey;
  final VoidCallback onWrongTap;
  final Animation<double> pulseAnimation;

  const _SpotlightBlocker({
    required this.targetKey,
    required this.onWrongTap,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            // Check if tap is in spotlight area
            final RenderBox? targetRenderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
            if (targetRenderBox != null) {
              final targetPosition = targetRenderBox.localToGlobal(Offset.zero);
              final targetSize = targetRenderBox.size;
              final padding = 8.0;

              final spotlightRect = Rect.fromLTWH(
                targetPosition.dx - padding,
                targetPosition.dy - padding,
                targetSize.width + (padding * 2),
                targetSize.height + (padding * 2),
              );

              if (!spotlightRect.contains(details.globalPosition)) {
                // Tapped outside spotlight - trigger pulse
                onWrongTap();
              }
            }
          },
          child: CustomPaint(
            painter: _SpotlightPainter(
              targetKey: targetKey,
              color: Colors.black.withOpacity(0.85),
              pulseScale: pulseAnimation.value,
            ),
            child: _HitTestBlocker(
              targetKey: targetKey,
              onWrongTap: onWrongTap,
            ),
          ),
        );
      },
    );
  }
}

/// Custom widget that blocks hits except on spotlight
class _HitTestBlocker extends SingleChildRenderObjectWidget {
  final GlobalKey targetKey;
  final VoidCallback onWrongTap;

  const _HitTestBlocker({
    required this.targetKey,
    required this.onWrongTap,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHitTestBlocker(
      targetKey: targetKey,
      onWrongTap: onWrongTap,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHitTestBlocker renderObject) {
    renderObject.targetKey = targetKey;
    renderObject.onWrongTap = onWrongTap;
  }
}

class _RenderHitTestBlocker extends RenderProxyBox {
  GlobalKey targetKey;
  VoidCallback onWrongTap;

  _RenderHitTestBlocker({
    required this.targetKey,
    required this.onWrongTap,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Get the target widget's position and size
    final RenderBox? targetRenderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (targetRenderBox != null) {
      final targetPosition = targetRenderBox.localToGlobal(Offset.zero);
      final targetSize = targetRenderBox.size;
      final padding = 8.0;

      // Check if tap is within spotlight area (with padding)
      final spotlightRect = Rect.fromLTWH(
        targetPosition.dx - padding,
        targetPosition.dy - padding,
        targetSize.width + (padding * 2),
        targetSize.height + (padding * 2),
      );

      if (spotlightRect.contains(position)) {
        // Allow tap to pass through to target widget
        // Don't consume the hit test - return false so it continues to underlying widgets
        return false;
      }
    }

    // User tapped outside spotlight - trigger pulse animation
    onWrongTap();
    
    // Block all other taps
    return true;
  }
}

/// Pulsing pointer widget to draw attention
class PulsingPointer extends StatefulWidget {
  final Offset position;

  const PulsingPointer({super.key, required this.position});

  @override
  State<PulsingPointer> createState() => _PulsingPointerState();
}

class _PulsingPointerState extends State<PulsingPointer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: ScaleTransition(
        scale: _animation,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFE53935).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.touch_app,
              color: Color(0xFFE53935),
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
