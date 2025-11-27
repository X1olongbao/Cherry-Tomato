import 'package:flutter/material.dart';

/// Creates a smooth slide transition for page navigation
PageRouteBuilder<T> createSmoothRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      
      var tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: curve),
      );
      
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
