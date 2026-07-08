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
# 合并 bin：pioarduino 平台不支持 `pio run -t mergebin`，须用 esptool.py 直接合并
esptool.py --chip esp32s3 merge-bin -o firmware-merged.bin \
  0x0 .pio/build/esp32s3/bootloader.bin \
  0x8000 .pio/build/esp32s3/partitions.bin \
  0xe000 ~/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin \
  0x10000 .pio/build/esp32s3/firmware.bin
pio run -e esp32s3 -t upload             # 仅上传 firmware 部分
pio device monitor                       # 串口监控，默认 115200
```

合并产物路径：`firmware/firmware-merged.bin`（由 esptool.py merge-bin 生成于 `firmware/` 目录下），烧录命令（在仓库根目录执行）：

```bash
esptool.py write_flash 0x0 firmware/firmware-merged.bin
```

CI 使用 `esp32s3-ci` 环境（与 `esp32s3` 配置相同，仅用于区分 CI）。

### App 首次拉取（在 `app/` 下执行）

```bash
flutter create . --platforms=android,linux,windows,macos --org com.smartcar
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
- 本地与 CI 均使用 `esptool.py --chip esp32s3 merge-bin` 合并四镜像为 `firmware-merged.bin`（pioarduino 社区平台未注册 `pio run -t mergebin` SCons 目标，会报 `Do not know how to make File target 'mergebin'`）。
- `flutter_rust_bridge_codegen` 是 crates.io 上的 Rust crate（`cargo install`），不是 pub.dev 的 Dart 包；`pubspec.yaml` 中不得将其列为 `dev_dependency`，否则 `flutter pub get` 会失败。CI 通过 `cargo install` 安装（见 `.github/workflows/app.yml`）。
- Arduino-ESP32 core 3.x 移除了 v2.x 的 LEDC API（`ledcSetup`/`ledcAttachPin`/`ledcWrite(channel, duty)` 及 `LEDC_CHANNEL_*` 宏）；须使用 `ledcAttach(pin, freq, resolution)` + `ledcWrite(pin, duty)`。注意 `esp_camera` 的 `camera_config_t.ledc_channel` 仍用 ESP-IDF 的 `ledc_channel_t` 枚举（`LEDC_CHANNEL_0` 等），不受影响。
- `motor_task.cpp` 的 `ledcAttach` 自动分配通道从 0 开始，会与 `esp_camera` 的 `LEDC_CHANNEL_0` 冲突（覆盖左轮 PWM）；须用 `ledcAttachChannel(pin, freq, res, channel)` 显式指定通道 1/2 避开摄像头。
- `ble_task.cpp` 的 `BLECharacteristic::getValue()` 在 Arduino-ESP32 core 3.x + NimBLE 下返回 `std::string`（含内嵌 0x00），不可用 `.c_str()` 构造 `std::string`（会在第一个 0x00 处截断控制帧）；须直接 `std::string value = pChar->getValue()`。
- `firmware/platformio.ini` 必须显式锁定 pioarduino 社区平台 URL（`https://github.com/pioarduino/platform-espressif32/releases/download/stable/platform-espressif32.zip`），**不可回退**到 `platform = espressif32`：官方 platform 仍只捆绑 Arduino-ESP32 core 2.0.17，与 `motor_task.cpp` 的 v3.x LEDC API 不兼容，CI 编译会失败。
- `#[frb(sync)]` / `#[frb(opaque)]` 等 frb v2 属性宏不会由 codegen 自动注入到用户源文件，使用该属性的模块（如 `api.rs` / `image.rs`）必须显式 `use flutter_rust_bridge::frb;`，否则 `cargo doc --no-deps --all-features` 报 `cannot find attribute 'frb' in this scope`。
- CI 中 `flutter create .` 生成的 `android/app/build.gradle(.kts)` 默认 `compileSdk = 33`，而 `flutter_reactive_ble` 的 `:reactive_ble_mobile` 依赖 AndroidX 1.7.x 要求 compileSdk ≥ 34。由于 `android/` 不在版本控制中，必须在 `flutter create .` 之后用 `sed` 提升 compileSdk 至 35，并向 `android/build.gradle` 注入 `subprojects` 块强制所有插件模块统一 compileSdk 35（见 `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤）。
- `pio run -t mergebin` 在 pioarduino 社区平台上不可用（SCons 目标未注册）；CI 与本地合并 bin 须改用 `esptool.py --chip esp32s3 merge-bin` 显式合并 bootloader(0x0) + partitions(0x8000) + boot_app0(0xe000) + firmware(0x10000)。
- `app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 不应提交 `.gitkeep` 等任何文件到版本控制；否则 CI checkout 后这些目录非空，`flutter create .` 会将其识别为已有平台目录，可能不重新生成 `android/app/build.gradle` 等原生文件。
- CI 中 Android compileSdk patch 步骤仅在 `build-matrix` job 的 `apk` 条目执行（`if: matrix.flutter_target == 'apk'`）；`cargo-doc` job 不包含此步骤。
- CI 中 Android compileSdk patch 步骤应通过 `working-directory: app` 在 Flutter 项目根目录内执行，自动检测 `android/app/build.gradle` 或 `android/app/build.gradle.kts`（Flutter 3.44.4+ 默认生成 Kotlin DSL），使用相对路径；不要在仓库根目录下使用 `app/android/...` 绝对路径。
- 向 `build.gradle.kts` 注入 `subprojects` 块时必须使用 Kotlin DSL 语法（`compileSdkVersion(35)` + `extensions.findByName` + 强转 `BaseExtension`），Groovy 语法（`compileSdk 35` 无 `=`）在 Kotlin DSL 中会编译失败；CI 须根据 `.kts` 扩展名分支选择语法。
- YAML `run: |` 块中不可使用 heredoc（`<<'EOF'`）注入多行文本：heredoc 内容行若缩进为 0 列会提前终止 YAML literal block scalar，导致整个 workflow 文件无法解析；须改用 `printf '\n...\n' >> file` 单行注入。
- Flutter 3.44.4+ 生成的 `android/app/build.gradle.kts` 中 compileSdk 值为 `flutter.compileSdkVersion`（非字面量数字），sed 正则 `compileSdk = [0-9]*` 会零匹配后插入 35 产生非法 Kotlin；须用 `compileSdk = .*` 全量替换。
- GitHub Actions Windows runner 默认 shell 为 PowerShell，`rm` 是 `Remove-Item` 的别名，不支持 `-rf` 参数。CI 中所有使用 `rm -rf` 等 Unix 专属命令的 `run` 步骤必须显式指定 `shell: bash`，否则 Windows runner 上会报 `A parameter cannot be found that matches parameter name 'rf'`。

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
