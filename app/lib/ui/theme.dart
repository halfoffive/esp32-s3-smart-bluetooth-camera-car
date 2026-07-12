// theme.dart - Material 3 默认主题
//
// 使用 Material 3 默认 ColorScheme（不设种子色），提供浅色与深色主题。
// 默认跟随系统（ThemeMode.system），用户可在设置页切换 系统/浅色/深色。
// 结构色一律取自 Theme.of(context).colorScheme；状态语义色见 HudStatus。
// 等宽数值字体走系统 monospace 回退（不引入第三方字体包），与 M3 textTheme 角色统一。

import 'package:flutter/material.dart';

/// 应用主题。
class AppTheme {
  AppTheme._();

  /// 浅色主题：纯 Material 3 默认配色。
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  /// 深色主题：纯 Material 3 默认配色。
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }

  /// 等宽数据字体样式（RPM / 速度 / FPS 等数值）。
  ///
  /// 用于数值/数据展示；调用方按需传入 colorScheme.onSurface 等结构色。
  static TextStyle mono({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // Material 3 圆角 token。统一在此处声明，供卡片 / 弹层 / 段位复用，
  // 避免各页面重复硬编码散落的 BorderRadius.circular(N)。
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
}

/// 遥测 / 连接状态语义色。
///
/// 这些颜色承载固定语义（正常=绿、警告=黄、危险=红），
/// 不随 ColorScheme 主题变化，使用 Material 默认色。
class HudStatus {
  HudStatus._();

  /// 正常 / 已连接 / 电池正常
  static const Color active = Colors.green;

  /// 警告 / 连接中 / 电池偏低
  static const Color warn = Colors.amber;

  /// 危险色：取当前主题的 error 角色（深浅色自适应）。
  static Color dangerOf(BuildContext context) =>
      Theme.of(context).colorScheme.error;
}

/// 动画时长与曲线 token。
///
/// 所有 UI 动画应引用此处的 token，避免散落硬编码 `Duration`/`Curves`。
/// 参考 Material 3 motion 规范：
///   - short: 180ms（微反馈，如按下缩放）
///   - medium: 300ms（普通过渡，如透明度变化）
///   - long: 460ms（强调动画，如卡片入场）
///   - pageTransition: 360ms（页面级转场）
///   - touch: 140ms（触摸反馈，比 short 略快）
abstract final class AppAnim {
  AppAnim._();

  /// 动画时长 token。
  static const durations = _Durations();

  /// 动画曲线 token。
  static const curves = _Curves();
}

class _Durations {
  const _Durations();

  /// 微反馈（180ms）
  final Duration short = const Duration(milliseconds: 180);

  /// 普通过渡（300ms）
  final Duration medium = const Duration(milliseconds: 300);

  /// 强调动画（460ms）
  final Duration long = const Duration(milliseconds: 460);

  /// 页面级转场（360ms）
  final Duration pageTransition = const Duration(milliseconds: 360);

  /// 触摸反馈（140ms，比 short 略快）
  final Duration touch = const Duration(milliseconds: 140);
}

class _Curves {
  const _Curves();

  /// 减速进入：easeOutCubic（Material 3 emphasized）
  final Curve emphasized = Curves.easeOutCubic;

  /// 标准双向：easeInOutCubicEmphasized（Material 3 standard）
  final Curve standard = Curves.easeInOutCubicEmphasized;

  /// 减速：easeOut（旧称 decelerate）
  final Curve decel = Curves.easeOut;

  /// 弹性：easeOutBack（轻微回弹）
  final Curve spring = Curves.easeOutBack;

  /// 反向弹性：easeInBack（加速离开）
  final Curve springReverse = Curves.easeInBack;

  /// 加速离开：easeInCubic
  final Curve accel = Curves.easeInCubic;
}
