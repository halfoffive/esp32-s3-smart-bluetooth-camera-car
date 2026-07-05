// theme.dart - Material 3 主题：智能小车遥操仪表盘风格
//
// 配色：深空碳黑底 + 警示橙强调色 + 数据活跃绿，营造 FPV 无人机图传仪表感。
// 字体：Inter（正文）+ JetBrains Mono（数值/数据）。注：实际字体文件需在
//       pubspec.yaml 的 fonts: 段声明资源；本任务为不修改 pubspec，
//       在 theme 里使用 logical family 名，缺失时回退到系统无衬线/等宽。

import 'package:flutter/material.dart';

/// 全局调色板。
class AppColors {
  AppColors._();

  /// 主背景：深空碳黑
  static const Color bg = Color(0xFF0B0E14);

  /// 表层（卡片/面板）
  static const Color surface = Color(0xFF141822);

  /// 表层变体（凹陷区/摇杆底圆）
  static const Color surfaceVariant = Color(0xFF1E2330);

  /// 强调色：警示橙（HUD 高亮、按钮）
  static const Color accent = Color(0xFFFF6A00);

  /// 强调色变暗（hover/边框）
  static const Color accentDim = Color(0xFFB84A00);

  /// HUD 主文字色
  static const Color hudText = Color(0xFFE8ECF1);

  /// HUD 次要文字色
  static const Color hudTextDim = Color(0xFF8A93A6);

  /// 数据活跃绿（连接正常、电池正常）
  static const Color dataActive = Color(0xFF3DD68C);

  /// 警示黄（连接中/电池偏低）
  static const Color warn = Color(0xFFF5A623);

  /// 危险红（紧急停车/断连）
  static const Color danger = Color(0xFFE5484D);
}

/// 应用主题。
class AppTheme {
  AppTheme._();

  /// 暗色主题：基于警示橙种子色派生 Material 3 配色，覆盖关键表面色。
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.accent,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.hudText,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  /// 等宽数据字体样式（RPM / 速度 / FPS 等数值）。
  ///
  /// fontFamilyFallback 在 JetBrains Mono 字体资源未声明时回退到系统等宽。
  static TextStyle mono({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.hudText,
  }) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['Inter', 'Roboto Mono', 'monospace'],
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}
