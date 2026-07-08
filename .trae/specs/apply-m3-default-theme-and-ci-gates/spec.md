# Material 3 默认主题 + Clippy 门槛 + CI 修复 Spec

## Why
当前 App 使用自定义橙黑配色（仅深色、`colorSchemeSeed: AppColors.accent`），不符合「Material 3 默认配色 + 深浅色 + 默认跟随系统」的要求；CI 中 Android `build.gradle.kts` 的 compileSdk patch 生成非法 Kotlin 语法（`compileSdk 35` 缺 `=`）、Linux 构建因 `keyboard_controller.dart` 缺 `KeyEventResult` 导入而失败；`cargo clippy` 存在警告但未设为提交门槛；AI 提交未分批。三项问题相互独立，需并行修复。

## What Changes
- **Flutter 主题**：改用 Material 3 默认 `ColorScheme`（不设种子色），提供 `light()` + `dark()`，`MaterialApp` 默认 `ThemeMode.system`（跟随系统）；设置页可切换 系统/浅色/深色，选择持久化到 `shared_preferences`（键 `car_theme_mode`）
- **移除自定义 `AppColors`**：结构色（bg/surface/surfaceVariant/accent/hudText/hudTextDim）一律改用 `Theme.of(context).colorScheme` 对应角色；状态语义色（active/warn/danger）改为 Material 默认色（`Colors.green` / `Colors.amber` / `colorScheme.error`），由新 `HudStatus` 类承载
- **修复 `keyboard_controller.dart`**：`import 'package:flutter/widgets.dart' show FocusNode;` → `show FocusNode, KeyEventResult;`
- **修复 `app.yml` Android compileSdk patch**：按文件扩展名区分 DSL —— `.gradle.kts` 用 `compileSdk = 35`（带 `=`，Kotlin 属性赋值），`.gradle` 用 `compileSdk 35`（Groovy 函数调用）；`subprojects` 注入块同步区分
- **新增 CI clippy 门槛**：`app.yml` 在 codegen 之后、build/doc 之前执行 `cargo clippy --all-features -- -D warnings`；修复现有 Rust clippy 警告
- **AGENTS.md 追加约定**：M3 默认配色 + 深浅色跟随系统；clippy 零警告提交门槛；AI 分批提交（按关注点拆 commit）

## Impact
- 受影响代码：
  - `app/lib/ui/theme.dart` — 重写为 M3 默认 light/dark + `HudStatus` 状态色，删除 `AppColors`
  - `app/lib/ui/theme_mode_controller.dart` — 新增 Riverpod 主题模式状态 + `shared_preferences` 持久化
  - `app/lib/main.dart` — 启动加载主题模式，`MaterialApp` 接入 `theme`/`darkTheme`/`themeMode`
  - `app/lib/ui/joystick.dart` — painter 接收 `Color` 参数，从 `colorScheme` 传入
  - `app/lib/ui/camera_viewport.dart` — `AppColors.*` → `colorScheme.*` / `HudStatus.*`
  - `app/lib/ui/telemetry_panel.dart` — 同上
  - `app/lib/ui/control_panel.dart` — 同上
  - `app/lib/ui/settings_screen.dart` — 移除 `AppColors`，新增主题模式选择控件
  - `app/lib/input/keyboard_controller.dart` — 补 `KeyEventResult` 导入
  - `.github/workflows/app.yml` — 修复 compileSdk patch + 新增 clippy 步骤
  - `app/rust/src/*.rs` — 修复 clippy 警告（重点 `image.rs` 重复赋值、`api.rs` match 可简化）
  - `AGENTS.md` / `CHANGELOG.md` — 同步约定与变更
- 不影响 BLE 协议、固件、引脚分配、电机控制逻辑

## ADDED Requirements

### Requirement: Material 3 默认配色 + 深浅色跟随系统
App SHALL 使用 Material 3 默认 `ColorScheme`（`useMaterial3: true`，不指定 `colorSchemeSeed` / 自定义种子色），同时提供浅色与深色主题；`MaterialApp` 默认 `ThemeMode.system`（跟随系统）。用户可在设置页切换 系统/浅色/深色，选择持久化到 `shared_preferences`（键 `car_theme_mode`，值为 `system`/`light`/`dark`）。

#### Scenario: 默认跟随系统
- **WHEN** 首次启动（无已保存主题模式）
- **THEN** App 使用 `ThemeMode.system`
- **AND** 浅色/深色随系统设置自动切换

#### Scenario: 用户切换主题模式
- **WHEN** 用户在设置页选择「深色」
- **THEN** 立即切换为深色主题
- **AND** 选择持久化，重启后仍为深色

#### Scenario: 结构色取自 ColorScheme
- **WHEN** 系统切换浅色/深色
- **THEN** 摇杆底圆 / 面板背景 / 主色按钮 / 文字颜色随 `Theme.of(context).colorScheme` 变化
- **AND** 不残留自定义橙黑硬编码色

### Requirement: CI clippy 零警告门槛
`app.yml` SHALL 在 `flutter_rust_bridge_codegen generate` 之后、`cargo doc` / `flutter build` 之前执行 `cargo clippy --all-features -- -D warnings`；存在任意 clippy 警告即构建失败。

#### Scenario: clippy 警告阻断 CI
- **WHEN** Rust 源含 clippy 警告
- **THEN** CI 失败
- **AND** 错误日志指向告警文件与行号

### Requirement: AI 分批提交
AI 助手在完成多关注点改动后 SHALL 按逻辑关注点拆分为多个独立 commit（如 CI 修复 / 主题改造 / clippy 门槛 / 文档各自独立），而非单一大 commit；每个 commit 遵循 Conventional Commits 且独立可编译。

#### Scenario: 多关注点改动分批提交
- **WHEN** 一次任务涉及 CI 修复 + 主题改造 + 文档
- **THEN** 产出 ≥3 个独立 commit
- **AND** 每个 commit 仅含该关注点的文件

## MODIFIED Requirements

### Requirement: Flutter UI 风格
Flutter 侧 SHALL 使用 Material Design 3 默认配色（`useMaterial3: true`，不设 `colorSchemeSeed`），结构色（背景/表面/主色/文字）一律取自 `Theme.of(context).colorScheme`；状态语义色（正常/警告/危险）使用 Material 默认色（`Colors.green` / `Colors.amber` / `colorScheme.error`），由 `HudStatus` 承载。Riverpod 状态管理。

#### Scenario: UI 跟随主题
- **WHEN** 系统切换浅色/深色
- **THEN** 所有面板 / 摇杆 / HUD 结构色随 `ColorScheme` 变化

## REMOVED Requirements

### Requirement: 自定义橙黑 HUD 配色
**Reason**: 用户要求改用 Material 3 默认配色
**Migration**: 删除 `AppColors` 类；颜色映射：`bg→colorScheme.surface`、`surface→colorScheme.surfaceContainerHighest`、`surfaceVariant→colorScheme.surfaceContainerHigh`、`accent→colorScheme.primary`、`accentDim→colorScheme.primaryContainer`、`hudText→colorScheme.onSurface`、`hudTextDim→colorScheme.onSurfaceVariant`、`danger→colorScheme.error`、`dataActive→HudStatus.active`、`warn→HudStatus.warn`
