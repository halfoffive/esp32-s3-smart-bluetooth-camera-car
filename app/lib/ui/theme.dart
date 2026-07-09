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
