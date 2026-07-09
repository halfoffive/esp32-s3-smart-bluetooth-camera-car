# 修复驾驶 tab 空白复现 + CI 增加 HAP 构建 Spec

## Why

用户报告上一轮修复（commit fe51645：`_DriveTab` 包 Scaffold+SafeArea + `IndexedStack` 加 `StackFit.expand`）后，**驾驶 tab 空白 + 底部 tab 不切换的 bug 仍然存在**。CI 全绿仅验证编译，未验证运行时渲染。同时用户要求 GitHub Action 增加 HarmonyOS HAP 构建（用 `gitcode.com/CPF-Flutter/flutter_flutter` 峰容层），并偏好优先使用 Rust 编写跨 FFI 逻辑。

## What Changes

### Part A: 驾驶 tab 空白修复（防御性 + 根因排查）
- **MODIFIED** `app/lib/main.dart`：`_HomeScreenState` 的 `ref.listen(bleControllerProvider, ...)` 从 `build` 顶部移到 `initState`（用 Riverpod 2 的 `ref.listenManual`），避免在 widget build 期间注册 listener 的潜在副作用（build 可能被重复调用，listener 重复注册虽被 Riverpod 去重但仍非最佳实践）。这是防御性改动，即使非根因也不会有害。
- **ADDED** 诊断辅助：在 `BleController` 构造与关键状态转移处加 `debugPrint`（仅 debug 模式），便于用户运行 `flutter run` 时提供日志定位根因。release 构建无副作用。

### Part B: CI 增加 HAP 构建
- **ADDED** `.github/workflows/app.yml` 新增 `build-hap` job（独立于现有 `build-matrix`，因 HAP 工具链与标准 Flutter 不同）：
  - Clone `flutter_flutter` SDK（替换标准 Flutter SDK）
  - 安装 OpenHarmony SDK（从 gitee openharmony docs 公开下载）+ hvigor/ohpm（npm 安装，`@ohos:registry=https://repo.harmonyos.com/npm/`）+ JDK 17
  - `flutter create . --platforms=ohos --org com.smartcar --project-name smart_car_remote` 生成 ohos 平台目录
  - `flutter_rust_bridge_codegen generate` + `flutter pub get`
  - `flutter build hap --release`（**unsigned**，签名需用户证书，留后续扩展）
  - 上传 `entry-default-unsigned.hap` artifact
- **ADDED** Rust 交叉编译目标：`aarch64-unknown-linux-ohos`（OpenHarmony arm64 目标，需 rustup 添加；若 rustup 未收录则用 `aarch64-linux-android` 近似目标作为 fallback，标注 TODO）
- **MODIFIED** release job 的 artifact 列表增加 `app-hap`

## Impact

- **Affected specs**: `refactor-m3-native-ui-and-device-config`（驾驶 tab 渲染）、`smart-bt-camera-car`（CI 流水线）
- **Affected code**:
  - `app/lib/main.dart`（`_HomeScreenState`：ref.listen 移到 initState）
  - `app/lib/ble/ble_controller.dart`（debugPrint 诊断日志，release 无副作用）
  - `.github/workflows/app.yml`（新增 build-hap job + release artifact 列表）
- **新增外部依赖**：OpenHarmony SDK ~1GB 下载、hvigor/ohpm npm 包、JDK 17、flutter_flutter SDK fork
- **CI 影响**：build-hap job 预计 15-25 分钟（SDK 下载 + 工具链安装 + 构建），与现有 build-matrix 并行
- **Rust 侧**：若 OpenHarmony Rust target 不在 rustup 官方收录，可能需用 nightly 或自定义 target JSON；本 spec 先用 fallback target，标注 TODO 待社区支持

## Assumptions & Decisions

1. **"相同状况" = 驾驶 tab 空白 + tab 不切换 bug 仍在**（上一轮修复未生效，CI 只验证编译未验证运行时）
2. **根因假设**：上一轮的 `StackFit.expand` + Scaffold 修复方向正确但不足。最可能根因是 `ref.listen` 在 `build` 期间注册的副作用（Riverpod 2 允许但推荐 `initState` + `ref.listenManual`）。若此修复后 bug 仍在，需用户提供 `flutter run` 日志深入排查（如 `FlutterReactiveBle` 构造异常、`frameStreamProvider` 订阅失败等）。
3. **HAP 构建先做 unsigned**：签名需要用户华为开发者证书（.p12 + .p7b profile），属敏感文件，留后续 spec 扩展。unsigned HAP 可用于内部测试与架构验证。
4. **优先 Rust 偏好**：本 spec 的 bug 修复是 Flutter UI 层（Dart），Rust 不直接适用；HAP 构建是 CI/工具链层。若后续涉及跨 FFI 新逻辑，优先 Rust 实现。
5. **OpenHarmony Rust target 不确定性**：rustup 官方可能未收录 `aarch64-unknown-linux-ohos`，先尝试，失败则 fallback 到 `aarch64-linux-android`（Android NDK 目标，与 ohos arm64 ABI 相近），标注 TODO 待 rustup 官方支持。
6. **flutter_flutter SDK 版本**：gitcode 仓库未标明版本，CI 中 clone 默认分支（main/master），若不稳定再锁定 commit。
7. **遵守 AGENTS.md**：M3 原生组件、中文注释、Conventional Commits、CI actions/* Node 24、clippy 零警告门槛、文档同步（CHANGELOG/README/AGENTS）。

## ADDED Requirements

### Requirement: CI 构建 HarmonyOS HAP 包
系统 SHALL 在 `.github/workflows/app.yml` 提供独立的 `build-hap` job，使用 `gitcode.com/CPF-Flutter/flutter_flutter` SDK fork 构建 unsigned HAP 包并上传为 artifact。

#### Scenario: HAP 构建成功
- **WHEN** push 到 main 分支且 `app/**` 或 `.github/workflows/app.yml` 变更
- **THEN** `build-hap` job 触发，安装 OpenHarmony SDK + hvigor + ohpm + JDK 17
- **AND** clone flutter_flutter SDK 替换标准 Flutter
- **AND** 生成 ohos 平台目录 + frb codegen + pub get
- **AND** 执行 `flutter build hap --release` 产出 unsigned HAP
- **AND** 上传 `app-hap` artifact（路径 `app/build/outputs/ohos/default/entry-default-unsigned.hap` 或 hvigor 产物路径）

#### Scenario: HAP 构建失败不阻塞其他平台
- **WHEN** `build-hap` job 失败（如 OpenHarmony SDK 下载失败、hvigor 版本不兼容）
- **THEN** 现有 `cargo-doc` / `build-matrix`（apk/linux/windows/macos）job 不受影响（`build-hap` 独立，release job 用 `if: success()` 或显式列出依赖 job）

### Requirement: 驾驶 tab 渲染诊断日志
系统 SHALL 在 debug 构建下，于 `BleController` 构造与关键状态转移处输出 `debugPrint` 诊断日志，便于用户运行 `flutter run` 时定位驾驶 tab 空白根因。release 构建下 `debugPrint` 无副作用（Flutter 框架自动剥离）。

#### Scenario: 用户运行 flutter run 排查
- **GIVEN** 用户在真机或模拟器运行 `flutter run`
- **WHEN** HomeScreen 首次构建 + IndexedStack 子节点构建
- **THEN** 控制台输出 `BleController` 构造 / `FlutterReactiveBle()` 实例化 / stream 订阅 / 错误的诊断日志
- **AND** 用户可将日志反馈给开发者定位根因

## MODIFIED Requirements

### Requirement: HomeScreen 错误反馈监听
`_HomeScreenState` 的 `ref.listen(bleControllerProvider, ...)` SHALL 在 `initState` 中用 `ref.listenManual` 注册（Riverpod 2 推荐用法），而非在 `build` 顶部用 `ref.listen`。避免 build 期间注册 listener 的潜在副作用（build 可能被框架多次调用）。

#### Scenario: 错误 SnackBar 仍可见
- **GIVEN** 用户在任意 tab（驾驶/设备/设置）
- **WHEN** `BleController.errorMessage` 变化
- **THEN** root ScaffoldMessenger 弹 SnackBar 显示错误（行为与上一轮修复一致，仅注册时机变更）

## REMOVED Requirements

无。本 spec 不移除任何现有功能。
