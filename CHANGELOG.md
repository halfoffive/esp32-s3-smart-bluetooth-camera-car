# Changelog

本仓库所有重要变更均记录于此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- feat(app): 主题模式设置 —— 设置页新增「外观」段，`SegmentedButton` 切换 系统/浅色/深色，选择持久化到 `shared_preferences`（键 `car_theme_mode`），默认跟随系统（`ThemeMode.system`）。新增 `theme_mode_controller.dart`（Riverpod `StateNotifier<ThemeMode>`）。
- ci(app): `app.yml` 新增 `cargo clippy --all-features -- -D warnings` 门槛（`cargo-doc` 与 `build-matrix` job 均在 codegen 之后、build/doc 之前执行），clippy 警告即构建失败。

### Changed
- ci(firmware): 切换 PlatformIO 平台为 pioarduino 社区发行包（`platform-espressif32` stable），从而获得 Arduino-ESP32 core 3.x，与 `motor_task.cpp` 已迁移的 v3.x LEDC API 对齐；官方 platform 仍绑定 core 2.0.17。
- ci(app): 为 Flutter Action 启用 `cache: true`，并新增 cargo 缓存（`~/.cargo/registry`、`~/.cargo/git`、`app/rust/target`），减少 CI 重复编译耗时。
- ci: build-matrix 与 cargo-doc job 显式声明 `permissions: contents: read`，release job 按需授予 `contents: write`，实现最小权限原则。
- feat(app): Material 3 **默认配色**替代自定义橙黑 HUD 配色 —— 移除 `AppColors` 类与 `colorSchemeSeed`，结构色（背景/表面/主色/文字）一律取自 `Theme.of(context).colorScheme`；状态语义色由新 `HudStatus` 承载（`Colors.green`/`Colors.amber`/`colorScheme.error`）。`AppTheme` 新增 `light()`/`dark()` 双主题，`main.dart` 接入 `theme`/`darkTheme`/`themeMode`。`joystick`/`camera_viewport`/`telemetry_panel`/`control_panel`/`settings_screen` 同步迁移。

### Fixed
- fix(app): `pubspec.yaml` 中 `flutter_rust_bridge` 的版本约束 `=2.12.0` 不符合 Dart pub 语法（`=` 是 Cargo 语法），导致 `flutter pub get` 报 `Invalid version constraint` 失败；改为精确版本 `2.12.0`。
- fix(app): `ble_controller.dart` 修复多个状态机竞态：connect() 取消残留扫描订阅/定时器；startScan() 超时回调早退时补 complete 防止 Future 永久挂起；_onConnected() 置 connected 前取消残留 _reconnectTimer，避免健康连接被自残式重连断开；connect() 与 _attemptReconnect() 重置 _initializing 时同步递增 _initGeneration，防止旧 _onConnected 从 await 恢复后干扰新连接。
- fix(app): `keyboard_controller.dart` 移除 `widgets.dart` 中对 `KeyEventResult` 的 show import（由 `services.dart` 全量提供），避免潜在编译错误。
- fix(ci): 将 `actions/checkout`、`upload-artifact`、`download-artifact`、`cache`、`setup-python` 修正到实际存在的稳定大版本（`@v4`/`@v5`），修复因 v7/v6 标签不存在导致 CI workflow 解析失败。
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
- fix(ci): 升级 `actions/checkout`/`cache`/`upload-artifact`/`download-artifact` 至 `@v5`（Node 24 运行时），修复 GitHub Actions 自 2025-09-19 弃用 Node 20 产生的 `Node.js 20 is deprecated` 警告（`app.yml` 与 `firmware.yml` 全量替换；`setup-python@v5` 与 `flutter-action@v2` 已兼容未动）。
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
