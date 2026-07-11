# Smart Car Remote — 智能蓝牙摄像头小车遥控 App

基于 Flutter + Rust（flutter_rust_bridge）的跨端遥控 App，配合 ESP32-S3 智能蓝牙摄像头小车使用。
通过 BLE 接收车载摄像头画面与遥测数据，下发方向 / 速度指令。Rust 侧以纯函数处理 BLE 协议解析、JPEG 分片重组、控制指令编码。

**导航流程**：打开应用 -> 设备连接页（扫描/连接 BLE）-> 连接成功自动进入横屏控制页（摄像头 + 单摇杆）；设置与断开连接藏在控制页 / 设备页的 AppBar 菜单中。

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
│   │   ├── camera_viewport.dart  # 摄像头画面 + HUD 覆盖层
│   │   ├── control_screen.dart   # 横屏控制页（摄像头 + 单摇杆，状态驱动路由）
│   │   ├── control_panel.dart    # 单摇杆 + 紧急停车面板
│   │   ├── devices_screen.dart   # 设备连接页（应用入口：扫描/连接/断开）
│   │   ├── joystick.dart         # 虚拟摇杆 widget
│   │   ├── telemetry_panel.dart  # 左右 RPM / 线速度 / 目标速度 / 电池
│   │   ├── settings_screen.dart  # 主题 / PID / 物理参数 / WiFi 配置
│   │   ├── theme_mode_controller.dart  # 主题模式（系统/浅色/深色）持久化
│   │   └── theme.dart            # MD3 默认主题、HudStatus 语义色、等宽字体
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

- **单摇杆控制**：控制页右侧虚拟摇杆，方向 + 速度幅度（模长映射速度百分比）。释放自动回中并发送 stop。
- **横屏锁定**：控制页 `initState` 锁定 `landscapeLeft/landscapeRight`，离开控制页恢复全方向。
- **紧急停车**：控制页紧急停车按钮，立即发送 stop 指令（speed_pct=0）。
- **菜单**：控制页 / 设备连接页 AppBar `PopupMenuButton` 提供设置入口；控制页额外提供「断开连接」。
- 摇杆 80ms 节流，避免 BLE 写入过载；释放事件不节流，确保及时停车。
