# Checklist

## build-hap 移除
- [x] `.github/workflows/app.yml` 中不再包含 `build-hap` job（grep `build-hap` 无匹配）
- [x] `release` job 的 `needs` 不含 `build-hap`（实际为 `needs: [cargo-doc, build-matrix]`）
- [x] `release` job 的 `files` 不含 `artifacts/app-hap/*`
- [x] app.yml YAML 语法合法（`python3 -c "import yaml; yaml.safe_load(...)"` 通过）

## cargo binstall
- [x] `cargo-doc` job 有 `Install cargo-binstall` 步骤（curl 官方脚本，line 53）
- [x] `build-matrix` job 有 `Install cargo-binstall` 步骤（line 145）
- [x] `cargo-doc` job 用 `cargo binstall --no-confirm cargo-expand --version 1.0.88`（line 70）
- [x] `cargo-doc` job 用 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`（line 76）
- [x] `build-matrix` job 用 `cargo binstall --no-confirm cargo-expand --version 1.0.88`（line 162）
- [x] `build-matrix` job 用 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`（line 166）
- [x] 不再有 `cargo install cargo-expand` 或 `cargo install flutter_rust_bridge_codegen` 残留

## codegen --config
- [x] `cargo-doc` job 的 codegen 命令含 `--config flutter_rust_bridge.yaml`（line 89）
- [x] `build-matrix` job 的 codegen 命令含 `--config flutter_rust_bridge.yaml`（line 274）

## 桌面端 Rust cdylib
- [x] Windows 条目有 `Build and copy Rust cdylib (Windows)` 步骤，`if: matrix.flutter_target == 'windows'`（line 322）
- [x] Windows 步骤执行 `cargo build --release` 并复制 `rust_lib.dll` 到 `app/build/windows/x64/runner/Release/`（line 327）
- [x] Linux 条目有 `Build and copy Rust cdylib (Linux)` 步骤，`if: matrix.flutter_target == 'linux'`（line 310）
- [x] Linux 步骤执行 `cargo build --release` 并复制 `librust_lib.so` 到 `app/build/linux/x64/release/bundle/lib/`（line 315）
- [x] macOS 条目有 `Build and copy Rust cdylib (macOS)` 步骤，`if: matrix.flutter_target == 'macos'`（line 334）
- [x] macOS 步骤执行 `cargo build --release` 并复制 `librust_lib.dylib` 到 `.app/Contents/Frameworks/`（line 340）

## Android Rust 库
- [x] apk 条目有 `Install cargo-ndk` 步骤（`cargo binstall --no-confirm cargo-ndk`，line 169-171），`if: matrix.flutter_target == 'apk'`
- [x] apk 条目有 `Setup Android NDK` 步骤，设置 `ANDROID_NDK_HOME`（line 174）
- [x] apk 条目有 `Build Rust library for Android` 步骤，在 `Build Android APK` 之前（line 296）
- [x] Android 步骤执行 `cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release`（line 298）

## 文档同步
- [x] `AGENTS.md` 移除 HAP 相关陷阱条目（grep `HAP|HarmonyOS|ohos|gitcode|OpenHarmony|hvigor|ohpm|build-hap` 无匹配）
- [x] `AGENTS.md` 新增 frb v2 cdylib 需显式编译复制陷阱
- [x] `AGENTS.md` 新增 codegen 必须在 `app/` 下执行 + `--config` 防御提示
- [x] `AGENTS.md` 新增 cargo binstall 约定
- [x] `CHANGELOG.md` `[Unreleased]` 下记录本次变更（Removed / Changed / Fixed）
- [x] `README.md` 检查并移除 HAP 相关说明

## 提交与 PR
- [x] 多 commit 按 Conventional Commits 拆分（ci / docs 等）
- [x] 推送到远程分支
- [x] `gh pr create` 创建 PR（PR #9）
