# Checklist

## build-hap 移除
- [ ] `.github/workflows/app.yml` 中不再包含 `build-hap` job（grep `build-hap` 仅在注释或无匹配）
- [ ] `release` job 的 `needs` 不含 `build-hap`
- [ ] `release` job 的 `files` 不含 `artifacts/app-hap/*`
- [ ] app.yml YAML 语法合法（`python3 -c "import yaml; yaml.safe_load(...)"` 通过）

## cargo binstall
- [ ] `cargo-doc` job 有 `Install cargo-binstall` 步骤（curl 官方脚本）
- [ ] `build-matrix` job 有 `Install cargo-binstall` 步骤
- [ ] `cargo-doc` job 用 `cargo binstall --no-confirm cargo-expand --version 1.0.88`
- [ ] `cargo-doc` job 用 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`
- [ ] `build-matrix` job 用 `cargo binstall --no-confirm cargo-expand --version 1.0.88`
- [ ] `build-matrix` job 用 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`
- [ ] 不再有 `cargo install cargo-expand` 或 `cargo install flutter_rust_bridge_codegen` 残留

## codegen --config
- [ ] `cargo-doc` job 的 codegen 命令含 `--config flutter_rust_bridge.yaml`
- [ ] `build-matrix` job 的 codegen 命令含 `--config flutter_rust_bridge.yaml`

## 桌面端 Rust cdylib
- [ ] Windows 条目有 `Build and copy Rust cdylib (Windows)` 步骤，`if: matrix.flutter_target == 'windows'`
- [ ] Windows 步骤执行 `cargo build --release` 并复制 `rust_lib.dll` 到 `app/build/windows/x64/runner/Release/`
- [ ] Linux 条目有 `Build and copy Rust cdylib (Linux)` 步骤，`if: matrix.flutter_target == 'linux'`
- [ ] Linux 步骤执行 `cargo build --release` 并复制 `librust_lib.so` 到 `app/build/linux/x64/release/bundle/lib/`
- [ ] macOS 条目有 `Build and copy Rust cdylib (macOS)` 步骤，`if: matrix.flutter_target == 'macos'`
- [ ] macOS 步骤执行 `cargo build --release` 并复制 `librust_lib.dylib` 到 `.app/Contents/Frameworks/`

## Android Rust 库
- [ ] apk 条目有 `Install cargo-ndk` 步骤（`cargo binstall --no-confirm cargo-ndk`），`if: matrix.flutter_target == 'apk'`
- [ ] apk 条目有 `Setup Android NDK` 步骤，设置 `ANDROID_NDK_HOME`
- [ ] apk 条目有 `Build Rust library for Android` 步骤，在 `Build Android APK` 之前
- [ ] Android 步骤执行 `cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release`

## 文档同步
- [ ] `AGENTS.md` 移除 HAP 相关陷阱条目（HarmonyOS / gitcode fork / OpenHarmony SDK / hvigor / ohos / aarch64-unknown-linux-ohos）
- [ ] `AGENTS.md` 新增 frb v2 cdylib 需显式编译复制陷阱
- [ ] `AGENTS.md` 新增 codegen 必须在 `app/` 下执行 + `--config` 防御提示
- [ ] `AGENTS.md` 新增 cargo binstall 约定
- [ ] `CHANGELOG.md` `[Unreleased]` 下记录本次变更（Removed / Changed / Fixed）
- [ ] `README.md` 检查并移除 HAP 相关说明（如有）

## 提交与 PR
- [ ] 多 commit 按 Conventional Commits 拆分（ci / docs 等）
- [ ] 推送到远程分支
- [ ] `gh pr create` 创建 PR
