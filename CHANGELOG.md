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
- `fix(app): pubspec.yaml 列出的 flutter_rust_bridge_codegen 不是 Dart 包（实为 crates.io 上的 Rust crate），导致 flutter pub get 失败；移除该 dev_dependency，codegen 改由 cargo install 提供（CI 已配置）。`
- `fix(firmware): motor_task.cpp 迁移至 Arduino-ESP32 v3.x LEDC API（ledcAttach + ledcWrite(pin, duty)），修复 CI 因 ledcSetup/ledcAttachPin/LEDC_CHANNEL_* 在 v3.x 被移除导致的编译失败。`
- `fix(app): 修正 ble_controller.dart 中 flutter_reactive_ble subscribeToCharacteristic 的订阅类型（Stream<List<int>>），移除已废弃的 CharacteristicValue 提取辅助函数。`
- `fix(app): 在 keyboard_controller.dart 导入 KeyEventResult，并移除 main.dart 中未使用的 ble_controller 导入。`
- `fix(app): 将 UI 文件中弃用的 Color.withOpacity 替换为 Color.withValues(alpha: ...)。`
- `fix(app/rust): 为 flutter_rust_bridge 生成绑定补充 ImageAssembler 构造器与 encode_control 重导出，并适配 Dart 调用方使用命名参数。`
- `fix(firmware): ble_task.cpp 适配 Arduino-ESP32 core 3.x + NimBLE：ControlCharacteristicCallbacks::onWrite 中 getValue() 返回 Arduino String 改为 .c_str() 构造 std::string（修复 String→std::string 转换错误）；移除 BLE2902.h 与两处 addDescriptor(new BLE2902())（NimBLE 对 NOTIFY/INDICATE 特征自动添加 CCCD，BLE2902 在该栈下已 deprecated）。`

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
