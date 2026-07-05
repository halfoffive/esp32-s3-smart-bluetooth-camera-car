# Tasks

## Bug 1: Windows runner 上 `rm -rf` 不兼容 PowerShell

- [x] Task 1: 为 "Clean platform directories" 步骤指定 `shell: bash`
  - [x] 1.1 在 `app.yml` 的 `cargo-doc` job（约第 57-58 行）的 "Clean platform directories" 步骤添加 `shell: bash`
  - [x] 1.2 在 `app.yml` 的 `build-matrix` job（约第 124-125 行）的 "Clean platform directories" 步骤添加 `shell: bash`
  - 验证：Windows runner 上 `rm -rf` 通过 Git Bash 执行，不报 `A parameter cannot be found that matches parameter name 'rf'`

## Bug 2: Android compileSdk patch 在 build.gradle 缺失时隐式失败

- [x] Task 2: 为 "Patch Android compileSdk" 步骤增加文件存在性守卫
  - [x] 2.1 在 sed 命令前增加 `test -f app/android/app/build.gradle || { echo "ERROR: app/android/app/build.gradle not found"; exit 1; }`
  - [x] 2.2 在 `flutter create .` 后（可选）追加 `ls -la app/android/app/build.gradle` 校验输出，便于 CI 日志排查
  - 验证：build.gradle 存在时 sed 正常执行；缺失时输出明确错误信息并以非零退出码退出

## 文档同步

- [x] Task 3: 更新 CHANGELOG 与 AGENTS
  - [x] 3.1 `CHANGELOG.md` 在 `[Unreleased]` → Fixed 下记录：修复 Windows runner 上 `rm -rf` 不兼容 PowerShell；Android patch 步骤增加文件存在性守卫
  - [x] 3.2 `AGENTS.md` 追加：CI 中 Unix 专属命令（`rm -rf` 等）须指定 `shell: bash` 以兼容 Windows runner
  - 验证：文档与本次变更一致

# Task Dependencies

- Task 1 与 Task 2 互不依赖，可并行
- Task 3 依赖 Task 1 / Task 2 完成后汇总变更点
