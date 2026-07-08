# Tasks

## Bug 1: firmware.yml mergebin 失败

- [x] Task 1: 替换 firmware.yml 的 merge 步骤为 esptool.py merge-bin
  - [x] 1.1 删除 `pio run -d firmware -e esp32s3-ci -t mergebin` 步骤
  - [x] 1.2 新增 `esptool.py --chip esp32s3 merge-bin` 步骤，合并 bootloader(0x0) + partitions(0x8000) + boot_app0(0xe000) + firmware(0x10000) → `firmware-merged.bin`
  - [x] 1.3 保留后续 `cp` / `upload-artifact` / `release` 步骤（产物名不变）
  - 验证：本地或 CI 中 `esptool.py write_flash 0x0 firmware-merged.bin` 可烧录（CI 内仅校验 merge 步骤退出码 0）

## Bug 2: cargo doc 找不到 frb 属性宏

- [x] Task 2: 为使用 `#[frb(...)]` 的源文件补 import
  - [x] 2.1 在 `app/rust/src/api.rs` 顶部增加 `use flutter_rust_bridge::frb;`
  - [x] 2.2 在 `app/rust/src/image.rs` 顶部增加 `use flutter_rust_bridge::frb;`
  - 验证：`cd app/rust && cargo doc --no-deps --all-features`（需先 codegen 生成 frb_generated.rs）无 `cannot find attribute 'frb'` 错误

## Bug 3: Android compileSdk 33 不满足插件依赖

- [x] Task 3: 在 app.yml 中追加 Android SDK patch 步骤
  - [x] 3.1 在 `cargo-doc` job 的 `Bootstrap Flutter platforms` 之后追加 patch 步骤：用 `sed` 将 `android/app/build.gradle` 的 `compileSdk` 提升到 35
  - [x] 3.2 在 `cargo-doc` job 同位置追加注入 `subprojects` 块到 `android/build.gradle`（强制所有模块 compileSdk 35）
  - [x] 3.3 在 `build-matrix` job 的 `Bootstrap Flutter platforms` 之后追加相同 patch 步骤（仅对 apk target 执行，已加 `if: matrix.flutter_target == 'apk'`）
  - 验证：`flutter build apk --release` 不再报 `compile against version 34 or later` 错误

## 文档同步

- [x] Task 4: 更新 CHANGELOG / AGENTS / README
  - [x] 4.1 `CHANGELOG.md` 在 `[Unreleased]` → Fixed 下记录三处修复
  - [x] 4.2 `AGENTS.md` 追加：pioarduino 平台不支持 `mergebin` 目标、须用 `esptool.py merge-bin`；`#[frb(...)]` 须显式 import；CI 须在 `flutter create .` 后 patch compileSdk
  - [x] 4.3 `README.md`（含根 README 与 `firmware/README.md`）中 mergebin 相关命令已同步为 `esptool.py merge-bin` 命令
  - 验证：三个文档均反映最新 CI 行为

# Task Dependencies
- Task 1 / Task 2 / Task 3 互不依赖，可并行
- Task 4 依赖 Task 1 / 2 / 3 完成后汇总变更点
