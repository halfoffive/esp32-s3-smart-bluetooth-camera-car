# AGENTS.md — 智能蓝牙摄像头小车 会话备忘

本文件汇总后续 OpenCode 会话容易踩坑的仓库级事实与约定。改动前必读，改动后及时更新。

## 仓库边界

- `firmware/` — ESP32-S3 固件（PlatformIO + Arduino + FreeRTOS 多线程）
- `app/` — Flutter 跨端 App + `app/rust/` 子 crate
- `app/rust/` — `rust_lib`，flutter_rust_bridge 纯函数侧
- `.github/workflows/` — `firmware.yml` / `app.yml`
- `.trae/specs/smart-bt-camera-car/spec.md` — 原始需求与验收场景

## 常用命令速查

### 固件（在 `firmware/` 下执行）

```bash
pio run -e esp32s3                       # 编译
pio run -e esp32s3 -t mergebin           # 合并 bootloader + partitions + firmware
pio run -e esp32s3 -t upload             # 仅上传 firmware 部分
pio device monitor                       # 串口监控，默认 115200
```

合并产物路径：`.pio/build/esp32s3/firmware.bin`，烧录命令：

```bash
esptool.py write_flash 0x0 firmware/.pio/build/esp32s3/firmware.bin
```

CI 使用 `esp32s3-ci` 环境（与 `esp32s3` 配置相同，仅用于区分 CI）。

### App 首次拉取（在 `app/` 下执行）

```bash
flutter create . --platforms=android,linux,windows,macos --org com.smartcar --project-name smart_car_remote
flutter_rust_bridge_codegen generate
flutter pub get
```

`android/`、`linux/`、`windows/`、`macos/` 不在版本控制中，由 `flutter create .` 补齐，不会覆盖 `lib/` 与 `pubspec.yaml`。

### App 运行与构建

```bash
flutter run -d <device-id>
flutter build apk --release
flutter build linux --release
flutter build windows --release
flutter build macos --release
```

### Rust 文档

```bash
cd app/rust
cargo doc --no-deps --open            # 本地浏览
# CI 使用：cargo doc --no-deps --all-features
```

## 工具链陷阱

- `app/rust/` 在运行 `flutter_rust_bridge_codegen generate` 之前不能独立编译，缺少 `frb_generated.rs` 与 Dart 胶水是正常现象。
- 修改 Rust 侧暴露给 Dart 的接口后，必须重新执行 `flutter_rust_bridge_codegen generate`。
- CI 里的 `cargo doc` 使用 `--all-features`，本地生成文档时如需对齐可加上该参数。
- 固件使用自定义分区表 `partitions.csv`，启用 `qio_opi` PSRAM，摄像头模型固定为 `CAMERA_MODEL_ESP32S3_EYE`。
- 本地合并 bin 的输出文件与 CI 产物 `firmware-merged.bin` 同名但来源不同；CI 通过 `cp firmware/.pio/build/esp32s3-ci/firmware.bin firmware-merged.bin` 重命名。

## BLE 关键约定

- 帧格式：`SYNC(0xAA 0x55) | LEN_HI | LEN_LO | CMD | PAYLOAD... | CRC8`
- CRC8：多项式 `0x07`，初始值 `0x00`，覆盖 `LEN_HI` 到 `PAYLOAD` 末尾
- GATT 服务 UUID：`12345678-1234-5678-1234-56789abcdef0`
- 三个特征末位分别为 `...def1`（图像 NOTIFY）、`...def2`（控制 WRITE）、`...def3`（遥测 NOTIFY）
- MTU 协商目标 512 字节

## 用户强制风格

- **Rust 侧**：函数式编程风格，纯函数优先，写适量中文注释。
- **Flutter 侧**：Material Design 3，Riverpod 状态管理。
- **固件**：FreeRTOS 多任务，共享数据用 `volatile` + critical section 保护。
- **提交**：遵循 Conventional Commits。
- **AI 改动后**：必须同步更新 `AGENTS.md`、`README.md`、`CHANGELOG.md`。不要把文档留到下次。

## 文档更新义务

每次完成较显著的改动后，按以下顺序检查并更新：

1. `CHANGELOG.md` — 在 `[Unreleased]` 下按 Added / Changed / Fixed / Removed 归类，附带可验证的变更点。
2. `README.md` — 若涉及硬件接线、构建命令、协议、操作模式，必须同步。
3. `AGENTS.md` — 若引入新的工具链陷阱、命令、边界或风格约定，必须追加或修正。

不要假设“已有 README 就够了”。本仓库是多技术栈混合项目，文档分散，漏一处就可能让下次会话重复踩坑。
