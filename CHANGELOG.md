# Changelog

本仓库所有重要变更均记录于此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Changed
- `ci(firmware): 切换 PlatformIO 平台为 pioarduino 社区发行包（platform-espressif32 stable），从而获得 Arduino-ESP32 core 3.x，与 motor_task.cpp 已迁移的 v3.x LEDC API 对齐；官方 platform 仍绑定 core 2.0.17。`
- `ci: bump GitHub Actions 至 Node.js 24 版本（actions/checkout@v7.0.0、actions/cache@v6.1.0、actions/setup-python@v6.3.0、actions/upload-artifact@v7.0.1），消除 Node.js 20 deprecation warning。`
- `ci(app): 在 flutter_rust_bridge_codegen generate 之前新增 cargo install cargo-expand 步骤，预先装好传递依赖，避免 codegen 期间重复编译/下载。`

### Fixed
- `fix(firmware): ble_task.cpp onWrite 回调中 getValue().c_str() 在第一个 0x00 字节处截断控制帧（控制帧 LEN_HI 恒为 0x00），导致所有控制指令被静默丢弃；改为直接 getValue() 拷贝 std::string 保留完整二进制。`
- `fix(firmware): motor_task.cpp ledcAttach 自动分配通道 0 与 esp_camera 的 LEDC_CHANNEL_0 冲突，覆盖左轮 PWM；改用 ledcAttachChannel 显式指定通道 1/2。`
- `fix(firmware): motor_task.cpp target_pwm 未钳位，speed_pct>100 时溢出 V_MAX_PWM 导致遥测与 turn_bias 计算错误；包裹 clamp_pwm 防御。`
- `fix(firmware): speed_sensor.cpp vTaskDelay（相对延时）改为 vTaskDelayUntil（绝对节拍），消除采样窗口漂移。`
- `fix(app): ble_controller.dart _onConnected 中 sendControl(0,0,0) 因 status 仍为 connecting 被守卫跳过；将 status=connected 移到 sendControl 之前。`
- `fix(app): ble_controller.dart _onConnected catch 块未取消 _connSub/_imageSub/_telemetrySub，残留订阅触发回调；增加 cancel 清理。`
- `fix(app): ble_controller.dart 异步回调无 mounted 检查，dispose 后 setState 崩溃；在所有 await 后加 mounted 守卫，dispose 首行设 _userDisconnect。`
- `fix(app): tilt_controller.dart stop 指令被节流丢弃，小车不停车；speedPct==0 时绕过节流立即发送。`
- `fix(app): camera_viewport.dart Image.memory 缺少 errorBuilder，坏帧导致红屏；增加 errorBuilder 返回空 SizedBox。`
- `fix(app): frame_stream.dart Future 链缺少 .catchError，单次 FFI 异常永久中断帧/遥测流；增加 catchError 保持链存活。`
- `fix(ci/app): macOS rust_target 从 x86_64-apple-darwin 改为 aarch64-apple-darwin（macos-latest 现为 arm64 runner）。`
- `fix(ci/app): release job 不再依赖 cargo-doc；download-artifact 从 v4 升级到 v7；Linux 依赖步骤条件改为 matrix.flutter_target == 'linux'。`
- `fix(ci/app): Patch Android compileSdk 步骤向 build.gradle.kts 注入 Groovy 语法（compileSdk 35 无 =）导致 Kotlin DSL 编译失败；改为检测 .kts 扩展名并注入 Kotlin DSL 语法（compileSdkVersion(35)）。`
- `fix(ci/app): heredoc 内容在 YAML run: | 块中缩进为 0 列导致 scalar 提前终止、整个 app.yml 无法解析；改用 printf 单行注入避免缩进冲突。`
- `fix(ci/app): sed 正则 compileSdk = [0-9]* 在 Flutter 3.44.4+ 生成的 compileSdk = flutter.compileSdkVersion 上零匹配后插入 35 产生非法 Kotlin；改为 compileSdk = .* 全量替换。`
- `fix(app): pubspec.yaml 列出的 flutter_rust_bridge_codegen 不是 Dart 包（实为 crates.io 上的 Rust crate），导致 flutter pub get 失败；移除该 dev_dependency，codegen 改由 cargo install 提供（CI 已配置）。`
- `fix(firmware): motor_task.cpp 迁移至 Arduino-ESP32 v3.x LEDC API（ledcAttach + ledcWrite(pin, duty)），修复 CI 因 ledcSetup/ledcAttachPin/LEDC_CHANNEL_* 在 v3.x 被移除导致的编译失败。`
- `fix(app): 修正 ble_controller.dart 中 flutter_reactive_ble subscribeToCharacteristic 的订阅类型（Stream<List<int>>），移除已废弃的 CharacteristicValue 提取辅助函数。`
- `fix(app): 在 keyboard_controller.dart 导入 KeyEventResult，并移除 main.dart 中未使用的 ble_controller 导入。`
- `fix(app): 将 UI 文件中弃用的 Color.withOpacity 替换为 Color.withValues(alpha: ...)。`
- `fix(app/rust): 为 flutter_rust_bridge 生成绑定补充 ImageAssembler 构造器与 encode_control 重导出，并适配 Dart 调用方使用命名参数。`
- `fix(firmware): ble_task.cpp 适配 Arduino-ESP32 core 3.x + NimBLE：ControlCharacteristicCallbacks::onWrite 中 getValue() 返回 Arduino String 改为 .c_str() 构造 std::string（修复 String→std::string 转换错误）；移除 BLE2902.h 与两处 addDescriptor(new BLE2902())（NimBLE 对 NOTIFY/INDICATE 特征自动添加 CCCD，BLE2902 在该栈下已 deprecated）。`
- `fix(ci/firmware): 替换 pio run -t mergebin 为 esptool.py --chip esp32s3 merge-bin 直接合并 bootloader+partitions+boot_app0+firmware；pioarduino 社区平台未注册 mergebin SCons 目标导致 CI 报 'Do not know how to make File target mergebin'。同时删除多余的 Rename artifact 步骤。`
- `fix(ci/app): 为 app/rust/src/api.rs 与 image.rs 补 use flutter_rust_bridge::frb; 导入，修复 cargo doc --no-deps --all-features 报 'cannot find attribute frb in this scope'（frb v2 codegen 不会自动向用户源文件注入该 import）。`
- `fix(ci/app): 在 flutter create . 之后追加 Patch Android compileSdk 步骤（sed 改 android/app/build.gradle + 向 android/build.gradle 注入 subprojects 块），将 compileSdk 提升到 35，修复 :reactive_ble_mobile 因 AndroidX 1.7.x 依赖要求 SDK 34+ 导致的 checkReleaseAarMetadata 失败。`
- 修复 CI 中 Android compileSdk patch 步骤路径错误，将工作目录设为 `app/` 并使用 `android/app/build.gradle` 与 `android/build.gradle` 相对路径。
- 修复 CI 中 `flutter create . --platforms=android,linux,windows,macos` 一次性生成多平台模板导致 `android/` 目录缺失的问题；改为按矩阵条目仅生成目标平台，并为 Bootstrap 步骤显式指定 `working-directory: app` 与 `shell: bash`。
- 修复 `app/android/` 等平台目录因 `.gitkeep` 残留，导致 CI 中 `flutter create .` 未完整生成 `android/app/build.gradle`，进而使 Android SDK patch 步骤报 `No such file or directory`。
- 限制 `app.yml` 中 Android compileSdk patch 仅在 `build-matrix` 的 `apk` 条目执行；`cargo-doc` job 与桌面平台构建不再执行该步骤。
- 修复 Windows runner 上 `rm -rf` 命令不兼容 PowerShell 导致 "Clean platform directories" 步骤失败（添加 `shell: bash`）
- 修复 CI 中 Android compileSdk patch 步骤无法找到 build.gradle 的问题（Flutter 3.44.4+ 默认生成 build.gradle.kts）；改为自动检测 .gradle 或 .gradle.kts 扩展名。

## [0.1.0] - 2026-07-04
### Added
- ESP32-S3 固件工程（PlatformIO + Arduino）：摄像头采集、BLE 通信、电机 PID 控制、红外测速四线程
- Flutter + Rust 跨端 App（flutter_rust_bridge）：Material Design 3，适配 Android 与桌面三平台
- GitHub Actions 流水线：固件 `firmware-merged.bin`（可烧录到 0x0）与 App 多平台二进制
- BLE 二进制协议：图像分片 NOTIFY / 控制写入 / 遥测 NOTIFY
- 正弦曲线加速 + 10ms 周期 PID 左右轮平衡
- 手机体感操控 + 桌面 WASD 键盘控制

<!-- 链接占位符：USER/REPO 可替换为实际仓库所有者与名称 -->
[Unreleased]: https://github.com/USER/REPO/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/USER/REPO/releases/tag/v0.1.0
