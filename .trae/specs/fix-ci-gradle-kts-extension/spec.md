# 修复 CI Android Gradle 文件扩展名不匹配 Spec

## Why

CI 使用的 Flutter stable（3.44.4）现在默认生成 Kotlin DSL 的 Gradle 文件（`build.gradle.kts`），而非旧的 Groovy 文件（`build.gradle`）。当前 `app.yml` 的诊断与 patch 步骤仍引用 `build.gradle`，导致 `ls` 与 `test -f` 均找不到文件，CI 直接失败。

## What Changes

- `.github/workflows/app.yml` 的 "List Android project files" 步骤改为同时列出 `android/app/build.gradle*` 与 `android/build.gradle*`，兼容两种扩展名
- `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤改为自动检测 `build.gradle` 或 `build.gradle.kts`，并对检测到的文件执行 patch
- Kotlin DSL（`.kts`）的 `compileSdk` 写法与 Groovy 一致（`compileSdk = 35`），sed 正则保持兼容
- 注入 `subprojects` 块时，目标文件改为检测到的根 build 文件（`build.gradle` 或 `build.gradle.kts`），注入语法保持 Groovy 兼容（Kotlin DSL 的根 build 文件同样接受 Groovy 块，因为 subprojects 块是 Gradle 通用 DSL）
- 更新 `CHANGELOG.md`，记录 Gradle 文件扩展名兼容修复

## Impact

- 受影响代码：`.github/workflows/app.yml` — 诊断与 patch 步骤的文件路径检测逻辑
- 受影响文档：`CHANGELOG.md`（Fixed 条目）
- 不影响业务逻辑、BLE 协议、固件、UI

## ADDED Requirements

### Requirement: Android compileSdk patch 须兼容 Groovy 与 Kotlin DSL 两种 Gradle 文件

CI 中 "Patch Android compileSdk" 步骤 SHALL 自动检测 `android/app/build.gradle` 或 `android/app/build.gradle.kts`，并对实际存在的文件执行 sed patch；根 build 文件同理。若两者均不存在，SHALL 以明确错误信息退出。

#### Scenario: 仅存在 build.gradle.kts 时正常 patch

- **WHEN** `flutter create .` 生成 `android/app/build.gradle.kts` 与 `android/build.gradle.kts`
- **THEN** patch 步骤检测到 `.kts` 文件并执行 sed
- **AND** compileSdk 被提升至 35
- **AND** subprojects 块被追加到 `android/build.gradle.kts`

#### Scenario: 仅存在 build.gradle 时正常 patch

- **WHEN** `flutter create .` 生成 `android/app/build.gradle` 与 `android/build.gradle`
- **THEN** patch 步骤检测到 Groovy 文件并执行 sed
- **AND** compileSdk 被提升至 35
- **AND** subprojects 块被追加到 `android/build.gradle`

#### Scenario: 两种文件均不存在时明确报错

- **WHEN** `android/app/` 下既无 `build.gradle` 也无 `build.gradle.kts`
- **THEN** 步骤输出 `ERROR: no build.gradle or build.gradle.kts found in android/app/`
- **AND** 步骤以非零退出码退出

## MODIFIED Requirements

### Requirement: 构建流水线

仓库 SHALL 提供两条 GitHub Actions 工作流：
1. `firmware.yml`：PlatformIO 编译固件后用 `esptool.py merge-bin` 合并镜像
2. `app.yml`：在 `flutter create .` 后、于 `app/` 工作目录内 patch Android compileSdk 至 35（兼容 `build.gradle` 与 `build.gradle.kts`），再构建 Android APK + Linux/Windows/macOS 桌面包

#### Scenario: Android APK 构建通过

- **WHEN** `app.yml` 的 `build-matrix` job 的 `apk` 条目运行
- **THEN** "Patch Android compileSdk" 步骤自动检测 Gradle 文件扩展名并 patch
- **AND** `flutter build apk --release` 成功

## REMOVED Requirements

无。
