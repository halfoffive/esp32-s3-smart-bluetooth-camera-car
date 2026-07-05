# 修复 CI 中 Flutter 平台目录生成不完整导致 Android SDK patch 失败 Spec

## Why

`app.yml` 在 CI 中两次执行 `Patch Android compileSdk` 时均报错 `sed: can't read app/android/app/build.gradle: No such file or directory`。根因是仓库 `.gitignore` 已将 `app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 排除出版本控制，但这些目录下的 `.gitkeep` 仍被 git 跟踪；CI checkout 后平台目录存在但仅含 `.gitkeep`，`flutter create .` 检测到目录已存在，未完整重新生成 `android/app/build.gradle` 等文件，导致后续 sed 失败。同时 Android SDK patch 步骤在不需要 Android 构建的 job/矩阵条目中也运行，属于多余且放大失败面。

## What Changes

- 删除已跟踪的 `app/android/.gitkeep`、`app/linux/.gitkeep`、`app/macos/.gitkeep`、`app/windows/.gitkeep`，使 CI checkout 后平台目录不存在，`flutter create .` 可完整生成原生项目结构
- `.github/workflows/app.yml` 的 `cargo-doc` job 移除 `Patch Android compileSdk` 步骤（该 job 仅生成 Rust 文档，不构建 Android）
- `.github/workflows/app.yml` 的 `build-matrix` job 为 `Patch Android compileSdk` 步骤增加条件 `if: matrix.flutter_target == 'apk'`，仅在 Android 构建时执行
- 更新 `AGENTS.md` 与 `CHANGELOG.md`，记录平台目录不得含 `.gitkeep` 及 Android patch 条件约定

## Impact

- 受影响代码：
  - `app/android/.gitkeep` — 删除
  - `app/linux/.gitkeep` — 删除
  - `app/macos/.gitkeep` — 删除
  - `app/windows/.gitkeep` — 删除
  - `.github/workflows/app.yml` — 调整两个 job 的步骤与条件
- 受影响文档：`CHANGELOG.md`、`AGENTS.md`
- 不影响业务逻辑、BLE 协议、固件、UI

## ADDED Requirements

### Requirement: CI 中 Flutter 平台目录须由 `flutter create .` 完整生成

CI SHALL 确保 `flutter create .` 执行前，`app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 不存在或被清理，以便 `flutter create . --platforms=android,linux,windows,macos` 完整生成各平台原生文件。

#### Scenario: Android build.gradle 存在
- **WHEN** `app.yml` 的 Bootstrap Flutter platforms 步骤执行完毕
- **THEN** `app/android/app/build.gradle` 存在且包含 `compileSdk` 字段
- **AND** `app/android/build.gradle` 存在

#### Scenario: 本地目录不残留占位文件
- **WHEN** 开发者克隆仓库
- **THEN** `app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 不在版本控制中
- **AND** 开发者执行 `flutter create .` 后可获得完整平台目录

## MODIFIED Requirements

### Requirement: Android compileSdk patch 仅在需要 Android 构建时执行

仓库 CI 中 Android compileSdk patch 步骤 SHALL 仅在构建 Android APK 时执行； cargo-doc job 与 Linux/Windows/macOS 矩阵条目 SHALL 跳过该步骤。

#### Scenario: cargo-doc job 跳过 Android patch
- **WHEN** `app.yml` 的 `cargo-doc` job 运行
- **THEN** 不执行 `Patch Android compileSdk` 步骤
- **AND** `cargo doc --no-deps --all-features` 仍可正常生成文档

#### Scenario: build-matrix 非 Android 条目跳过 Android patch
- **WHEN** `app.yml` 的 `build-matrix` job 运行在 `linux` / `windows` / `macos` 条目
- **THEN** 不执行 `Patch Android compileSdk` 步骤
- **AND** 仅在 `apk` 条目执行该步骤

## REMOVED Requirements

无。
