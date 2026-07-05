# Checklist

## Bug 1: firmware mergebin
- [x] `firmware.yml` 不再包含 `pio run -t mergebin` 步骤
- [x] `firmware.yml` 使用 `esptool.py --chip esp32s3 merge-bin` 合并四个镜像
- [x] 合并偏移量正确：bootloader=0x0、partitions=0x8000、boot_app0=0xe000、firmware=0x10000
- [x] 产物名仍为 `firmware-merged.bin`，upload-artifact / release 步骤无需改动

## Bug 2: cargo doc frb 导入
- [x] `app/rust/src/api.rs` 顶部包含 `use flutter_rust_bridge::frb;`
- [x] `app/rust/src/image.rs` 顶部包含 `use flutter_rust_bridge::frb;`
- [x] 没有其它源文件使用 `#[frb(...)]` 而遗漏 import（已检查 ble/control/telemetry/lib，确认无需补）

## Bug 3: Android compileSdk
- [x] `app.yml` 的 `cargo-doc` job 在 `flutter create .` 后追加 patch 步骤
- [x] `app.yml` 的 `build-matrix` job 同样追加 patch 步骤
- [x] patch 将 `android/app/build.gradle` 的 compileSdk 提升到 35
- [x] patch 在 `android/build.gradle` 注入 `subprojects` 块强制所有模块 compileSdk 35
- [x] patch 步骤在 `flutter pub get` / `cargo doc` / `flutter build` 之前执行

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下记录三处修复
- [x] `AGENTS.md` 追加三条工具链陷阱（mergebin / frb import / compileSdk patch）
- [x] `README.md` 中 mergebin 相关命令已同步（含根 README 与 firmware/README）
