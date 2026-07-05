# 修复 CI 跨平台清理与 Android patch 兼容性 Spec

## Why

`app.yml` 的 `build-matrix` job 在 Windows runner 上失败（`rm -rf` 被 PowerShell 解析为 `Remove-Item`，不接受 `-rf` 参数），在 Linux runner 的 `apk` 条目上 sed patch 失败（`app/android/app/build.gradle: No such file or directory`）。两条路径均阻塞 App CI，需统一修复。

## What Changes

- `.github/workflows/app.yml` 的两处 "Clean platform directories" 步骤（`cargo-doc` job 与 `build-matrix` job）添加 `shell: bash`，使 Windows runner 使用 Git Bash 执行 `rm -rf` 而非 PowerShell
- `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤增加文件存在性守卫（`test -f`），并在 `flutter create .` 后追加 `ls app/android/app/build.gradle` 校验，确保 `flutter create .` 确实生成了 android 原生文件；若文件缺失则给出明确错误信息而非 sed 的隐式失败
- 更新 `AGENTS.md` 与 `CHANGELOG.md`，记录 Windows runner 须为 `rm -rf` 指定 `shell: bash` 的陷阱

## Impact

- 受影响代码：
  - `.github/workflows/app.yml` — 两处清理步骤加 `shell: bash`；Android patch 步骤加文件存在性守卫
- 受影响文档：`CHANGELOG.md`（Fixed 条目）、`AGENTS.md`（追加 Windows `rm -rf` 陷阱）
- 不影响业务逻辑、BLE 协议、固件、UI

## ADDED Requirements

### Requirement: CI 清理步骤须跨平台兼容

仓库 CI 中所有使用 Unix 专属命令（`rm -rf`、`cp -r` 等）的 `run` 步骤 SHALL 显式指定 `shell: bash`，确保在 Windows runner（默认 shell 为 PowerShell）上也能正确执行。

#### Scenario: Windows runner 清理步骤通过

- **WHEN** `app.yml` 的 `build-matrix` job 在 `windows-latest` runner 上运行 "Clean platform directories" 步骤
- **THEN** 步骤使用 Git Bash 执行 `rm -rf`
- **AND** 不出现 `A parameter cannot be found that matches parameter name 'rf'` 错误
- **AND** 步骤退出码为 0

### Requirement: Android compileSdk patch 须在文件存在时执行

CI 中 "Patch Android compileSdk" 步骤 SHALL 在执行 sed 之前验证 `app/android/app/build.gradle` 存在；若文件缺失，SHALL 以明确错误信息退出（非零退出码），而非依赖 sed 隐式失败。

#### Scenario: build.gradle 存在时正常 patch

- **WHEN** `flutter create .` 成功生成 `app/android/app/build.gradle`
- **THEN** sed patch 正常执行
- **AND** compileSdk 被提升至 35

#### Scenario: build.gradle 缺失时明确报错

- **WHEN** `flutter create .` 未生成 `app/android/app/build.gradle`
- **THEN** 步骤输出明确错误信息（如 `ERROR: app/android/app/build.gradle not found`）
- **AND** 步骤以非零退出码退出
- **AND** 不出现隐晦的 `sed: can't read ... No such file or directory` 错误

## MODIFIED Requirements

### Requirement: 构建流水线

仓库 SHALL 提供两条 GitHub Actions 工作流：
1. `firmware.yml`：PlatformIO 编译固件后用 `esptool.py merge-bin` 合并镜像
2. `app.yml`：在 `flutter create .` 后 patch Android compileSdk 至 35，再构建 Android APK + Linux/Windows/macOS 桌面包

所有跨平台 `run` 步骤 SHALL 使用 `shell: bash` 确保兼容性；Android patch 步骤 SHALL 在 sed 前验证目标文件存在。

#### Scenario: Windows runner 构建通过

- **WHEN** `app.yml` 的 `build-matrix` job 在 `windows-latest` 上运行
- **THEN** "Clean platform directories" 步骤通过
- **AND** "Bootstrap Flutter platforms" 步骤通过
- **AND** Windows 桌面包构建成功

#### Scenario: Android APK 构建通过

- **WHEN** `app.yml` 的 `build-matrix` job 的 `apk` 条目运行
- **THEN** "Patch Android compileSdk" 步骤验证 build.gradle 存在后执行 sed
- **AND** `flutter build apk --release` 成功

## REMOVED Requirements

无。
