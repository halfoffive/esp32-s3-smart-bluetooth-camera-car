# 修复 CI Android compileSdk patch 路径 Spec

## Why

`app.yml` 的 "Patch Android compileSdk" 步骤当前从仓库根目录引用 `app/android/app/build.gradle`，但步骤本身在仓库根目录执行。虽然路径在理论上正确，但持续报 `ERROR: app/android/app/build.gradle not found`，说明路径解析或工作目录上下文与预期不符。为与标准 Flutter 项目内部路径对齐并消除歧义，需将 patch 步骤的工作目录切换到 `app/`，并使用 `android/app/build.gradle` 与 `android/build.gradle` 的相对路径。

## What Changes

- `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤增加 `working-directory: app`，使其在 Flutter 项目根目录内执行
- 将该步骤中的文件路径从 `app/android/app/build.gradle` 改为 `android/app/build.gradle`
- 将该步骤中追加 subprojects 块的目标文件从 `app/android/build.gradle` 改为 `android/build.gradle`
- 在该步骤前增加文件列表诊断步骤，便于 CI 日志排查
- 更新 `AGENTS.md` 与 `CHANGELOG.md`，记录 Android patch 步骤须在 `app/` 工作目录下使用相对路径的约定

## Impact

- 受影响代码：`.github/workflows/app.yml` — "Patch Android compileSdk" 步骤的工作目录与路径
- 受影响文档：`CHANGELOG.md`（Fixed 条目）、`AGENTS.md`（工作目录约定）
- 不影响业务逻辑、BLE 协议、固件、UI

## ADDED Requirements

### Requirement: Android compileSdk patch 须在 `app/` 工作目录内执行

CI 中 "Patch Android compileSdk" 步骤 SHALL 设置 `working-directory: app`（或在 `run` 内先 `cd app`），并引用 `android/app/build.gradle` 与 `android/build.gradle` 相对路径。

#### Scenario: build.gradle 存在时正常 patch

- **WHEN** `flutter create .` 成功生成 `app/android/app/build.gradle`
- **THEN** patch 步骤在 `working-directory: app` 下执行
- **AND** `test -f android/app/build.gradle` 通过
- **AND** sed 将 compileSdk 提升至 35

#### Scenario: build.gradle 缺失时明确报错

- **WHEN** `app/android/app/build.gradle` 缺失
- **THEN** 步骤输出 `ERROR: android/app/build.gradle not found`
- **AND** 步骤以非零退出码退出

## MODIFIED Requirements

### Requirement: 构建流水线

仓库 SHALL 提供两条 GitHub Actions 工作流：
1. `firmware.yml`：PlatformIO 编译固件后用 `esptool.py merge-bin` 合并镜像
2. `app.yml`：在 `flutter create .` 后、于 `app/` 工作目录内 patch Android compileSdk 至 35，再构建 Android APK + Linux/Windows/macOS 桌面包

#### Scenario: Android APK 构建通过

- **WHEN** `app.yml` 的 `build-matrix` job 的 `apk` 条目运行
- **THEN** "Patch Android compileSdk" 步骤在 `app/` 目录内验证并 patch `android/app/build.gradle`
- **AND** `flutter build apk --release` 成功

## REMOVED Requirements

无。
