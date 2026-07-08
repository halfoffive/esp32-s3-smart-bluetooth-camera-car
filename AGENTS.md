# AGENTS.md — 智能蓝牙摄像头小车 会话备忘

本文件汇总后续 OpenCode 会话容易踩坑的仓库级事实与约定。改动前必读，改动后及时更新。

## 仓库边界

- `firmware/` — ESP32-S3 固件（PlatformIO + Arduino + FreeRTOS 多线程）
- `app/` — Flutter 跨端 App + `app/rust/` 子 crate
- `app/rust/` — `rust_lib`，flutter_rust_bridge 纯函数侧
- `.github/workflows/` — `firmware.yml` / `app.yml`
- `.trae/specs/` — 规格文档目录（smart-bt-camera-car 原始需求；fix-ci-build-failures / fix-ci-flutter-platform CI 修复增量）

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
- 本地与 CI 均使用 `esptool.py --chip esp32s3 merge-bin` 合并四镜像（bootloader(0x0) + partitions(0x8000) + boot_app0(0xe000) + firmware(0x10000)）为 `firmware-merged.bin`（pioarduino 社区平台未注册 `pio run -t mergebin` SCons 目标，会报 `Do not know how to make File target 'mergebin'`）。
- `flutter_rust_bridge_codegen` 是 crates.io 上的 Rust crate（`cargo install`），不是 pub.dev 的 Dart 包；`pubspec.yaml` 中不得将其列为 `dev_dependency`，否则 `flutter pub get` 会失败。CI 通过 `cargo install` 安装（见 `.github/workflows/app.yml`）。
- frb v2 codegen 执行时需要 `cargo-expand`（`cargo install cargo-expand`），CI 中应在 `flutter_rust_bridge_codegen generate` 之前预装，避免自动安装的不确定性。
- frb v2 生成的 Dart 代码依赖 `freezed_annotation`（dependencies）和 `freezed`/`build_runner`（dev_dependencies），`pubspec.yaml` 中必须声明，否则 codegen 报 `MissingDep`。
- Dart `pubspec.yaml` 的版本约束**不支持** Cargo 式的 `=` 前缀。精确版本直接写 `x.y.z`（如 `flutter_rust_bridge: 2.12.0`），兼容更新用 `^x.y.z`；写成 `=2.12.0` 会导致 `flutter pub get` 报 `Invalid version constraint`。
- Arduino-ESP32 core 3.x 移除了 v2.x 的 LEDC API（`ledcSetup`/`ledcAttachPin`/`ledcWrite(channel, duty)` 及 `LEDC_CHANNEL_*` 宏）；须使用 `ledcAttach(pin, freq, resolution)` + `ledcWrite(pin, duty)`。注意 `esp_camera` 的 `camera_config_t.ledc_channel` 仍用 ESP-IDF 的 `ledc_channel_t` 枚举（`LEDC_CHANNEL_0` 等），不受影响。
- `firmware/platformio.ini` 必须显式锁定 pioarduino 社区平台 URL（`https://github.com/pioarduino/platform-espressif32/releases/download/stable/platform-espressif32.zip`），**不可回退**到 `platform = espressif32`：官方 platform 仍只捆绑 Arduino-ESP32 core 2.0.17，与 `motor_task.cpp` 的 v3.x LEDC API 不兼容，CI 编译会失败。
- `#[frb(sync)]` / `#[frb(opaque)]` 等 frb v2 属性宏不会由 codegen 自动注入到用户源文件，使用该属性的模块（如 `api.rs` / `image.rs`）必须显式 `use flutter_rust_bridge::frb;`，否则 `cargo doc --no-deps --all-features` 报 `cannot find attribute 'frb' in this scope`。
- CI 中 `flutter create .` 生成的 `android/app/build.gradle` 默认 `compileSdk = 33`，而 `flutter_reactive_ble` 的 `:reactive_ble_mobile` 依赖 AndroidX 1.7.x 要求 compileSdk ≥ 34。由于 `android/` 不在版本控制中，必须在 `flutter create .` 之后用 `sed` 提升 compileSdk 至 35，并向 `android/build.gradle` 注入 `subprojects` 块强制所有插件模块统一 compileSdk 35（见 `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤，仅在 build-matrix 的 apk 条目执行，见 `if: matrix.flutter_target == 'apk'`）。
- `app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 不应提交 `.gitkeep` 等任何文件到版本控制；否则 CI checkout 后这些目录非空，`flutter create .` 会将其识别为已有平台目录，可能不重新生成 `android/app/build.gradle` 等原生文件。
- CI 中 Android compileSdk patch 应使用 `if: matrix.flutter_target == 'apk'` 限制，避免在 `cargo-doc` job 与桌面平台（linux/windows/macos）矩阵条目运行。Patch 步骤须兼容 Flutter 3.29+ 的 `build.gradle.kts`（同时检查 `build.gradle` 与 `build.gradle.kts`），并加 `shell: bash`。
- 跨 FFI 的 Rust 函数不得用 `assert`/`panic` 校验参数，应返回 `Result<T, String>`，否则 panic 会终止整个 Flutter 进程。
- `#[frb(named_args)]` **不是** frb v2 的合法属性（frb v1 旧属性，v2 已移除）。frb v2 **默认就生成 Dart 命名参数**，反向切换位置参数用 `#[frb(positional)]`。使用 `named_args` 会导致 `flutter_rust_bridge_codegen generate` panic，所有平台 CI 失败。
- `esp_camera` 的 `ledc_channel` 不得用 `LEDC_CHANNEL_0`/`1`（会被 `ledcAttach` 自动分配给电机），须用 `LEDC_CHANNEL_2` 避免通道冲突。
- 启用 `-DUSE_NIMBLE` 时，NimBLE 栈的 `BLECharacteristic` 没有 `getSubscribedCount()` 成员；需要订阅计数时应通过 `onSubscribe` 回调自行维护，或直接在 `ble_task.cpp` 中调用 `notify()`（无订阅时 NimBLE 内部跳过）。
- `firmware/platformio.ini` 中 `espressif/esp32-camera` 须使用实际存在的版本；PlatformIO Library Registry 中该库最新只到 `2.0.4`，而 Arduino-ESP32 core 3.x 需要更新版本，因此应直接使用 GitHub 源 `https://github.com/espressif/esp32-camera.git#v2.1.7`，写 `^2.4.0` 或 `^2.1.7` 会报 `UnknownPackageError`。
- `concurrency.cancel-in-progress` 对 tag 推送应设为不取消（`${{ !startsWith(github.ref, 'refs/tags/') }}`），避免误取消 release。
- CI 中 Android compileSdk patch 必须按 Gradle DSL 区分语法：Kotlin DSL（`build.gradle.kts`）使用属性赋值 `compileSdk = 35`（**带 `=`**），Groovy DSL（`build.gradle`）使用函数调用 `compileSdk 35`（**不带 `=`**）。原单条 sed 同时套用两种 DSL 会把 `.gradle.kts` 改成非法的 `compileSdk 35`，Gradle 报 `Unexpected tokens (use ';' to separate expressions on same line)`。`subprojects` 注入块同理须按 DSL 区分；Kotlin DSL 注入块中应使用 `com.android.build.api.dsl.CommonExtension<*, *, *, *, *>`，已弃用的 `com.android.build.gradle.BaseExtension` 会导致 `Unresolved reference 'compileSdk'`。
- `KeyEventResult` 定义在 `package:flutter/src/widgets/focus_manager.dart`，由 `package:flutter/widgets.dart` 再导出（**不在** `services.dart`）。`keyboard_controller.dart` 用 `show` 子句限定 `widgets.dart` 导入时，必须显式列出 `KeyEventResult`（`import 'package:flutter/widgets.dart' show FocusNode, KeyEventResult;`），否则 Linux/桌面构建报 `Type 'KeyEventResult' not found`。`KeyEvent`/`KeyDownEvent`/`KeyUpEvent`/`LogicalKeyboardKey` 才来自 `services.dart`。
- GitHub Actions 的 `actions/*` 系列须使用 Node 24 原生版本，避免 `Node.js 20 is deprecated` 警告：当前应使用 `actions/checkout@v7`、`actions/cache@v6`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`actions/setup-python@v6`。`@v5` 仍基于 Node 20 运行时，会被 runner 强制迁移到 Node 24 并产生弃用警告；`subosito/flutter-action@v2` 已兼容 Node 24，无需升级。
- frb v2 属性宏（`#[frb(sync)]` / `#[frb(opaque)]` 等）内部会展开 `#[cfg(frb_expand)]`，rustc 1.80+ 的 check-cfg 机制会将其判为 `unexpected_cfgs`，在 `-D warnings` 下导致 `cargo clippy` 失败。须在 `app/rust/Cargo.toml` 的 `[lints.rust]` 段声明该 cfg 为已知：`unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }`（deny 保留对其它未知 cfg 的拒绝，仅放行 `frb_expand`）。不得用散布的 `#[allow(unexpected_cfgs)]` 替代。

## BLE 关键约定

- 帧格式：`SYNC(0xAA 0x55) | LEN_HI | LEN_LO | CMD | PAYLOAD... | CRC8`
- CRC8：多项式 `0x07`，初始值 `0x00`，覆盖 `LEN_HI` 到 `PAYLOAD` 末尾
- GATT 服务 UUID：`12345678-1234-5678-1234-56789abcdef0`
- 三个特征末位分别为 `...def1`（图像 NOTIFY）、`...def2`（控制 WRITE）、`...def3`（遥测 NOTIFY）
- MTU 协商目标 512 字节

## 用户强制风格

- **Rust 侧**：函数式编程风格，纯函数优先，写适量中文注释。
- **Flutter 侧**：Material Design 3 **默认配色**（`useMaterial3: true`，不设 `colorSchemeSeed` / 自定义种子色），结构色一律取自 `Theme.of(context).colorScheme`；**深浅色默认跟随系统**（`ThemeMode.system`），用户可在设置页切换 系统/浅色/深色（持久化到 `shared_preferences` 键 `car_theme_mode`）；状态语义色（正常/警告/危险）使用 Material 默认色（`Colors.green`/`Colors.amber`/`colorScheme.error`），由 `HudStatus` 承载，不随主题变化。Riverpod 状态管理。
- **固件**：FreeRTOS 多任务，共享数据用 `volatile` + critical section 保护。
- **提交**：遵循 Conventional Commits。
- **AI 改动后**：必须同步更新 `AGENTS.md`、`README.md`、`CHANGELOG.md`。不要把文档留到下次。

## 提交纪律

- **clippy 零警告门槛**：提交前 `cargo clippy --all-features -- -D warnings` 必须通过（退出码 0）；CI 中 `app.yml` 的 `cargo-doc` 与 `build-matrix` job 均已设此门槛，存在警告即构建失败。跨 FFI 的 Rust 函数不得用 `assert`/`panic` 校验参数。
- **AI 分批提交**：AI 助手完成多关注点改动后 SHALL 按逻辑关注点拆分为多个独立 commit（如 CI 修复 / 主题改造 / clippy 门槛 / 文档各自独立），而非单一大 commit；每个 commit 遵循 Conventional Commits 且独立可编译。不要把无关变更塞进同一 commit。

## 文档更新义务

每次完成较显著的改动后，按以下顺序检查并更新：

1. `CHANGELOG.md` — 在 `[Unreleased]` 下按 Added / Changed / Fixed / Removed 归类，附带可验证的变更点。
2. `README.md` — 若涉及硬件接线、构建命令、协议、操作模式，必须同步。
3. `AGENTS.md` — 若引入新的工具链陷阱、命令、边界或风格约定，必须追加或修正。

不要假设“已有 README 就够了”。本仓库是多技术栈混合项目，文档分散，漏一处就可能让下次会话重复踩坑。
