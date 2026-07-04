# Changelog

本仓库所有重要变更均记录于此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

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
