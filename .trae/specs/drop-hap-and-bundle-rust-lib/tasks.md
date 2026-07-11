# Tasks

- [ ] Task 1: 移除 build-hap job 及 release 引用
  - [ ] 1.1: 删除 `.github/workflows/app.yml` 中整个 `build-hap` job（从 `# Job 3: HarmonyOS HAP 构建` 注释到 HAP artifact 上传步骤结束）
  - [ ] 1.2: 修改 `release` job 的 `needs: [cargo-doc, build-matrix, build-hap]` → `needs: [cargo-doc, build-matrix]`
  - [ ] 1.3: 修改 `release` job 的 `files` 列表，移除 `artifacts/app-hap/*` 行
  - [ ] 1.4: 验证 app.yml YAML 语法合法（`python3 -c "import yaml; yaml.safe_load(open('.github/workflows/app.yml'))"`）

- [ ] Task 2: cargo binstall 替换 cargo install
  - [ ] 2.1: 在 `cargo-doc` job 的 `Setup Rust toolchain` 之后新增 `Install cargo-binstall` 步骤（curl 官方脚本）
  - [ ] 2.2: `cargo-doc` job 的 `Install cargo-expand` 步骤改为 `cargo binstall --no-confirm cargo-expand --version 1.0.88`
  - [ ] 2.3: `cargo-doc` job 的 `Install flutter_rust_bridge_codegen` 步骤改为 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`
  - [ ] 2.4: 在 `build-matrix` job 的 `Setup Rust toolchain` 之后新增 `Install cargo-binstall` 步骤
  - [ ] 2.5: `build-matrix` job 的 `Install cargo-expand` 改为 `cargo binstall --no-confirm cargo-expand --version 1.0.88`
  - [ ] 2.6: `build-matrix` job 的 `Install flutter_rust_bridge_codegen` 改为 `cargo binstall --no-confirm flutter_rust_bridge_codegen --version 2.12.0`

- [ ] Task 3: codegen 命令加 --config 标志
  - [ ] 3.1: `cargo-doc` job 的 codegen 命令改为 `cd app && flutter_rust_bridge_codegen generate --config flutter_rust_bridge.yaml`
  - [ ] 3.2: `build-matrix` job 的 codegen 命令改为 `cd app && flutter_rust_bridge_codegen generate --config flutter_rust_bridge.yaml`

- [ ] Task 4: 桌面端 Rust cdylib 编译并复制到产物目录
  - [ ] 4.1: 在 `build-matrix` job 的 `Build Windows desktop` 步骤之后、`Upload Windows artifact` 之前，新增 `Build and copy Rust cdylib (Windows)` 步骤：`cd app/rust && cargo build --release` + `cp target/release/rust_lib.dll ../build/windows/x64/runner/Release/`（条件 `if: matrix.flutter_target == 'windows'`）
  - [ ] 4.2: 在 `Build Linux desktop` 之后、`Upload Linux artifact` 之前，新增 `Build and copy Rust cdylib (Linux)` 步骤：`cd app/rust && cargo build --release` + `cp target/release/librust_lib.so ../build/linux/x64/release/bundle/lib/`（条件 `if: matrix.flutter_target == 'linux'`，先 `mkdir -p` 目标目录）
  - [ ] 4.3: 在 `Build macOS desktop` 之后、`Upload macOS artifact` 之前，新增 `Build and copy Rust cdylib (macOS)` 步骤：`cd app/rust && cargo build --release` + `cp target/release/librust_lib.dylib ../build/macos/Build/Products/Release/smart_car_remote.app/Contents/Frameworks/`（条件 `if: matrix.flutter_target == 'macos'`，先 `mkdir -p` 目标目录）

- [ ] Task 5: Android Rust 库编译并复制到 jniLibs
  - [ ] 5.1: 在 `build-matrix` job 的 `Install cargo-binstall` 步骤之后，新增 `Install cargo-ndk` 步骤（`cargo binstall --no-confirm cargo-ndk`，条件 `if: matrix.flutter_target == 'apk'`）
  - [ ] 5.2: 新增 `Setup Android NDK` 步骤（`sdkmanager "ndk;27.0.12077973"` 或类似，条件 `if: matrix.flutter_target == 'apk'`，设置 `ANDROID_NDK_HOME` 环境变量）
  - [ ] 5.3: 在 `Build Android APK` 之前，新增 `Build Rust library for Android` 步骤：`cd app/rust && cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release`（条件 `if: matrix.flutter_target == 'apk'`）

- [ ] Task 6: 文档同步
  - [ ] 6.1: `AGENTS.md` 移除 HAP 相关陷阱条目（HarmonyOS HAP 构建 / gitcode fork / OpenHarmony SDK / hvigor / ohos / aarch64-unknown-linux-ohos target 等条目）
  - [ ] 6.2: `AGENTS.md` 新增陷阱：frb v2 不自动编译桌面/Android Rust cdylib，CI 需显式 `cargo build --release` + 复制共享库到产物目录；Android 需 `cargo-ndk` + jniLibs
  - [ ] 6.3: `AGENTS.md` 新增提示：`flutter_rust_bridge_codegen generate` 必须在 `app/` 目录下执行（config 文件 `app/flutter_rust_bridge.yaml`）；CI 加 `--config` 标志防御
  - [ ] 6.4: `AGENTS.md` 新增 cargo binstall 约定：CI 用 `cargo binstall --no-confirm` 替代 `cargo install` 加速
  - [ ] 6.5: `CHANGELOG.md` `[Unreleased]` 下按 Removed / Changed / Fixed 归类记录本次变更
  - [ ] 6.6: `README.md` 移除 HAP 构建相关说明（如有，检查后决定是否修改）

- [ ] Task 7: 提交与 PR
  - [ ] 7.1: 按 Conventional Commits 拆分多 commit 提交（ci: drop hap / ci: use cargo-binstall / ci: bundle rust cdylib / docs: sync 等）
  - [ ] 7.2: 推送到远程分支
  - [ ] 7.3: 用 `gh pr create` 创建 PR，标题与 body 遵循 Conventional Commits

# Task Dependencies
- Task 2 依赖 Task 1（同一文件编辑，先删 HAP job 再改其他步骤更清晰）
- Task 3 可与 Task 2 并行（改不同步骤，但同一文件需串行编辑）
- Task 4 / Task 5 依赖 Task 2（cargo-binstall 步骤需先就位，cargo-ndk 依赖 binstall）
- Task 6 依赖 Task 1-5（文档同步需反映所有代码变更）
- Task 7 依赖 Task 1-6（全部变更完成后才能提交 PR）
