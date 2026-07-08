# Smart Car Remote — 智能蓝牙摄像头小车遥控 App

基于 Flutter + Rust（flutter_rust_bridge）的跨端遥控 App，配合 ESP32-S3 智能蓝牙摄像头小车使用。
通过 BLE 接收车载摄像头画面与遥测数据，下发方向 / 速度指令；手机端支持加速度计体感操控，
桌面端支持键盘 WASD / 方向键。Rust 侧以纯函数处理 BLE 协议解析、JPEG 分片重组、控制指令编码。

BLE 二进制协议、GATT UUID、帧格式详见仓库根目录 [README](../README.md#ble-通信协议)。

## 技术栈

- Flutter（latest stable）+ Dart
- Rust（stable）+ [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) v2.x（latest）
- 状态管理：Riverpod；模型：Freezed
- BLE：flutter_reactive_ble；传感器：sensors_plus

## 目标平台

Android、Linux、Windows、macOS（iOS 暂未纳入构建流水线）。

## 首次拉取

本仓库未提交 Flutter 平台原生目录（`android/` `linux/` `windows/` `macos/`），首次拉取后请在 `app/` 下运行：

```bash
flutter create . --platforms=android,linux,windows,macos --org com.smartcar --project-name smart_car_remote
flutter_rust_bridge_codegen generate   # 生成 Rust ↔ Dart 绑定
flutter pub get
```

`flutter create .` 会补全各平台原生工程目录，不会覆盖 `lib/` 与 `pubspec.yaml`。

## flutter_rust_bridge 代码生成

Rust 侧接口写在 `rust/src/api.rs` 下，Dart 侧胶水代码由 codegen 生成。修改 Rust 接口后执行：

```bash
flutter_rust_bridge_codegen generate
```

参考官方文档：<https://cjycode.com/flutter_rust_bridge/>

## 运行与调试

```bash
flutter pub get
flutter run -d <device>      # <device> 如 linux / windows / macos / <android-device-id>
```

## 构建

各平台 release 构建、CI 产物下载见根目录 [README](../README.md#app-构建与运行)。

## Rust 文档

```bash
cd rust
cargo doc --no-deps --open
```

## 目录结构

```
app/
├── lib/                       # Dart 主代码
│   ├── main.dart              # 应用入口
│   ├── ble/                   # BLE 连接层
│   │   ├── ble_controller.dart   # 扫描 / 连接 / MTU 协商 / 特征订阅 / 自动重连
│   │   ├── car_device.dart       # 设备抽象（名称 ESP32S3_SmartCar、UUID 绑定）
│   │   └── frame_stream.dart     # NOTIFY 包 → Rust 重组 → JPEG 流
│   ├── ui/                    # Material Design 3 UI
│   │   ├── camera_viewport.dart  # 上方摄像头画面 + HUD 覆盖层
│   │   ├── control_panel.dart    # 操控区容器
│   │   ├── joystick.dart         # 虚拟摇杆 widget
│   │   ├── telemetry_panel.dart  # 左右 RPM / 线速度 / 目标速度 / 电池
│   │   ├── settings_screen.dart  # PID / T_ramp / 轮径 / 轮距 / 槽数（本地持久化）
│   │   └── theme.dart            # MD3 主题、调色板、字体配对
│   └── input/                 # 输入处理
│       ├── keyboard_controller.dart  # 桌面 WASD / 方向键
│       └── tilt_controller.dart      # 手机体感（加速度计 → 目标速度/转向）
├── rust/                      # Rust 子 crate（flutter_rust_bridge）
│   ├── src/
│   │   ├── lib.rs             # crate 入口
│   │   ├── api.rs             # flutter_rust_bridge 暴露的 API 表面
│   │   ├── ble.rs             # 帧解析（同步头 / 长度 / CRC8 校验）
│   │   ├── image.rs           # assemble_chunk(state, packet) -> Option<Frame> 分片重组
│   │   ├── control.rs         # encode_command(dir, turn, speed) -> Vec<u8> 控制指令编码
│   │   └── telemetry.rs       # 遥测结构体解码
│   └── Cargo.toml
├── android/ linux/ windows/ macos/   # 平台原生目录（由 flutter create . 补全）
└── pubspec.yaml
```

## 操作模式

- **手机端**：
  - **摇杆模式**：屏幕虚拟摇杆，方向 + 速度幅度
  - **体感模式**：加速度计读数映射（前倾前进、左右倾转向），一键切换
- **桌面端**：
  - **摇杆模式**：屏幕虚拟摇杆
  - **键盘模式**：WASD / 方向键，按下立即下发，松开触发平滑减速
- **紧急停车**：主界面紧急停车按钮，立即发送 stop 指令（speed_pct=0）
- 输入去抖 + 速率限制，避免 BLE 写入过载
