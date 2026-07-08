# Tasks

## Bug 修复（CI 阻塞，可立即并行）

- [x] Task 1: 修复 keyboard_controller.dart 缺少 KeyEventResult 导入
  - [x] 1.1 将 `import 'package:flutter/widgets.dart' show FocusNode;` 改为 `show FocusNode, KeyEventResult;`
  - 验证：`flutter build linux --release` 不再报 `Type 'KeyEventResult' not found`

- [x] Task 2: 修复 app.yml 的 Android compileSdk patch 生成非法 Kotlin DSL
  - [x] 2.1 重写 `Patch Android compileSdk` 步骤的 sed：按文件扩展名区分 —— `.gradle.kts` 文件 patch 后为 `compileSdk = 35`（带 `=`），`.gradle` 文件为 `compileSdk 35`
  - [x] 2.2 根 `build.gradle(.kts)` 注入的 `subprojects` 块同样按 DSL 区分：`.kts` 用 `compileSdk = 35`，`.gradle` 用 `compileSdk 35`
  - 验证：CI `flutter build apk --release` 不再报 `Unexpected tokens (use ';' to separate expressions)`

## Clippy 门槛

- [x] Task 3: 新增 CI clippy 门槛并修复现有警告
  - [x] 3.1 在 `app.yml` 的 `cargo-doc` job 与 `build-matrix` job 中、`Generate flutter_rust_bridge bindings` 之后、`cargo doc` / `flutter build` 之前，新增 `Run cargo clippy` 步骤：`cd app/rust && cargo clippy --all-features -- -D warnings`
  - [x] 3.2 本地运行 `flutter_rust_bridge_codegen generate` 后 `cargo clippy --all-features -- -D warnings`，修复全部警告（重点 `image.rs` push() 中 if/else 两分支重复赋值 → 提取公共赋值；`api.rs` match 可简化为 `Option::and_then`）
  - 验证：`cargo clippy --all-features -- -D warnings` 退出码 0

## Material 3 默认主题改造

- [x] Task 4: 重写 theme.dart 为 M3 默认配色
  - [x] 4.1 删除 `AppColors` 类（含所有自定义 hex 色）
  - [x] 4.2 `AppTheme.light()` → `ThemeData(useMaterial3: true, brightness: Brightness.light)`
  - [x] 4.3 `AppTheme.dark()` → `ThemeData(useMaterial3: true, brightness: Brightness.dark)`
  - [x] 4.4 `AppTheme.mono()` 保留等宽字体样式，`color` 参数默认 `null`
  - [x] 4.5 新增 `HudStatus` 类：`active = Colors.green`、`warn = Colors.amber`、`danger` 取 `colorScheme.error`（提供 `dangerOf(BuildContext)` 静态方法）
  - 验证：theme.dart 无 `colorSchemeSeed` / 自定义 hex 结构色

- [x] Task 5: 新增 theme_mode_controller.dart + main.dart 接入（依赖 Task 4）
  - [x] 5.1 新建 `app/lib/ui/theme_mode_controller.dart`：`ThemeModeController extends StateNotifier<ThemeMode>`，初值 `ThemeMode.system`；`load()` 从 `shared_preferences` 读 `car_theme_mode`；`set(ThemeMode)` 持久化并更新 state；暴露 `themeModeProvider`
  - [x] 5.2 `main.dart`：`WidgetsFlutterBinding.ensureInitialized()` 后 `ProviderContainer()` + `read(themeModeProvider.notifier).load()`，`UncontrolledProviderScope` 包裹；`SmartCarApp` 读 `ref.watch(themeModeProvider)` 设 `themeMode`，`theme: AppTheme.light()`、`darkTheme: AppTheme.dark()`
  - 验证：默认跟随系统；切换后重启仍保持

- [ ] Task 6: 重构 UI 文件 AppColors → colorScheme（依赖 Task 4）
  - [x] 6.1 `joystick.dart`：`_JoystickPainter` 增加 `Color` 参数（baseFill / baseStroke / cross / thumb / thumbHighlight），`build` 中从 `Theme.of(context).colorScheme` 取值传入
  - [x] 6.2 `camera_viewport.dart`：`AppColors.bg→colorScheme.surface`、`accent→primary`、`hudTextDim→onSurfaceVariant`、`dataActive→HudStatus.active`、`warn→HudStatus.warn`、`danger→HudStatus.dangerOf(context)`；HUD 芯片黑底渐变（`Colors.black`）保留（视频叠层可读性）
  - [x] 6.3 `telemetry_panel.dart`：`surfaceVariant→surfaceContainerHigh`、`hudText→onSurface`、`hudTextDim→onSurfaceVariant`、`dataActive/warn/danger→HudStatus`
  - [x] 6.4 `control_panel.dart`：`surface→surfaceContainerHighest`、`surfaceVariant→surfaceContainerHigh`、`accent→primary`、`hudText→onSurface`、`hudTextDim→onSurfaceVariant`、`danger→HudStatus.dangerOf(context)`
  - [x] 6.5 `settings_screen.dart`：移除全部 `AppColors` 引用（→ `colorScheme`）；顶部新增「外观」段，含主题模式选择（`SegmentedButton` 或下拉：系统/浅色/深色），读写 `themeModeProvider`
  - 验证：`grep -r "AppColors" app/lib` 无输出；浅色/深色下 UI 一致无残留橙黑

## 文档与提交

- [ ] Task 7: 更新 AGENTS.md / CHANGELOG.md（依赖 Task 1-6）
  - [ ] 7.1 `AGENTS.md`：
    - 「用户强制风格」Flutter 侧补充「Material 3 默认配色（不设种子色），深浅色默认跟随系统，设置页可切换」
    - 「工具链陷阱」追加：Kotlin DSL（`.gradle.kts`）compileSdk patch 必须带 `=`（`compileSdk = 35`），Groovy（`.gradle`）不带；`KeyEventResult` 在 `package:flutter/widgets.dart`，`show` 导入须显式列出
    - 新增「提交纪律」段：`cargo clippy --all-features -- -D warnings` 必须通过才能提交；AI 多关注点改动须分批提交（独立可编译 commit）
  - [ ] 7.2 `CHANGELOG.md` `[Unreleased]`：Added（主题模式设置 / clippy 门槛）、Changed（M3 默认配色替代自定义橙黑）、Fixed（KeyEventResult 导入 / Android compileSdk Kotlin 语法）
  - 验证：文档与变更一致

- [ ] Task 8: 分批 git 提交（依赖 Task 1-7，按关注点拆分）
  - [ ] 8.1 `fix(input): 补 KeyEventResult 导入修复 Linux 构建`
  - [ ] 8.2 `fix(ci): 修复 Android compileSdk patch 的 Kotlin DSL 语法`
  - [ ] 8.3 `ci: 新增 cargo clippy 零警告门槛并修复现有警告`
  - [ ] 8.4 `feat: Material 3 默认配色 + 深浅色跟随系统 + 主题模式设置`
  - [ ] 8.5 `docs: 更新 AGENTS 约定与 CHANGELOG`
  - 验证：每个 commit 独立可编译；遵循 Conventional Commits

# Task Dependencies

- Task 1 / Task 2 / Task 3 / Task 4 互不依赖，**Batch 1 可并行**
- Task 5 依赖 Task 4（theme.dart API）
- Task 6 依赖 Task 4（theme.dart API + HudStatus）
- Task 5 / Task 6 **Batch 2 可并行**（同在 Task 4 完成后）
- Task 7 依赖 Task 1-6 完成
- Task 8 依赖 Task 1-7，按 8.1→8.2→8.3→8.4→8.5 顺序提交
