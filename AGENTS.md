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
flutter_rust_bridge_codegen integrate   # 接入 Rust 构建系统（Android CMake/NDK 等），缺此步 APK 不含 librust_lib.so
flutter_rust_bridge_codegen generate
flutter pub get
```

### App 桌面端本地开发注意事项

- 桌面端（Windows/Linux/macOS）运行前，需要先在 `app/rust/` 下编译 Rust crate，生成 `rust_lib.dll` / `.so` / `.dylib`：
  ```bash
  cd app/rust
  cargo build --release
  ```
  否则 `main.dart` 中 `RustLib.init()` 会报「Failed to load dynamic library 'rust_lib.dll'」等动态库找不到错误，触发启动错误回退页。
- BLE 包已迁移到 `flutter_blue_plus`，原生支持 Android / iOS / Linux / macOS，Windows 通过 federated 插件 `flutter_blue_plus_winrt` 支持。桌面端运行前同样需要先编译 Rust 动态库（见上条），之后即可扫描/连接/控制。

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
- `flutter_rust_bridge_codegen` 是 crates.io 上的 Rust crate（`cargo install`），不是 pub.dev 的 Dart 包；`pubspec.yaml` 中不得将其列为 `dev_dependency`，否则 `flutter pub get` 会失败。CI 通过 [`cargo-binstall`](https://github.com/cargo-bins/cargo-binstall) 拉预编译二进制安装（见 `.github/workflows/app.yml` 中 `Install cargo tools (binstall)` 步骤），远快于 `cargo install`。
- **CI 安装 cargo bin 一律走 binstall**：`.github/workflows/app.yml` 中 `cargo-expand` 与 `flutter_rust_bridge_codegen` 都用 `cargo binstall -y --force <crate>@<version>`（先 `taiki-e/install-action@v2.9.4` 装 binstall 本体，**必须 pin 到具体 tag**；不要用 `cargo-bins/cargo-binstall@*` —— 后者的 PowerShell 自安装脚本在 `windows-latest` 上会报 `iwr : Object reference not set to an instance of an object` 而失败），秒级完成；不要回退到 `cargo install --locked`（从源码编译数分钟）。若某个 crate 在 crates.io 未发布 binstall 兼容的预编译产物，binstall 会自动 fallback 到 `cargo install`。
- frb v2 codegen 执行时需要 `cargo-expand`（`cargo install cargo-expand`），CI 中应在 `flutter_rust_bridge_codegen generate` 之前预装，避免自动安装的不确定性。
- frb v2 生成的 Dart 代码依赖 `freezed_annotation`（dependencies）和 `freezed`/`build_runner`（dev_dependencies），`pubspec.yaml` 中必须声明，否则 codegen 报 `MissingDep`。
- Dart `pubspec.yaml` 的版本约束**不支持** Cargo 式的 `=` 前缀。精确版本直接写 `x.y.z`（如 `flutter_rust_bridge: 2.12.0`），兼容更新用 `^x.y.z`；写成 `=2.12.0` 会导致 `flutter pub get` 报 `Invalid version constraint`。
- Arduino-ESP32 core 3.x 移除了 v2.x 的 LEDC API（`ledcSetup`/`ledcAttachPin`/`ledcWrite(channel, duty)` 及 `LEDC_CHANNEL_*` 宏）；须使用 `ledcAttach(pin, freq, resolution)` + `ledcWrite(pin, duty)`。注意 `esp_camera` 的 `camera_config_t.ledc_channel` 仍用 ESP-IDF 的 `ledc_channel_t` 枚举（`LEDC_CHANNEL_0` 等），不受影响。
- `firmware/platformio.ini` 必须显式锁定 pioarduino 社区平台 URL（`https://github.com/pioarduino/platform-espressif32/releases/download/stable/platform-espressif32.zip`），**不可回退**到 `platform = espressif32`：官方 platform 仍只捆绑 Arduino-ESP32 core 2.0.17，与 `motor_task.cpp` 的 v3.x LEDC API 不兼容，CI 编译会失败。
- `#[frb(sync)]` / `#[frb(opaque)]` 等 frb v2 属性宏不会由 codegen 自动注入到用户源文件，使用该属性的模块（如 `api.rs` / `image.rs`）必须显式 `use flutter_rust_bridge::frb;`，否则 `cargo doc --no-deps --all-features` 报 `cannot find attribute 'frb' in this scope`。
- CI 中 `flutter create .` 生成的 `android/app/build.gradle` 默认 `compileSdk = 33`，而 `flutter_blue_plus` 的 `:flutter_blue_plus_android` 依赖 AndroidX 1.7.x 要求 compileSdk ≥ 34。由于 `android/` 不在版本控制中，必须在 `flutter create .` 之后用 `sed` 提升 compileSdk 至 35，并向 `android/build.gradle` 注入 `subprojects` 块强制所有插件模块统一 compileSdk 35（见 `.github/workflows/app.yml` 的 "Patch Android compileSdk" 步骤，仅在 build-matrix 的 apk 条目执行，见 `if: matrix.flutter_target == 'apk'`）。
- `app/android/`、`app/linux/`、`app/macos/`、`app/windows/` 不应提交 `.gitkeep` 等任何文件到版本控制；否则 CI checkout 后这些目录非空，`flutter create .` 会将其识别为已有平台目录，可能不重新生成 `android/app/build.gradle` 等原生文件。
- CI 中 Android compileSdk patch 应使用 `if: matrix.flutter_target == 'apk'` 限制，避免在 `cargo-doc` job 与桌面平台（linux/windows/macos）矩阵条目运行。Patch 步骤须兼容 Flutter 3.29+ 的 `build.gradle.kts`（同时检查 `build.gradle` 与 `build.gradle.kts`），并加 `shell: bash`。
- 跨 FFI 的 Rust 函数不得用 `assert`/`panic` 校验参数，应返回 `Result<T, String>`，否则 panic 会终止整个 Flutter 进程。
- `#[frb(named_args)]` **不是** frb v2 的合法属性（frb v1 旧属性，v2 已移除）。frb v2 **默认就生成 Dart 命名参数**，反向切换位置参数用 `#[frb(positional)]`。使用 `named_args` 会导致 `flutter_rust_bridge_codegen generate` panic，所有平台 CI 失败。
- `esp_camera` 的 `ledc_channel` 不得用 `LEDC_CHANNEL_0`/`1`（会被 `ledcAttach` 自动分配给电机），须用 `LEDC_CHANNEL_2` 避免通道冲突。
- 启用 `-DUSE_NIMBLE` 时，NimBLE 栈的 `BLECharacteristic` 没有 `getSubscribedCount()` 成员；需要订阅计数时应通过 `onSubscribe` 回调自行维护，或直接在 `ble_task.cpp` 中调用 `notify()`（无订阅时 NimBLE 内部跳过）。
- `firmware/platformio.ini` 中 `espressif/esp32-camera` 须使用实际存在的版本；PlatformIO Library Registry 中该库最新只到 `2.0.4`，而 Arduino-ESP32 core 3.x 需要更新版本，因此应直接使用 GitHub 源 `https://github.com/espressif/esp32-camera.git#v2.1.7`，写 `^2.4.0` 或 `^2.1.7` 会报 `UnknownPackageError`。
- `concurrency.cancel-in-progress` 对 tag 推送应设为不取消（`${{ !startsWith(github.ref, 'refs/tags/') }}`），避免误取消 release。
- CI 中 Android compileSdk patch 必须按 Gradle DSL 区分语法：Kotlin DSL（`build.gradle.kts`）使用属性赋值 `compileSdk = 35`（**带 `=`**），Groovy DSL（`build.gradle`）使用函数调用 `compileSdk 35`（**不带 `=`**）。原单条 sed 同时套用两种 DSL 会把 `.gradle.kts` 改成非法的 `compileSdk 35`，Gradle 报 `Unexpected tokens (use ';' to separate expressions on same line)`。
- CI 中向根 `android/build.gradle(.kts)` 注入 `subprojects` 块时，必须在**已有的第一个 `subprojects {` 块内**插入 `afterEvaluate { ... }`，而不可在文件末尾追加新的 `subprojects { ... }` 块，否则 Gradle 报 `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`。Kotlin DSL 注入块中通过反射调用 `setCompileSdk`/`setCompileSdkVersion(Int)` 来避免 AGP/Gradle 类型差异导致的 `Unresolved reference 'compileSdk'`。
- `KeyEventResult` 定义在 `package:flutter/src/widgets/focus_manager.dart`，由 `package:flutter/widgets.dart` 再导出（**不在** `services.dart`）。`keyboard_controller.dart` 用 `show` 子句限定 `widgets.dart` 导入时，必须显式列出 `KeyEventResult`（`import 'package:flutter/widgets.dart' show FocusNode, KeyEventResult;`），否则 Linux/桌面构建报 `Type 'KeyEventResult' not found`。`KeyEvent`/`KeyDownEvent`/`KeyUpEvent`/`LogicalKeyboardKey` 才来自 `services.dart`。
- GitHub Actions 的 `actions/*` 系列须使用 Node 24 原生版本，避免 `Node.js 20 is deprecated` 警告：当前应使用 `actions/checkout@v7`、`actions/cache@v6`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`actions/setup-python@v6`。`@v5` 仍基于 Node 20 运行时，会被 runner 强制迁移到 Node 24 并产生弃用警告；`subosito/flutter-action@v2` 已兼容 Node 24，无需升级。
- frb v2 属性宏（`#[frb(sync)]` / `#[frb(opaque)]` 等）内部会展开 `#[cfg(frb_expand)]`，rustc 1.80+ 的 check-cfg 机制会将其判为 `unexpected_cfgs`，在 `-D warnings` 下导致 `cargo clippy` 失败。须在 `app/rust/Cargo.toml` 的 `[lints.rust]` 段声明该 cfg 为已知：`unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }`（deny 保留对其它未知 cfg 的拒绝，仅放行 `frb_expand`）。不得用散布的 `#[allow(unexpected_cfgs)]` 替代。
- BLE 协议新增 `CMD_SET_PARAMS=0x04` / `CMD_SET_WIFI=0x05` 复用控制 WRITE 特征（`...def2`），不新增 GATT 特征；`ble_task.cpp` `ControlCharacteristicCallbacks::onWrite` 中 `proto_validate` 通过后按 `buf[4]`（CMD 字节）分发，未知 CMD 直接丢弃。
- 固件 PID/物理参数从 `config.h` 编译期宏改为运行时 `static volatile` 变量 + setter（`motor_set_pid` / `motor_set_ramp` / `motor_set_physical` / `speed_sensor_set_physical`），NVS 持久化用 Arduino-ESP32 内置 `Preferences.h`（`params_store.{h,cpp}` / `wifi_config.{h,cpp}`）。首次启动无 NVS 时回退 `config.h` 宏默认，行为与原版一致；`motor_init` / `speed_sensor_init` 在初始化时从 NVS 加载。
- 修改 Rust 侧暴露给 Dart 的接口（如新增 `encode_set_params` / `encode_set_wifi`）后必须重跑 `flutter_rust_bridge_codegen generate`；CI 由 `app.yml` 的「Generate flutter_rust_bridge bindings」步骤自动生成。本地若无 `flutter` 命令，仅改源代码后由 CI 兜底（不要手改 `frb_generated.dart` / `frb_generated.rs`）。**本地开发时**：`app/lib/src/rust/` 已在 `.gitignore`，Dart 绑定不入版本库；Rust 新增函数后若忘记跑 codegen，`ble_controller.dart` 等调用点 `undefined_function`，**整个 Dart 编译失败会让 hot reload 静默不生效**，UI 表现为「按钮点了不换页 / tab 切换无反应」等**假 UI bug**，容易被误认为 widget/listener 问题。表现为运行时无反应先看 LSP 是否有 `undefined_function` 或 codegen 产物是否过期。
- **frb v2 必须显式初始化**：`app/lib/main.dart` 必须在 `runApp` 之前调用 `await RustLib.init();`（由生成的 `app/lib/src/rust/frb_generated.dart` 提供），否则 Rust 动态库未加载，首次调用 `encodeControl` / `encodeSetParams` / `encodeSetWifi` 等函数时会抛「RustLib not initialized」。这不会直接让启动页空白（`BleController` 构造是干净的），但会让「点击扫描/下发参数」后立即崩溃，表象仍像 UI 问题。
- **异步初始化异常保护**：`main()` 中 `await container.read(themeModeProvider.notifier).load()` 等插件初始化步骤必须用 try/catch 保护，否则 `SharedPreferences`（或其它插件）初始化失败会直接阻止 `runApp`，用户看到的就是**空白页**。初始化失败后仍应调用 `runApp` 并显示错误回退界面。
- **全局构建错误回退**：生产环境务必设置 `ErrorWidget.builder`（或在 `MaterialApp.builder` 中兜底），将未捕获的 widget 构建异常渲染成可见的 Material 错误页。Flutter 在 release 模式下遇到未处理构建错误会显示空白屏，debug 模式才显示红屏；没有回退则用户/开发者都无从定位。
- `SetParamsPayload` 在 Rust 与固件两端均须 `#pragma pack(1)` / 21 字节小端对齐，二进制布局必须严格一致（字段顺序：`kp f32` + `ki f32` + `kd f32` + `ramp_ms u32` + `wheel_dia_mm u16` + `wheel_base_mm u16` + `enc_slots u8` = 4+4+4+4+2+2+1 = 21 字节）。固件端用 `PROTO_STATIC_ASSERT(sizeof(struct SetParamsPayload) == 21, ...)` 校验；Rust 端 `#[repr(C, packed)]` 派生 + 编码后 `assert_eq!(bytes.len(), 21)` 单测。
- HarmonyOS HAP 构建**已弃用**（自 2026-07）：`.github/workflows/app.yml` 不再包含 `build-hap` job。原因：`gitcode.com/CPF-Flutter/flutter_flutter` fork 工具链链路（version 占位 / OpenHarmony SDK 结构校验 / hvigor 包名 / ohpm registry / rustup target 缺失）不稳定，且鸿蒙 SDK 下载动辄数百 MB 拖慢流水线；即便设 `workflow_dispatch` 手动触发也基本无实用价值。如需 HAP，请本地按 `.trae/specs/fix-drive-blank-and-add-hap-ci/` 历史 spec 手动搭链。
- **CI 桌面产物必须内嵌 rust_lib**：Flutter 桌面（Windows/Linux/macOS）`flutter build` 不感知外部 Cargo crate，默认不复制 `rust_lib.dll`/`.so`/`.dylib` 到 release bundle，用户直接跑二进制会报 `Failed to load dynamic library 'rust_lib.dll' ... (error code: 126)` 并进入 `_InitErrorScreen`。`app.yml` 的 `build-matrix` job 在 `flutter build <desktop>` 之后必须显式 `cargo build --release --target <rust_target>` + 拷贝到 release bundle：Linux `librust_lib.so` → `bundle/lib/`；Windows `rust_lib.dll` → `runner/Release/`（可执行文件同目录）；macOS `librust_lib.dylib` → `<app>.app/Contents/Frameworks/`。
- **Android APK 必须先 `flutter_rust_bridge_codegen integrate`**：`app/android/` 不在版本控制中，每次 CI 由 `flutter create .` 重新生成，原生 `android/` 目录不含 Rust 编译配置。必须在 `flutter create .` 之后、`flutter build apk` 之前执行 `flutter_rust_bridge_codegen integrate`（`app.yml` 的「Integrate flutter_rust_bridge (Android)」步骤，`if: matrix.flutter_target == 'apk'`），向 `android/app/build.gradle` 注入 `externalNativeBuild` CMake + NDK 配置，使 Gradle 自动编译 `rust/` crate 并打包 `lib/<abi>/librust_lib.so` 进 APK。缺失该步，APK 不含 `librust_lib.so`，运行时 `dlopen failed: library "librust_lib.so" not found`，App 进入 `_InitErrorScreen`。iOS 由 Xcode 处理，不在 CI 范围内。
- Riverpod 2 中 `ref.listen(provider, callback)` 写在 `ConsumerStatefulWidget.build` 顶部虽合法（Riverpod 自动去重重复注册），但推荐改用 `initState` + `ref.listenManual(provider, callback)` 注册副作用型 listener（如弹 SnackBar），避免在 widget build 期间注册 listener 的潜在副作用（build 可能被框架多次调用）。
- **导航流程**（自 2026-07 重构）：App 不再用底部 `NavigationBar` 多 tab，改为 `_AppRouter`（`main.dart`）按 `bleControllerProvider.select((s) => s.status)` 状态驱动路由：`status == connected` -> `ControlScreen`（横屏控制页），其余 -> `DeviceConnectionScreen`（设备连接页，应用入口）。设置与「断开连接」藏入 AppBar `PopupMenuButton`（`/settings` 命名路由 `pushNamed`）。`ControlScreen.initState` 用 `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` 锁横屏，`dispose` 恢复 `DeviceOrientation.values`（设备连接/设置页允许竖屏）。`ControlPanel` 仅单摇杆 + 紧急停车，不再有体感/键盘模式切换（`ControlMode` 枚举已移除）。
- `SystemChrome.setPreferredOrientations` 是全局副作用，离开横屏页**必须**在 `dispose` 恢复全方向，否则设备连接/设置页会被锁成横屏导致表单布局异常。

## 已知限制

- **桌面端 BLE 现已可用**：BLE 包已迁移到 `flutter_blue_plus`，原生支持 Android / iOS / Linux / macOS，Windows 通过 federated 插件 `flutter_blue_plus_winrt` 支持。桌面端运行前仍需先编译 Rust 动态库（见上条），之后即可扫描/连接/控制。
- **桌面端需手动编译 Rust 动态库**：桌面端运行前需要先在 `app/rust/` 下执行 `cargo build --release`，生成 `rust_lib.dll`（Windows）/ `.so`（Linux）/ `.dylib`（macOS）。否则 `main.dart` 的 `RustLib.init()` 会报「Failed to load dynamic library ...」，进入启动错误回退页。Android / iOS 构建由 Gradle / Xcode 自动处理 Rust 编译，不需要此手动步骤。

## BLE 关键约定

- 帧格式：`SYNC(0xAA 0x55) | LEN_HI | LEN_LO | CMD | PAYLOAD... | CRC8`
- CRC8：多项式 `0x07`，初始值 `0x00`，覆盖 `LEN_HI` 到 `PAYLOAD` 末尾
- GATT 服务 UUID：`12345678-1234-5678-1234-56789abcdef0`
- 三个特征末位分别为 `...def1`（图像 NOTIFY）、`...def2`（控制 WRITE）、`...def3`（遥测 NOTIFY）
- MTU 协商目标 512 字节
- `CMD_SET_PARAMS=0x04` 载荷 = `SetParamsPayload`（21 字节，小端，与固件 `#pragma pack(1)` 一致）：
  `kp(f32, 4) | ki(f32, 4) | kd(f32, 4) | ramp_ms(u32, 4) | wheel_dia_mm(u16, 2) | wheel_base_mm(u16, 2) | enc_slots(u8, 1)`，App→固件，复用控制 WRITE 特征 `...def2`。
- `CMD_SET_WIFI=0x05` 载荷 = 长度前缀字符串对（变长）：
  `ssid_len(u8, 1) | ssid(ssid_len 字节) | pass_len(u8, 1) | pass(pass_len 字节)`，SSID ≤ 32 字节、密码 ≤ 64 字节；App→固件，复用控制 WRITE 特征 `...def2`；设备收到后写 NVS，当前固件不主动连 WiFi（预留扩展）。

## 用户强制风格

- **Rust 侧**：函数式编程风格，纯函数优先，写适量中文注释。
- **Flutter 侧**：Material Design 3 **默认配色**（`useMaterial3: true`，不设 `colorSchemeSeed` / 自定义种子色），结构色一律取自 `Theme.of(context).colorScheme`；**深浅色默认跟随系统**（`ThemeMode.system`），用户可在设置页切换 系统/浅色/深色（持久化到 `shared_preferences` 键 `car_theme_mode`）；状态语义色（正常/警告/危险）使用 Material 默认色（`Colors.green`/`Colors.amber`/`colorScheme.error`），由 `HudStatus` 承载，不随主题变化。Riverpod 状态管理。
  - **M3 原生组件清单**（仅使用以下组件，不引入 `cupertino_icons` 之外的第三方 UI 包）：`FilledButton` / `FilledTonalButton` / `OutlinedButton` / `TextButton` 四档按钮、`PopupMenuButton` 菜单、`SegmentedButton` 分段选择、M3 默认 `TextField`/`TextFormField` outline（**不自定义** `InputDecoration.border` / `fillColor` / `filled`，数值输入用 `_numField` 走默认 outline）。导航由 `_AppRouter` 状态驱动（非底部 `NavigationBar`），控制页布局用 `Row`（横屏左摄像头右摇杆）；各子页须各自包 `Scaffold`（结构对称），避免裸 `Column` 在 loose 约束下 sizing 异常导致空白页。
  - **默认字体约定**：不引入第三方字体包（`pubspec.yaml` 无 `fonts:` 段，亦不引入 `google_fonts`）；等宽数值走系统 `'monospace'` fallback（`AppTheme.mono()` 设 `fontFamily: 'monospace'` + `fontFamilyFallback: ['monospace']`）；数值/标签文字使用 M3 `textTheme` 角色（`labelSmall` / `titleMedium` 等），不另设 `TextStyle` 颜色与字号硬编码。
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
