# Checklist

## Bug 1: KeyEventResult 导入
- [x] `keyboard_controller.dart` 的 `package:flutter/widgets.dart` import 含 `KeyEventResult`（`show FocusNode, KeyEventResult;`）
- [x] `flutter build linux --release` 不再报 `Type 'KeyEventResult' not found`

## Bug 2: Android compileSdk patch（Kotlin DSL 语法）
- [x] `.gradle.kts` 文件 patch 后为 `compileSdk = 35`（带 `=`）
- [x] `.gradle` 文件 patch 后为 `compileSdk 35`（不带 `=`）
- [x] 注入的 `subprojects` 块语法匹配对应 DSL（`.kts` 带 `=`，`.gradle` 不带）
- [x] patch 仅在 `matrix.flutter_target == 'apk'` 时执行
- [x] `flutter build apk --release` 不再报 `Unexpected tokens`

## Clippy 门槛
- [x] `app.yml` 的 `cargo-doc` job 含 `Run cargo clippy` 步骤（`cargo clippy --all-features -- -D warnings`）
- [x] `app.yml` 的 `build-matrix` job 含相同 clippy 步骤
- [x] clippy 步骤位于 `Generate flutter_rust_bridge bindings` 之后、`cargo doc` / `flutter build` 之前
- [x] `app/rust/src/*.rs` 无 clippy 警告（`image.rs` 重复赋值已合并、`api.rs` match 已简化）
- [x] `cargo clippy --all-features -- -D warnings` 退出码 0

## M3 默认主题
- [x] `theme.dart` 不含 `colorSchemeSeed` / 自定义种子色
- [x] `theme.dart` 不含 `AppColors` 类
- [x] `AppTheme.light()` 与 `AppTheme.dark()` 均存在且仅 `useMaterial3: true` + `brightness`
- [x] `theme.dart` 含 `HudStatus` 类（active=Colors.green, warn=Colors.amber, danger 经 colorScheme.error）
- [x] `main.dart` 设 `theme: AppTheme.light()`、`darkTheme: AppTheme.dark()`、`themeMode: ref.watch(themeModeProvider)`
- [x] 默认 `ThemeMode.system`（无已保存值时）
- [x] `theme_mode_controller.dart` 存在，`load()` 读 `car_theme_mode`，`set()` 持久化
- [x] `settings_screen.dart` 含主题模式选择控件（系统/浅色/深色）
- [x] `grep -r "AppColors" app/lib` 无输出
- [x] `joystick.dart` painter 颜色由 `colorScheme` 传入
- [x] `camera_viewport.dart` 无 `AppColors` 引用（HUD 黑底叠层可保留 `Colors.black`）
- [x] `telemetry_panel.dart` 无 `AppColors` 引用
- [x] `control_panel.dart` 无 `AppColors` 引用
- [x] `settings_screen.dart` 无 `AppColors` 引用
- [x] 浅色与深色模式下 UI 一致，无残留橙黑硬编码色

## 文档
- [x] `AGENTS.md` 「用户强制风格」含 M3 默认配色 + 深浅色跟随系统约定
- [x] `AGENTS.md` 「工具链陷阱」含 Kotlin DSL compileSdk 须带 `=` 约定
- [x] `AGENTS.md` 「工具链陷阱」含 `KeyEventResult` 须显式 `show` 导入约定
- [x] `AGENTS.md` 含「提交纪律」段（clippy 零警告 + AI 分批提交）
- [x] `CHANGELOG.md` `[Unreleased]` 记录 Added / Changed / Fixed 三类

## 提交
- [x] 至少 5 个独立 commit，按关注点拆分（input 修复 / ci Android 修复 / clippy 门槛 / M3 主题 / 文档）
- [x] 每个 commit 遵循 Conventional Commits 格式
- [x] 每个 commit 独立可编译
