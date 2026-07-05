# Checklist

## Bug 1: 平台目录生成不完整
- [x] 已删除 `app/android/.gitkeep`
- [x] 已删除 `app/linux/.gitkeep`
- [x] 已删除 `app/macos/.gitkeep`
- [x] 已删除 `app/windows/.gitkeep`
- [x] `git ls-files app/android app/linux app/macos app/windows` 无输出
- [x] `app.yml` 的 `cargo-doc` job 在 `flutter create .` 前执行清理
- [x] `app.yml` 的 `build-matrix` job 在 `flutter create .` 前执行清理
- [x] CI 中 `flutter create .` 后 `app/android/app/build.gradle` 存在

## Bug 2: Android SDK patch 条件
- [x] `app.yml` 的 `cargo-doc` job 不再包含 `Patch Android compileSdk` 步骤
- [x] `app.yml` 的 `build-matrix` job 的 `Patch Android compileSdk` 步骤带 `if: matrix.flutter_target == 'apk'`
- [x] Linux/Windows/macOS 矩阵条目不执行 Android SDK patch

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下已记录本次两处修复
- [x] `AGENTS.md` 已追加平台目录 `.gitkeep` 与 Android patch 条件约定
