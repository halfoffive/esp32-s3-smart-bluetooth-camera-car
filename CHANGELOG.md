# Changelog

本仓库所有重要变更均记录于此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Fixed
- fix(ci/app): 修复 code review 指出的 CI 稳定性问题 —— (1) `cargo-bins/cargo-binstall` action 从 `@main` pin 到 `@v1.9.0`，消除追随分支带来的供应链风险；(2) 为 Linux/Windows/macOS 三个 `Bundle rust_lib into <platform>` 步骤统一加 `set -e` + Rust cdylib 产物存在性预检 + Flutter release bundle 目标目录存在性预检，未命中时打印 `find` 辅助定位日志再 `exit 1`，避免未来 Flutter 目录漂移时报错含糊。

### Removed
- ci(app): 全面弃用 HarmonyOS HAP 构建 —— `.github/workflows/app.yml` 移除 `build-hap` job（工具链不稳定、下载耗时，且已长期设为 `workflow_dispatch` 手动触发从未成功过），`release` job 的 `needs` 不再列 `build-hap`，`files` glob 移除 `artifacts/app-hap/*`。如需 HAP 请本地手动构建。

### Fixed
- fix(ci/app): 修复桌面（Windows/Linux/macOS）release 产物启动即报 `Failed to load dynamic library 'rust_lib.dll'`（error code 126）—— `app.yml` 的 `build-matrix` job 在 `flutter build <desktop>` 之后新增「Bundle rust_lib into <platform> desktop」步骤，用 `cargo build --release --target <rust_target>` 编译 Rust cdylib 并拷贝到 Flutter release bundle：Linux → `build/linux/x64/release/bundle/lib/librust_lib.so`，Windows → `build/windows/x64/runner/Release/rust_lib.dll`（可执行文件同目录），macOS → `<app>.app/Contents/Frameworks/librust_lib.dylib`。Flutter 桌面打包不感知外部 Cargo crate，默认不复制 Rust 动态库，是本次启动失败根因。

### Changed
- ci(app): `cargo-expand` 与 `flutter_rust_bridge_codegen` 改用 [`cargo-binstall`](https://github.com/cargo-bins/cargo-binstall) 拉预编译二进制，取代 `cargo install --version ... --locked`（后者需要现场编译，每次 CI 数分钟）。所有 job（`cargo-doc`/`build-matrix`）统一走 `cargo-bins/cargo-binstall@main` action + `cargo binstall -y --force <crate>@<version>`，安装从数分钟降至秒级。

### Changed
- feat(app): BLE 包从 `flutter_reactive_ble` 迁移到 `flutter_blue_plus` —— 重写 `app/lib/ble/ble_controller.dart` 使用 `FlutterBluePlus.startScan` / `BluetoothDevice.connect` / `discoverServices` / `setNotifyValue` / `characteristic.write`，保留 5 状态 `ConnectionStatus` 机、3 次指数退避重连、MTU=512（Android 显式请求，桌面自动协商）；`app/lib/ui/devices_screen.dart` 改用 `ScanResult` / `BluetoothDevice` 类型；`app/pubspec.yaml` 替换依赖；`.github/workflows/app.yml` 更新 compileSdk patch 注释。Rust 协议层、frb 绑定、GATT UUID 与帧格式均不变。

### Fixed
- fix(app): 修复 App 启动空白页 —— `main.dart` 现在显式调用 `await RustLib.init()`（flutter_rust_bridge v2 要求），并在初始化失败时显示回退界面；同时用 try/catch 保护 `themeModeProvider.load()`，避免 `SharedPreferences` 等插件初始化异常阻止 `runApp` 导致空白屏。另设置 `ErrorWidget.builder`，将未捕获的 widget 构建异常渲染为 Material 错误页，而非 release 模式空白 / debug 模式红屏。

### Changed
- docs(readme): 更新根 `README.md` 的「App UI 结构」与「App 操作模式」章节，移除旧版底部 `NavigationBar` 三 tab / `IndexedStack` 描述，改为与代码一致的状态驱动 `_AppRouter`（`connected -> ControlScreen`，其余 -> `DeviceConnectionScreen`），并说明设置页通过 AppBar `PopupMenuButton` 进入。
- feat(app): 重构 App 导航为状态驱动 -- 移除 HomeScreen 的底部 NavigationBar 三 tab（驾驶/设备/设置）与 IndexedStack，改为 _AppRouter 按 bleControllerProvider.status 切换：未连接 -> DeviceConnectionScreen（设备连接页，应用入口），已连接 -> ControlScreen（横屏控制页）。设置与「断开连接」藏入 AppBar PopupMenuButton，不再占底部导航。符合「打开应用进入设备连接，连接设备再进入控制页面，设置藏在菜单栏」的交互诉求。
- feat(app): 控制页改为横屏布局 -- 新增 control_screen.dart，Row 左侧摄像头（含 HUD）+ 遥测条、右侧 300px 固定宽单摇杆列；initState 锁定 landscapeLeft/landscapeRight，dispose 恢复全方向（设备连接/设置页允许竖屏）。适配横屏操控场景。
- feat(app): 操控面板简化为单摇杆 -- control_panel.dart 移除体感（TiltController）/ 键盘（KeyboardController）模式切换 SegmentedButton 与 ControlMode 枚举，仅保留虚拟摇杆 + 紧急停车按钮。符合「使用单电子摇杆控制」诉求；摇杆节流 / 释放保留方向等逻辑不变。
- refactor(app): devices_screen.dart 类名 DevicesScreen -> DeviceConnectionScreen，AppBar 标题改「设备连接」并加 PopupMenuButton（设置入口）；原底部 tab 导航已移除。

### Removed
- refactor(app): control_panel.dart 不再引用 input/tilt_controller.dart / input/keyboard_controller.dart（文件保留待后续 spec 扩展）；main.dart 移除 HomeScreen / _DriveTab / IndexedStack / NavigationBar 相关代码。

### Added
- ci(app): `app.yml` 新增实验性 `build-hap` job —— 使用 `gitcode.com/CPF-Flutter/flutter_flutter` SDK fork 构建 HarmonyOS unsigned HAP 包：JDK 17 + OpenHarmony SDK + hvigor/ohpm（npm `@ohos:registry`）+ `flutter create --platforms=ohos` + `flutter build hap --release`；用 `continue-on-error: true` 标注，失败不阻塞 release；release job 的 `needs` 加 `build-hap`，`files` 列表加 `artifacts/app-hap/*`。
- feat(app): `BleController` 在构造与关键状态转移处（startScan / connect / _onConnectionStateChange / _onConnected / _onDisconnected / stream onError）补 `debugPrint` 诊断日志，便于 `flutter run` 定位驾驶 tab 空白根因；release 构建由 Flutter 框架自动剥离，无副作用。
- feat(app): 主题模式设置 —— 设置页新增「外观」段，`SegmentedButton` 切换 系统/浅色/深色，选择持久化到 `shared_preferences`（键 `car_theme_mode`），默认跟随系统（`ThemeMode.system`）。新增 `theme_mode_controller.dart`（Riverpod `StateNotifier<ThemeMode>`）。
- ci(app): `app.yml` 新增 `cargo clippy --all-features -- -D warnings` 门槛（`cargo-doc` 与 `build-matrix` job 均在 codegen 之后、build/doc 之前执行），clippy 警告即构建失败。
- feat(app): `HomeScreen` 改 `Scaffold` + `NavigationBar` 三 tab（驾驶 / 设备 / 设置）+ `IndexedStack` 保活子页状态；新增 `app/lib/ui/devices_screen.dart`，按 `BleState.status` 分支提供扫描 / 列表点选连接 / 断开按钮。
- feat(app): 设置页新增「WiFi 配置」段（SSID + 密码 `TextFormField` + 「下发到设备」`FilledButton`），BLE 已连接时调 `BleController.sendWifiConfig` 下发 `CMD_SET_WIFI=0x05`，SnackBar 提示「WiFi 配置已下发到设备」；未连接时按钮禁用并提示「请先连接设备」。
- feat(app): PID / 物理参数「保存」按钮支持设备下发 —— BLE 已连接时调 `BleController.sendParams` 下发 `CMD_SET_PARAMS=0x04`（21 字节 `SetParamsPayload`），SnackBar 提示「已保存到设备」；未连接时禁用并提示「请先连接设备」。移除原顶部「仅本地保存」说明卡片。
- feat(app/rust): `ble.rs` 新增 `CMD_SET_PARAMS=0x04` / `CMD_SET_WIFI=0x05` 常量 + `SetParamsPayload` 结构；`control.rs` 新增 `encode_set_params` / `encode_set_wifi` 编码函数 + 单测（断言 `SetParamsPayload` 编码后长度为 21 字节）。
- feat(firmware): 新增 `wifi_config.{h,cpp}`（NVS 存取 SSID/密码）与 `params_store.{h,cpp}`（NVS 存取 PID/物理参数）；`config.h` 新增 NVS 命名空间常量段（`WIFI_NVS_NAMESPACE` / `PARAMS_NVS_NAMESPACE` 等）。
- feat(firmware): `motor_task` / `speed_sensor` PID 与物理参数改为 `static volatile` 运行时变量 + setter（`motor_set_pid` / `motor_set_ramp` / `motor_set_physical` / `speed_sensor_set_physical`）；`motor_init` / `speed_sensor_init` 在初始化时从 NVS 加载，无 NVS 时回退 `config.h` 宏默认。
- feat(firmware): `protocol.h` 新增 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 宏 + `SetParamsPayload` 结构（`#pragma pack(1)` + `PROTO_STATIC_ASSERT` 校验 21 字节）；`ble_task.cpp` `ControlCharacteristicCallbacks::onWrite` 改为按 CMD 字节分发：`CMD_CONTROL` 走原控制逻辑、`CMD_SET_PARAMS` 调 `motor_set_*` + `params_store_save_*`、`CMD_SET_WIFI` 调 `wifi_config_set`、未知 CMD 丢弃。

### Changed
- ci(app): 取消 HarmonyOS HAP 自动构建 -- `build-hap` job 改为 `if: github.event_name == 'workflow_dispatch'`，仅手动触发，不再进入 push/PR/tag 自动流水线；`release` job 的 `needs` 仍列 `build-hap`（手动未触发时视为 skipped=success，不阻塞 release），`files` 保留 `artifacts/app-hap/*` glob 以备手动构建产物。
- ci(firmware): 切换 PlatformIO 平台为 pioarduino 社区发行包（`platform-espressif32` stable），从而获得 Arduino-ESP32 core 3.x，与 `motor_task.cpp` 已迁移的 v3.x LEDC API 对齐；官方 platform 仍绑定 core 2.0.17。
- ci(app): 为 Flutter Action 启用 `cache: true`，并新增 cargo 缓存（`~/.cargo/registry`、`~/.cargo/git`、`app/rust/target`），减少 CI 重复编译耗时。
- ci: build-matrix 与 cargo-doc job 显式声明 `permissions: contents: read`，release job 按需授予 `contents: write`，实现最小权限原则。
- feat(app): Material 3 **默认配色**替代自定义橙黑 HUD 配色 —— 移除 `AppColors` 类与 `colorSchemeSeed`，结构色（背景/表面/主色/文字）一律取自 `Theme.of(context).colorScheme`；状态语义色由新 `HudStatus` 承载（`Colors.green`/`Colors.amber`/`colorScheme.error`）。`AppTheme` 新增 `light()`/`dark()` 双主题，`main.dart` 接入 `theme`/`darkTheme`/`themeMode`。`joystick`/`camera_viewport`/`telemetry_panel`/`control_panel`/`settings_screen` 同步迁移。
- feat(app): 字体改为 M3 默认 —— 移除 `'Roboto Mono'` / `'Inter'` 自定义字体引用，等宽数值走系统 `'monospace'` fallback（`AppTheme.mono()`），数值标签改用 M3 `textTheme.labelSmall` / `titleMedium` 等角色；`pubspec.yaml` 不引入第三方字体包（无 `fonts:` 段、不引入 `google_fonts`）。
- feat(app): `settings_screen.dart` `_numField` 改为 M3 默认 outline —— 删除 `filled: true` / `fillColor` / 自定义 `border`，沿用 M3 `TextFormField` 默认 outline 外观。
- feat(app): `HomeScreen` 重构为 `Scaffold` + `NavigationBar` + `IndexedStack`，移除 `/settings` 命名路由与 AppBar 设置 IconButton；导航由底部 tab 完成，设置入口统一收口到「设置」tab。
- feat(firmware): PID / 物理参数从 `config.h` 编译期宏改为运行时 `static volatile` 变量 + NVS 加载，首次启动行为与原版一致（无 NVS 时回退宏默认），运行时可通过 BLE `CMD_SET_PARAMS` 修改并持久化。

### Fixed
- fix(app): 消除 `prefer_const_constructors` lint 警告 -- `ble_controller.dart` 的 `BleState(...)`、`tilt_controller.dart` 的 `ControlCommand(...)`、`main.dart` `_DriveTab` 的 `Scaffold/SafeArea/Column` 嵌套构造、`settings_screen.dart` 的 `ListTile(...)` 均改为 `const` 构造，提升性能。`frb_generated.dart` 两处同类警告属生成代码（gitignored），不手改。
- fix(app): 底部 NavigationBar 点击不显示页面的真正根因修复 —— Rust 侧新增 `encode_set_params` / `encode_set_wifi` 后未跑 `flutter_rust_bridge_codegen generate`，`lib/src/rust/control.dart` 缺失对应 Dart 符号，`ble_controller.dart:543,586` 引用 `control_rust.encodeSetParams` / `control_rust.encodeSetWifi` 触发 `undefined_function`，整个 Dart 编译失败导致 hot reload 静默不生效，用户看到的表象就是"点了 tab 没换页"。本次在 `app/` 下重新执行 codegen，Dart 绑定补齐即恢复。同时清理 `app/lib/ui/joystick.dart` 未使用的 `theme.dart` 导入。
- fix(app): 底部 NavigationBar 点击不切换页面修复 —— 将 `ref.listenManual` 错误监听注册延迟到 `addPostFrameCallback`（第一帧渲染完成后），确保 `ScaffoldMessenger` 已挂载、`context` 完全可用；保存 `ProviderSubscription` 并在 `dispose` 中正确 `close()`，listener 内加 `mounted` 检查；`onDestinationSelected` 加重复点击判断跳过不必要的 `setState`。修复根因：initState 阶段注册 listener 可能因 context 未完全挂载或 provider 初始化触发 listener 回调导致异常，中断 widget tree 正常构建。
- fix(ci/app): 修复 `build-hap` job 因 `gitcode.com/CPF-Flutter/flutter_flutter` SDK fork 的 `version` 文件为 `0.0.0-unknown` 导致 `flutter create --platforms=ohos` 内部 `flutter pub get` 失败的 bug：clone 后写入真实版本号 `3.27.4` 并同步修正 `bin/cache/flutter.version.json`；将 OpenHarmony SDK 下载与 hvigor/ohpm 安装步骤提前到 `flutter create` 之前；调优 HAP artifact 上传路径。
- fix(app): 驾驶 tab 空白复现的防御性修复 —— `_HomeScreenState` 的 `ref.listen(bleControllerProvider, ...)` 从 `build` 顶部移到 `initState`，改用 Riverpod 2 推荐的 `ref.listenManual` 注册 errorMessage 监听，避免在 widget build 期间注册 listener 的潜在副作用（build 可能被框架多次调用）。配合上轮的 `_DriveTab` 包 `Scaffold`+`SafeArea` + `IndexedStack` 加 `sizing: StackFit.expand` 修复。若 bug 仍在，需用户提供 `flutter run` 控制台日志（含本轮新增 `BleController` 诊断日志）深入排查。
- fix(ci): 将 `.github/workflows/app.yml` 与 `firmware.yml` 中的 `actions/checkout`、`actions/cache`、`actions/upload-artifact`、`actions/download-artifact`、`actions/setup-python` 升级到 Node 24 原生大版本（`@v7`/`@v6`/`@v7`/`@v8`/`@v6`），消除 `Node.js 20 is deprecated` 警告。
- fix(app): 设备页缺失扫描/连接按钮 —— 原 UI 仅在 AppBar 跳设置，无法扫描 BLE 设备；新增 `devices_screen.dart` 提供「设备」tab 扫描/连接/断开入口，状态分支由 `BleState.status` 驱动。
- fix(firmware): 修正 `firmware/platformio.ini` 中 `espressif/esp32-camera` 依赖为 GitHub 源 `https://github.com/espressif/esp32-camera.git#v2.1.7`，修复 PlatformIO Library Registry 中 `^2.4.0`/`^2.1.7` 均不存在导致的 `UnknownPackageError`。
- fix(firmware): 移除 `ble_task.cpp` 中 NimBLE 栈不存在的 `BLECharacteristic::getSubscribedCount()` 调用，改为直接调用 `send_image_frame()`（NimBLE 的 `notify()` 在无订阅时自动跳过），修复启用 `-DUSE_NIMBLE` 后的编译失败。
- fix(ci/app): 修正 Android compileSdk patch 的 Kotlin DSL 注入块，将 `CommonExtension` 替换为反射调用 `setCompileSdk`/`setCompileSdkVersion(Int)`，修复 Gradle `Unresolved reference 'compileSdk'` 构建失败。
- fix(ci/app): 修正根 `android/build.gradle(.kts)` 的 `subprojects` 注入方式：改在已有的第一个 `subprojects {` 块内插入 `afterEvaluate { ... }`，避免在文件末尾追加新块导致 Gradle 报 `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`。
- fix(app): `pubspec.yaml` 中 `flutter_rust_bridge` 的版本约束 `=2.12.0` 不符合 Dart pub 语法（`=` 是 Cargo 语法），导致 `flutter pub get` 报 `Invalid version constraint` 失败；改为精确版本 `2.12.0`。
- fix(app): `ble_controller.dart` 修复多个状态机竞态：connect() 取消残留扫描订阅/定时器；startScan() 超时回调早退时补 complete 防止 Future 永久挂起；_onConnected() 置 connected 前取消残留 _reconnectTimer，避免健康连接被自残式重连断开；connect() 与 _attemptReconnect() 重置 _initializing 时同步递增 _initGeneration，防止旧 _onConnected` 从 await 恢复后干扰新连接。
- fix(app): `keyboard_controller.dart` 移除 `widgets.dart` 中对 `KeyEventResult` 的 show import（由 `services.dart` 全量提供），避免潜在编译错误。
- fix(ci): 确认 `actions/checkout@v7`、`actions/cache@v6`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`actions/setup-python@v6` 大版本 tag 均存在且为 Node 24 运行时，回退此前错误的 `@v5` 回退，避免 Node 20 弃用警告。
- fix(ci/app): 修正 Android compileSdk `sed` 正则，要求至少一位数字并显式匹配 `compileSdk = flutter.compileSdkVersion` 引用形式，避免 patch 后生成非法 Kotlin 导致 Gradle 失败。
- fix(ci/firmware): 将 release 拆分为独立 job，build job 仅保留 `permissions: contents: read`，release job 按需授予 `permissions: contents: write`，符合最小权限原则。
- fix(app): `pubspec.yaml` 列出的 `flutter_rust_bridge_codegen` 不是 Dart 包（实为 crates.io 上的 Rust crate），导致 `flutter pub get` 失败；移除该 `dev_dependency`，codegen 改由 `cargo install` 提供（CI 已配置）。
- fix(firmware): `motor_task.cpp` 迁移至 Arduino-ESP32 v3.x LEDC API（`ledcAttach` + `ledcWrite(pin, duty)`），修复 CI 因 `ledcSetup`/`ledcAttachPin`/`LEDC_CHANNEL_*` 在 v3.x 被移除导致的编译失败。
- fix(app): 修正 `ble_controller.dart` 中 `flutter_reactive_ble` `subscribeToCharacteristic` 的订阅类型（`Stream<List<int>>`），移除已废弃的 `CharacteristicValue` 提取辅助函数。
- fix(app): 在 `keyboard_controller.dart` 导入 `KeyEventResult`，并移除 `main.dart` 中未使用的 `ble_controller` 导入。
- fix(app): 将 UI 文件中弃用的 `Color.withOpacity` 替换为 `Color.withValues(alpha: ...)`。
- fix(app/rust): 为 `flutter_rust_bridge` 生成绑定补充 `ImageAssembler` 构造器与 `encode_control` 重导出，并适配 Dart 调用方使用命名参数。
- fix(firmware): `ble_task.cpp` 适配 Arduino-ESP32 core 3.x + NimBLE：`ControlCharacteristicCallbacks::onWrite` 中 `getValue()` 返回 Arduino String 改为 `.c_str()` 构造 `std::string`（修复 String→`std::string` 转换错误）；移除 `BLE2902.h` 与两处 `addDescriptor(new BLE2902())`（NimBLE 对 NOTIFY/INDICATE 特征自动添加 CCCD，`BLE2902` 在该栈下已 deprecated）。
- fix(ci/firmware): 替换 `pio run -t mergebin` 为 `esptool.py --chip esp32s3 merge-bin` 直接合并 bootloader+partitions+boot_app0+firmware；pioarduino 社区平台未注册 `mergebin` SCons 目标导致 CI 报 `'Do not know how to make File target mergebin'`。同时删除多余的 Rename artifact 步骤。
- fix(ci/app): 为 `app/rust/src/api.rs` 与 `image.rs` 补 `use flutter_rust_bridge::frb;` 导入，修复 `cargo doc --no-deps --all-features` 报 `'cannot find attribute frb in this scope'`（frb v2 codegen 不会自动向用户源文件注入该 import）。
- fix(ci/app): 在 `flutter create .` 之后追加 Patch Android compileSdk 步骤（`sed` 改 `android/app/build.gradle` + 向 `android/build.gradle` 注入 `subprojects` 块），将 `compileSdk` 提升到 35，修复 `:reactive_ble_mobile` 因 AndroidX 1.7.x 依赖要求 SDK 34+ 导致的 `checkReleaseAarMetadata` 失败。
- 修复 `app/android/` 等平台目录因 `.gitkeep` 残留，导致 CI 中 `flutter create .` 未完整生成 `android/app/build.gradle`，进而使 Android SDK patch 步骤报 `No such file or directory`。
- fix(app): 修复驾驶 tab 空白 + 底部 NavigationBar tab 点击不切换页面 —— `_DriveTab` 是三个 tab 中唯一直接返回裸 `Column`（无 `Scaffold`）的，与 `DevicesScreen`/`SettingsScreen` 结构不对称；`IndexedStack` 默认 `StackFit.loose` 在某些 Flutter 版本/平台下导致裸 `Column` sizing 异常 → 驾驶页空白，IndexedStack 渲染失败时其他 tab 也看不到内容。修复：`_DriveTab` 包 `Scaffold`+`SafeArea`（无 AppBar 保留沉浸感）使三 tab 结构对称；`IndexedStack` 加 `sizing: StackFit.expand` 强制子节点填满 body，消除 sizing 歧义。
- 限制 `app.yml` 中 Android compileSdk patch 仅在 `build-matrix` 的 `apk` 条目执行；`cargo-doc` job 与桌面平台构建不再执行该步骤。
- fix(ci): `Clean platform directories` 步骤加 `shell: bash`，修复 Windows runner 上 `rm -rf` 失败；`cargo install` 锁定 `--version 2.12.0 --locked`；新增 `permissions: contents: write` 与 `concurrency`；firmware cache 加 `restore-keys`。
- fix(ci): Patch Android compileSdk 兼容 Flutter 3.29+ 的 `build.gradle.kts`；`concurrency.cancel-in-progress` 对 tag 推送不取消以保护 release；macOS `rust_target` 改为 `aarch64-apple-darwin`；release job 删除多余 Checkout 并限定 `pattern: app-*`。
- fix(firmware): `ble_task.cpp` onWrite 改用 `String.length()` 二进制安全读取，修复 `LEN_HI=0x00` 被 `c_str()` 截断导致所有控制帧失效；启用 `-DUSE_NIMBLE`；ISR 自增进入 `portENTER_CRITICAL_ISR` 临界区；`speed_task` 改用 `vTaskDelayUntil`；RPM 转 int16 前饱和防溢出；`camera_task` 队列二次投递失败释放内存；`motor_set_target` 入口饱和校验；任务优先级调整（motor/speed=3, camera/ble=2）。
- fix(firmware): 摄像头 LEDC 通道改为 `LEDC_CHANNEL_2`/`LEDC_TIMER_2`，避免抢占电机 ENA 通道导致左轮失控；JPEG 帧缓冲改用 PSRAM；PID 重置分支不再清零 `last_error`；`onDisconnect` 直接 `motor_stop()`；`send_image_frame` 循环内检查 `g_connected`；`esp32-camera` 锁定 `^2.4.0`；`partitions.csv` fr 分区补 `spiffs` 子类型；删除 `angular_mdps` 死字段。
- fix(app): `flutter_rust_bridge.yaml` 补 `crate::image`；`parse_packet` 加 `len<1` 校验防 panic；`startScan` 改 `Timer` 可取消并加状态守卫；`_onConnected` 先置 connected 再写入且失败统一进重连；订阅流补 `onError`；`frame_stream` 加 `isClosed` 检查与 `try/catch`；`_onJoystick` 加 80ms 节流；`tilt_controller` stop 指令绕过节流；`camera_viewport` FPS 定时归零；`encode_control` 返回 `Result` 防 FFI panic；`image.rs` 拒绝 `total_chunks==0`；移除未使用依赖。
- docs: `CHANGELOG.md` 链接占位符替换为实际仓库；`smart-bt-camera-car` spec/tasks 同步 `esptool.py merge-bin`；`app/rust/README.md` 修正 `api.rs`；`AGENTS.md` mergebin 条目去重、仓库边界补充 fix-ci spec。
- fix(app): `ble_controller.dart` 重连状态机加固：`_onDisconnected` 幂等守卫防 `_reconnectAttempts` 双重自增；`_attemptReconnect` 置 `connecting` 防重连失败卡死；`_initGeneration` 计数器 + try/catch/finally 全路径 generation 守卫，防旧 `_onConnected` 从 await 恢复后打断新连接或覆盖特征订阅；`connect()` 重置 `_initializing`。
- fix(app/rust): 删除 3 处 `#[frb(named_args)]`（`api.rs`/`ble.rs`/`control.rs`），该属性在 frb v2 中不存在（v1 旧属性），导致 `flutter_rust_bridge_codegen generate` panic、所有平台 CI 失败。frb v2 默认即生成 Dart 命名参数。
- fix(ci/app): `flutter_rust_bridge_codegen generate` 需要 `cargo-expand`，在 `app.yml` 中预装并锁定版本；同时补齐 `freezed_annotation`/`freezed`/`build_runner` 依赖，修复 `MissingDep: Please add freezed to your dev_dependencies` 错误。
- fix(app): `keyboard_controller.dart` 补回 `widgets.dart` 的 `show FocusNode, KeyEventResult;`（`KeyEventResult` 由 `widgets.dart` 再导出，不在 `services.dart`），修复 Linux/桌面构建报 `Type 'KeyEventResult' not found`。此前一次变更误将其从 `show` 子句移除。
- fix(ci/app): Android compileSdk patch 按 Gradle DSL 区分语法 —— Kotlin DSL（`build.gradle.kts`）产出 `compileSdk = 35`（带 `=`），Groovy（`build.gradle`）产出 `compileSdk 35`（不带 `=`）；`subprojects` 注入块同步区分。修复原单条 sed 对 `.gradle.kts` 生成非法 `compileSdk 35` 导致 Gradle 报 `Unexpected tokens`。
- fix(app/rust): 修复 clippy 警告 —— `image.rs` `push()` 合并 if/else 重复赋值（`branches_sharing_code`）；`api.rs` `handle_notify_packet` 用 `?` 扁平化 Option 并合并相同 match 臂（`match_same_arms`）；`ble.rs` `crc8` 补括号（`precedence`）。
- fix(ci): 升级 `actions/checkout`/`cache`/`upload-artifact`/`download-artifact` 至 `@v7`/`@v6`/`@v7`/`@v8`，`setup-python` 至 `@v6`（Node 24 运行时），修复 GitHub Actions 自 2025-09-19 弃用 Node 20 产生的 `Node.js 20 is deprecated` 警告（`app.yml` 与 `firmware.yml` 全量替换）。
- fix(app/rust): 在 `Cargo.toml` 新增 `[lints.rust]` 段声明 `frb_expand` 为已知 cfg（`unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }`），修复 `#[frb(sync)]`/`#[frb(opaque)]` 属性宏内部展开 `cfg(frb_expand)` 触发 `unexpected_cfgs` 导致 `cargo clippy -D warnings` 失败。
- fix(app/rust): 修复 clippy 风格警告 —— `control.rs` `encode_control` 两处边界判断改 `!(-1..=1).contains(&x)`（`manual_range_contains`）；`image.rs` 分片拼接循环改 `self.received.drain(..).flatten()`（`manual_flatten`）。

## [0.1.0] - 2026-07-04
### Added
- ESP32-S3 固件工程（PlatformIO + Arduino）：摄像头采集、BLE 通信、电机 PID 控制、红外测速四线程
- Flutter + Rust 跨端 App（flutter_rust_bridge）：Material Design 3，适配 Android 与桌面三平台
- GitHub Actions 流水线：固件 `firmware-merged.bin`（可烧录到 0x0）与 App 多平台二进制
- BLE 二进制协议：图像分片 NOTIFY / 控制写入 / 遥测 NOTIFY
- 正弦曲线加速 + 10ms 周期 PID 左右轮平衡
- 手机体感操控 + 桌面 WASD 键盘控制

[Unreleased]: https://github.com/halfoffive/esp32-s3-smart-bluetooth-camera-car/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/halfoffive/esp32-s3-smart-bluetooth-camera-car/releases/tag/v0.1.0
