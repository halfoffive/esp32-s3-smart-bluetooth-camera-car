# 修复 CI 构建流水线三处失败 Spec

## Why
仓库三条 CI 流水线（firmware.yml 的 `mergebin`、app.yml 的 `cargo doc`、app.yml 的 Android APK 构建）全部失败，阻塞了 v0.1.0 的发布与后续迭代。三个失败相互独立，根因各不相同，需逐一定位修复。

## What Changes
- **firmware.yml**：移除不可用的 `pio run -t mergebin` 目标（pioarduino 社区平台未注册该 SCons 目标），改用 `esptool.py merge-bin` 直接合并 bootloader + partitions + boot_app0 + firmware → `firmware-merged.bin`
- **app/rust/src/api.rs 与 image.rs**：补上 `use flutter_rust_bridge::frb;` 导入，使 `#[frb(sync)]` / `#[frb(opaque)]` 属性宏在 `cargo doc` 编译期可解析（codegen 不会自动向用户源文件注入该 import）
- **app.yml**：在 `flutter create .` 之后追加 patch 步骤，将 `android/app/build.gradle` 的 `compileSdk` 提升到 35，并在根 `android/build.gradle` 注入 `subprojects` 块强制所有插件模块（含 `reactive_ble_mobile`）使用 compileSdk ≥ 34，消除 AndroidX 1.7.x / 1.13.x 依赖对 SDK 34+ 的硬性要求

## Impact
- 受影响代码：
  - `.github/workflows/firmware.yml` — 替换 merge 步骤
  - `.github/workflows/app.yml` — 在两个 job 中各追加 Android SDK patch 步骤
  - `app/rust/src/api.rs` — 增加 1 行 import
  - `app/rust/src/image.rs` — 增加 1 行 import
- 受影响文档：`CHANGELOG.md`（记录 Fixed 条目）、`AGENTS.md`（追加 mergebin 陷阱与 compileSdk patch 约定）、`README.md`（若提及 mergebin 命令需同步）
- 不影响业务逻辑、协议、引脚分配、UI

## ADDED Requirements

### Requirement: 固件合并 bin 使用 esptool 直接合并
CI SHALL 在 PlatformIO 编译完成后，使用 `esptool.py --chip esp32s3 merge-bin` 显式合并四个分区镜像（bootloader @ 0x0、partitions @ 0x8000、boot_app0 @ 0xe000、firmware @ 0x10000）为单一 `firmware-merged.bin`，不再依赖 `pio run -t mergebin` 目标。

#### Scenario: 合并产物可烧录
- **WHEN** firmware.yml 触发并编译成功
- **THEN** 产出 `firmware-merged.bin` 位于仓库根目录
- **AND** `esptool.py write_flash 0x0 firmware-merged.bin` 可成功烧录并启动

#### Scenario: 不依赖 PIO mergebin 目标
- **WHEN** pioarduino 社区平台未注册 `mergebin` SCons 目标
- **THEN** CI 仍能完成合并，不出现 `Do not know how to make File target 'mergebin'` 错误

### Requirement: Android compileSdk 强制提升到 35
CI SHALL 在 `flutter create .` 之后、`flutter pub get` / `flutter build` 之前，对生成的 `android/` 目录执行 patch：
1. 将 `android/app/build.gradle` 中的 `compileSdk` 提升至 35
2. 在 `android/build.gradle` 注入 `subprojects` 块，对所有 Android library/application 模块强制 `compileSdk 35`

#### Scenario: 插件模块编译通过
- **WHEN** `flutter build apk --release` 触发
- **THEN** `:reactive_ble_mobile` 及所有 AndroidX 依赖以 compileSdk 35 编译
- **AND** 不再出现 `requires libraries and applications that depend on it to compile against version 34 or later` 错误

## MODIFIED Requirements

### Requirement: 构建流水线
仓库 SHALL 提供两条 GitHub Actions 工作流：
1. `firmware.yml`：PlatformIO 编译固件后用 `esptool.py merge-bin` 合并 bootloader+partitions+boot_app0+firmware，产物 `firmware-merged.bin` 可直接烧录到 0x0
2. `app.yml`：在 `flutter create .` 后 patch Android compileSdk 至 35，再构建 Android APK + Linux/Windows/macOS 桌面包，并运行 `cargo doc` 上传文档产物

#### Scenario: 固件产物
- **WHEN** firmware.yml 触发
- **THEN** 产出 `firmware-merged.bin`
- **AND** `esptool.py write_flash 0x0 firmware-merged.bin` 可烧录成功

#### Scenario: App 产物
- **WHEN** app.yml 触发
- **THEN** 上传 APK 与各平台桌面二进制为 artifact
- **AND** cargo-doc job 生成无警告文档

### Requirement: Rust 侧 frb 属性宏导入
Rust 源文件中所有使用 `#[frb(...)]` 属性的模块 SHALL 在文件顶部显式 `use flutter_rust_bridge::frb;`，确保 `cargo doc` / `cargo build` 在不依赖 codegen 注入的情况下也能解析该属性宏。

#### Scenario: cargo doc 通过
- **WHEN** 执行 `cargo doc --no-deps --all-features`
- **THEN** 不出现 `cannot find attribute 'frb' in this scope` 错误
- **AND** 文档生成无警告
