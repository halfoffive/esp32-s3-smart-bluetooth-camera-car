// settings_route.dart - 设置页底部滑入路由
//
// 供需要打开设置页的界面复用，统一转场方向与时长。

import 'package:flutter/material.dart';

import 'settings_screen.dart';
import 'theme.dart';

/// 构建从底部向上滑入的设置页路由。
Route<void> buildSettingsRoute() {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SettingsScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final isPop = animation.status == AnimationStatus.reverse;
      final curve = isPop ? AppAnim.curves.accel : AppAnim.curves.emphasized;
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: AppAnim.durations.pageTransition,
  );
}
