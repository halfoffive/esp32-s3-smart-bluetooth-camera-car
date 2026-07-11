# 全面弃用 HAP + 修复桌面/Android Rust cdylib 缺失 + cargo binstall 加速 Spec

## Why

CI 构建的桌面端产物启动即崩溃（`Failed to load dynamic library 'rust_lib.dll': The specified module could not be found. (error code: 126)`），根因是 frb v2 **不会**自动为桌面/Android 平台编译 Rust cdylib 并打包到产物目录——`flutter build windows/linux/macos` 只构建 Flutter 侧，Rust 共享库需显式编译并复制。HarmonyOS HAP 构建工具链长期不稳定（SDK URL 变动 / hvigor 包名 / ohos 平台目录生成），用户决定**全面弃用**。同时 `cargo install` 从源码编译 `cargo-expand` / `flutter_rust_bridge_codegen` 耗时过长，改用 `cargo-binstall` 下载预编译二进制加速。本地执行 `flutter_rust_bridge_codegen generate` 报 `Please provide rust_input` 是因为未在 `app/` 目录下执行（config 文件 `app/flutter_rust_bridge.yaml` 存在且格式正确）。

## What Changes

### Part A: 全面弃用 HAP
- **REMOVED** `.github/workflows/app.yml` 的整个 `build-hap` job（含 JDK 17 / flutter_flutter SDK fork / OpenHarmony SDK / hvigor/ohpm / ohos 平台生成 / HAP 构建与上传全部步骤）
- **MODIFIED** `release` job：`needs` 移除 `build-hap`（仅保留 `cargo-doc, build-matrix`），`files` 移除 `artifacts/app-hap/*`

### Part B: cargo binstall 加速
- **ADDED** `cargo-binstall` 自身安装步骤（curl 官方安装脚本），在 `cargo-doc` 与 `build-matrix` job 的 Rust 工具链配置之后
- **MODIFIED** `cargo install cargo-expand --version 1.0.88 --locked` → `cargo binstall --no-confirm cargo-expand --version 1.0.88`
- **MODIFIED** `cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked` → `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`
- 以上替换在 `cargo-doc` 与 `build-matrix` 两个 job 均执行

### Part C: 修复桌面端 Rust cdylib 缺失
- **ADDED** `build-matrix` job 在 `flutter build <platform> --release` 之后、`upload-artifact` 之前，按平台分支显式编译 Rust cdylib 并复制到产物目录：
  - **Windows**：`cd app/rust && cargo build --release`，复制 `target/release/rust_lib.dll` → `app/build/windows/x64/runner/Release/`
  - **Linux**：`cd app/rust && cargo build --release`，复制 `target/release/librust_lib.so` → `app/build/linux/x64/release/bundle/lib/`
  - **macOS**：`cd app/rust && cargo build --release`，复制 `target/release/librust_lib.dylib` → `app/build/macos/Build/Products/Release/smart_car_remote.app/Contents/Frameworks/`

### Part D: 修复 Android Rust 库缺失
- **ADDED** `cargo-ndk` 安装（`cargo binstall --no-confirm cargo-ndk`），仅 `apk` 矩阵条目
- **ADDED** Android NDK 安装步骤（`sdkmanager` ndk-bundle），仅 `apk` 矩阵条目
- **ADDED** 在 `flutter build apk --release` 之前，用 `cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release` 编译 `librust_lib.so` 并复制到 jniLibs

### Part E: codegen 配置健壮性
- **MODIFIED** codegen 命令加 `--config flutter_rust_bridge.yaml` 显式指定配置文件路径（`cargo-doc` 与 `build-matrix` job 均改）
- 配置文件 `app/flutter_rust_bridge.yaml` 内容不变（`rust_input: crate::api,crate::ble,crate::control,crate::image,crate::telemetry` 正确——Flutter 侧分别 import `api.dart` / `ble.dart` / `image.dart` / `control.dart`，需各模块独立生成绑定）

### Part F: 文档同步
- **MODIFIED** `AGENTS.md`：移除 HAP 相关陷阱条目；新增「桌面/Android Rust cdylib 需显式编译并复制」陷阱；新增「codegen 必须在 `app/` 目录下执行」提示
- **MODIFIED** `CHANGELOG.md`：`[Unreleased]` 下记录本次变更
- **MODIFIED** `README.md`：移除 HAP 构建相关说明（如有）

## Impact

- **Affected specs**: `fix-drive-blank-and-add-hap-ci`（HAP 部分被移除）、`smart-bt-camera-car`（CI 流水线）
- **Affected code**:
  - `.github/workflows/app.yml` — 移除 build-hap job、release needs/files 调整、cargo binstall 替换、Rust cdylib 编译复制步骤
  - `AGENTS.md` — HAP 陷阱移除 + 新增 cdylib/codegen 陷阱
  - `CHANGELOG.md` — 变更记录
  - `README.md` — HAP 说明移除（如有）
- **CI 影响**：移除 build-hap job 后 push/PR/tag 流水线不再含 HAP 步骤；cargo binstall 显著缩短工具链安装时间（从 ~3-5 分钟编译降到 ~30 秒下载）；桌面/Android 产物修复后可正常启动
- **BREAKING**：无（HAP job 此前已 `if: workflow_dispatch` 仅手动触发，移除不影响自动流水线；release 仍产出 android/linux/windows/macos 四平台产物）

## Assumptions & Decisions

1. **HAP 全面移除**：用户明确要求"全面弃用 hap"，不是仅改为手动触发——整个 job 及 release 引用全部删除。
2. **frb v2 不自动构建 cdylib**：frb v2 的 `flutter_rust_bridge` Dart 包仅提供 FFI 加载逻辑（`DynamicLibrary.open` / `System.loadLibrary`），**不**负责编译 Rust 库。桌面平台 CMake 集成需在 `windows/CMakeLists.txt` 等文件中配置，但 `app/{windows,linux,macos}/` 由 `flutter create .` 生成且 gitignored，无法在版本控制中维护 CMake 集成。因此采用 CI 显式编译 + 复制方案（最简方案，不引入 CMake patch 复杂度）。
3. **Android 用 cargo-ndk**：Android 交叉编译需 NDK sysroot + linker，`cargo-ndk` 封装了环境变量配置；`cargo build --target aarch64-linux-android` 裸用会因缺少 linker 失败。`cargo-ndk` 的 `-o` 参数直接输出到 jniLibs 目录。
4. **Android 仅 arm64-v8a**：现代 Android 设备绝大多数为 arm64；armeabi-v7a / x86_64 可后续按需扩展，当前不增加复杂度。
5. **cargo binstall 版本锁定**：`cargo-expand@1.0.88` / `flutter_rust_bridge_codegen@2.12.0` 与原 `cargo install --version` 一致；`cargo-ndk` 不锁版本（取 latest stable，避免版本号猜错导致 binstall 失败）。
6. **codegen `--config` 为防御性**：CI 当前 `cd app && flutter_rust_bridge_codegen generate` 已能找到 config，加 `--config` 是为防止 codegen 版本升级改变默认搜索行为。用户本地报错是未在 `app/` 下执行。
7. **提交纪律**：按 Conventional Commits 拆分多 commit（HAP 移除 / cargo binstall / cdylib 修复 / 文档同步各自独立），最后提 PR。

## ADDED Requirements

### Requirement: CI 显式编译并打包 Rust cdylib 到桌面端产物
CI SHALL 在 `flutter build <platform> --release` 之后、`upload-artifact` 之前，为 Windows / Linux / macOS 分别执行 `cargo build --release` 编译 Rust cdylib，并将共享库（`rust_lib.dll` / `librust_lib.so` / `librust_lib.dylib`）复制到对应平台 Flutter 构建产物目录，确保应用启动时 FFI `DynamicLibrary.open` 能找到库。

#### Scenario: Windows 产物可正常启动
- **WHEN** `build-matrix` 的 windows 条目执行
- **THEN** `flutter build windows --release` 后执行 `cd app/rust && cargo build --release`
- **AND** `rust_lib.dll` 复制到 `app/build/windows/x64/runner/Release/`
- **AND** `upload-artifact` 的 `app/build/windows/x64/runner/Release/*` 包含 `rust_lib.dll`
- **AND** 用户运行产物时不再报 `Failed to load dynamic library 'rust_lib.dll'`

#### Scenario: Linux 产物可正常启动
- **WHEN** `build-matrix` 的 linux 条目执行
- **THEN** `flutter build linux --release` 后执行 `cd app/rust && cargo build --release`
- **AND** `librust_lib.so` 复制到 `app/build/linux/x64/release/bundle/lib/`
- **AND** `upload-artifact` 的 `app/build/linux/x64/release/bundle/*` 包含 `librust_lib.so`

#### Scenario: macOS 产物可正常启动
- **WHEN** `build-matrix` 的 macos 条目执行
- **THEN** `flutter build macos --release` 后执行 `cd app/rust && cargo build --release`
- **AND** `librust_lib.dylib` 复制到 `smart_car_remote.app/Contents/Frameworks/`

### Requirement: CI 显式编译并打包 Rust cdylib 到 Android APK
CI SHALL 在 `flutter build apk --release` 之前，使用 `cargo-ndk` 为 `arm64-v8a` 编译 `librust_lib.so` 并复制到 `app/android/app/src/main/jniLibs/arm64-v8a/`，确保 APK 包含原生库。

#### Scenario: Android APK 包含 librust_lib.so
- **WHEN** `build-matrix` 的 apk 条目执行
- **THEN** 安装 `cargo-ndk`（via `cargo binstall`）+ Android NDK
- **AND** 执行 `cd app/rust && cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release`
- **AND** `librust_lib.so` 存在于 `app/android/app/src/main/jniLibs/arm64-v8a/`
- **AND** `flutter build apk --release` 将其打包进 APK

### Requirement: CI 使用 cargo-binstall 加速工具链安装
CI SHALL 使用 `cargo-binstall`（预编译二进制）安装 `cargo-expand` / `flutter_rust_bridge_codegen` / `cargo-ndk`，替代 `cargo install`（源码编译），缩短 CI 耗时。

#### Scenario: cargo binstall 替代 cargo install
- **WHEN** `cargo-doc` 或 `build-matrix` job 执行工具链安装步骤
- **THEN** 先通过官方 curl 脚本安装 `cargo-binstall`
- **AND** 用 `cargo binstall --no-confirm <pkg> --version <ver>` 安装各工具
- **AND** 不再出现 `cargo install` 源码编译的耗时

## MODIFIED Requirements

### Requirement: App CI 构建流水线
仓库 SHALL 保证 `.github/workflows/app.yml` 不再包含 `build-hap` job，`release` job 的 `needs` 仅列 `cargo-doc, build-matrix`，`files` 仅含 android/linux/windows/macos 四平台产物。

#### Scenario: HAP job 已移除
- **WHEN** 任何 push / PR / tag / workflow_dispatch 触发 app.yml
- **THEN** 流水线不包含 `build-hap` job
- **AND** `release` job 的 `needs` 不含 `build-hap`
- **AND** `release` job 的 `files` 不含 `artifacts/app-hap/*`

### Requirement: codegen 命令显式指定配置文件
CI SHALL 在 `flutter_rust_bridge_codegen generate` 命令中显式加 `--config flutter_rust_bridge.yaml`，防止 codegen 版本升级改变默认搜索路径。

#### Scenario: codegen 显式加载配置
- **WHEN** `cargo-doc` 或 `build-matrix` job 执行 codegen
- **THEN** 命令为 `cd app && flutter_rust_bridge_codegen generate --config flutter_rust_bridge.yaml`
- **AND** 不再出现 `Please provide rust_input` panic

## REMOVED Requirements

### Requirement: CI 构建 HarmonyOS HAP 包
**Reason**: 用户决定全面弃用 HAP；鸿蒙工具链（flutter_flutter SDK fork / OpenHarmony SDK / hvigor / ohpm）长期不稳定，下载安装耗时且易失败。
**Migration**: 无需迁移。HAP job 此前已改为 `if: workflow_dispatch` 仅手动触发，移除不影响自动流水线。如未来需要鸿蒙支持，可新建独立 spec 重新引入（建议用华为官方 DevEco Studio CLI 而非 gitcode fork）。
