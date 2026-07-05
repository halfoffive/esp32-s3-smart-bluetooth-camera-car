# Tasks

## Bug 1: Flutter 平台目录因 `.gitkeep` 残留导致生成不完整

- [x] Task 1: 删除已跟踪的 platform `.gitkeep` 文件
  - [x] 1.1 删除 `app/android/.gitkeep`
  - [x] 1.2 删除 `app/linux/.gitkeep`
  - [x] 1.3 删除 `app/macos/.gitkeep`
  - [x] 1.4 删除 `app/windows/.gitkeep`
  - 验证：`git ls-files app/android app/linux app/macos app/windows` 无任何输出

- [x] Task 2: 确保 CI 中 `flutter create .` 前平台目录被清理
  - [x] 2.1 在 `app.yml` 的 `cargo-doc` job 中，`Bootstrap Flutter platforms` 步骤前增加 `rm -rf app/android app/ios app/linux app/macos app/windows`（容错清理）
  - [x] 2.2 在 `app.yml` 的 `build-matrix` job 中，`Bootstrap Flutter platforms` 步骤前增加相同清理步骤
  - 验证：CI 中 `flutter create .` 后 `app/android/app/build.gradle` 存在

## Bug 2: Android SDK patch 步骤在无关 job/矩阵条目运行

- [x] Task 3: 调整 `app.yml` 中 Android SDK patch 的触发条件
  - [x] 3.1 从 `cargo-doc` job 移除 `Patch Android compileSdk` 步骤
  - [x] 3.2 在 `build-matrix` job 的 `Patch Android compileSdk` 步骤增加 `if: matrix.flutter_target == 'apk'`
  - 验证：Linux/Windows/macOS 矩阵条目与 cargo-doc job 不再执行 Android SDK patch

## 文档同步

- [x] Task 4: 更新 CHANGELOG 与 AGENTS
  - [x] 4.1 `CHANGELOG.md` 在 `[Unreleased]` → Fixed 下记录：修复平台目录 `.gitkeep` 残留导致 `flutter create .` 生成不完整；限制 Android compileSdk patch 仅在 apk 构建时执行
  - [x] 4.2 `AGENTS.md` 追加：平台原生目录不得含 `.gitkeep`；CI 中 Android SDK patch 应加 `if: matrix.flutter_target == 'apk'`
  - 验证：文档与本次变更一致

# Task Dependencies

- Task 1 与 Task 2 解决同一根因，可并行执行；建议先完成 Task 1
- Task 3 与 Task 1 / Task 2 互不依赖，可并行
- Task 4 依赖 Task 1 / Task 2 / Task 3 完成后汇总变更点
