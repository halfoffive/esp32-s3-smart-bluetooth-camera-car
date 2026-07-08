// theme_mode_controller.dart - 主题模式（系统/浅色/深色）状态管理
//
// 默认跟随系统（ThemeMode.system）；用户在设置页切换后持久化到 shared_preferences，
// 键名 car_theme_mode（值：system / light / dark）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式状态控制器：加载 / 持久化 / 切换 ThemeMode。
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);

  /// 启动时从 shared_preferences 加载已保存的主题模式。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _parse(prefs.getString('car_theme_mode'));
  }

  /// 切换主题模式并持久化。
  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('car_theme_mode', mode.name);
  }

  static ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// 全局主题模式 provider。
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
