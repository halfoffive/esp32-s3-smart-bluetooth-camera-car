# 智能蓝牙摄像头小车 (Smart Bluetooth Camera Car)

> 基于 Freenove ESP32-S3 WROOM（FNK0085）+ L298N + 双红外测速 + OV2640 摄像头的智能小车，通过 BLE 低延时遥控；配套 Flutter + Rust 跨端 App。

## 目录结构
- `firmware/` — ESP32-S3 固件（PlatformIO + Arduino + FreeRTOS 多线程）
- `app/` — 跨端遥控 App（Flutter + flutter_rust_bridge + Rust）
- `.github/workflows/` — CI 流水线（固件合并 bin / App 多平台构建 + cargo doc）
- `CHANGELOG.md` — 变更记录

## 硬件清单
| 部件 | 型号 / 说明 |
|---|---|
| 主控板 | Freenove ESP32-S3 WROOM (FNK0085)，板载 OV2640 摄像头 + 8MB PSRAM |
| 电机驱动 | L298N 双 H 桥 |
| 马达 | 2 × 直流减速电机 |
| 测速 | 2 × 红外对射编码器（槽型光耦） |
| 电源 | 适配 L298N 与 ESP32-S3 的电池组（具体视小车底盘） |

## 接线表
| ESP32-S3 GPIO | 连接目标 | 说明 |
|---|---|---|
| GPIO 1  | L298N ENA | 左轮 PWM（LEDC CH0） |
| GPIO 2  | L298N ENB | 右轮 PWM（LEDC CH1） |
| GPIO 41 | L298N IN1 | 左轮方向 |
| GPIO 42 | L298N IN2 | 左轮方向 |
| GPIO 45 | L298N IN3 | 右轮方向 |
| GPIO 46 | L298N IN4 | 右轮方向 |
| GPIO 14 | 左 IR 输出 | 中断 FALLING |
| GPIO 47 | 右 IR 输出 | 中断 FALLING |
| 摄像头 | 板载排母 | 引脚固定，参考 CAMERA_MODEL_ESP32S3_EYE |

> 引脚分配已避开板载摄像头占用（GPIO 4-18）、USB（19/20）、Flash（26-32）。

## 固件构建与烧录

> **平台要求**：`firmware/platformio.ini` 已锁定 `pioarduino` 社区平台
> （`https://github.com/pioarduino/platform-espressif32/releases/download/stable/platform-espressif32.zip`），
> 因为 `motor_task.cpp` 依赖 Arduino-ESP32 core **3.x** 的 LEDC API（`ledcAttach` / `ledcWrite(pin, duty)`），
> 而 PlatformIO 官方 `platform-espressif32` 仍只捆绑 core 2.0.17。首次构建 PlatformIO 会自动下载该 zip，后续离线复用。

### 本地构建
```bash
cd firmware
pio run -e esp32s3          # 编译
# 合并 bin：pioarduino 平台不支持 pio run -t mergebin，改用 esptool.py 直接合并
esptool.py --chip esp32s3 merge-bin -o firmware-merged.bin \
  0x0 .pio/build/esp32s3/bootloader.bin \
  0x8000 .pio/build/esp32s3/partitions.bin \
  0xe000 ~/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin \
  0x10000 .pio/build/esp32s3/firmware.bin
# 产物：firmware-merged.bin
```

### 烧录（合并 bin，0x0 偏移）
```bash
esptool.py write_flash 0x0 firmware/firmware-merged.bin
```

或用 PlatformIO 直接上传（仅 firmware 部分）：
```bash
pio run -e esp32s3 -t upload
```

### CI 产物
GitHub Actions 在 push 到 main 或打 `v*` tag 时构建并上传 `firmware-merged.bin`，可在 Actions → Artifacts 下载，直接 `esptool.py write_flash 0x0 firmware-merged.bin` 烧录。

## App 构建与运行

### 首次拉取
```bash
cd app
flutter create . --platforms=android,linux,windows,macos --org com.smartcar --project-name smart_car_remote
flutter_rust_bridge_codegen generate   # 生成 Rust ↔ Dart 绑定
flutter pub get
```

### 运行
```bash
flutter run -d <device-id>
```

**桌面端（Windows/Linux/macOS）本地开发注意**：
- 运行前需先在 `app/rust/` 下编译 Rust crate，生成 `rust_lib.dll` / `.so` / `.dylib`：
  ```bash
  cd app/rust
  cargo build --release
  ```
  否则启动时会因找不到 Rust 动态库而进入错误回退页。
- BLE 包已迁移到 `flutter_blue_plus`，原生支持 Android / iOS / Linux / macOS，Windows 通过 federated 插件 `flutter_blue_plus_winrt` 支持。编译 Rust 动态库后即可在桌面端扫描/连接/控制。

### 构建
```bash
flutter build apk --release        # Android
flutter build linux --release      # Linux
flutter build windows --release    # Windows
flutter build macos --release      # macOS
```

HarmonyOS HAP 构建需使用 [flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter) SDK fork（OpenHarmony 适配版），并预装 JDK 17 + OpenHarmony SDK + hvigor/ohpm；CI 的 `build-hap` job 已配齐此工具链（实验性，允许失败）。本地构建命令：

```bash
# 需先 clone flutter_flutter fork 并加入 PATH
cd app && flutter build hap --release    # HarmonyOS（unsigned）
```

### Rust 文档
```bash
cd app/rust
cargo doc --no-deps --open
```

### CI 产物
GitHub Actions 在 push 到 main 或打 `v*` tag 时构建各平台二进制并上传 artifact，详见 Actions 页。

## BLE 通信协议

帧格式：`SYNC(0xAA 0x55) | LEN_HI | LEN_LO | CMD | PAYLOAD... | CRC8`
- LEN = CMD(1) + PAYLOAD 字节数（不含 sync/len/crc）
- CRC8 多项式 0x07，初始 0x00，覆盖 LEN_HI..PAYLOAD

| CMD | 方向 | 载荷 |
|---|---|---|
| 0x01 图像分片 | 固件→App | `frame_id u16 LE` `chunk_idx u16 LE` `total_chunks u16 LE` `jpeg_bytes...` |
| 0x02 控制 | App→固件 | `direction i8` `turn i8` `speed_pct u8` |
| 0x03 遥测 | 固件→App | `left_rpm i16` `right_rpm i16` `left_speed_mm_s i16` `right_speed_mm_s i16` `target_speed_mm_s i16` `battery_mv u16` |
| 0x04 下发参数 | App→固件 | `SetParamsPayload` 21 字节：`kp f32 LE` `ki f32 LE` `kd f32 LE` `ramp_ms u32 LE` `wheel_dia_mm u16 LE` `wheel_base_mm u16 LE` `enc_slots u8` |
| 0x05 下发 WiFi | App→固件 | `ssid_len u8` `ssid(ssid_len 字节)` `pass_len u8` `pass(pass_len 字节)`，SSID ≤ 32 / 密码 ≤ 64 |

GATT 服务 UUID：`12345678-1234-5678-1234-56789abcdef0`，三个特征末位 `...def1/def2/def3` 分别对应图像/控制/遥测。MTU 协商 512 字节。`0x04` / `0x05` 复用控制 WRITE 特征 `...def2`，按 CMD 字节分发。

## 控制原理

### 正弦加速
收到前进指令后，目标速度按 `v(t) = V_max × sin(π/2 × min(t/T_ramp, 1))` 从 0 平滑升至 V_max，T_ramp = 1.5s（可调）。

### 直线平衡 PID
10ms（100Hz）控制周期内：
- `error = left_rpm − right_rpm`
- `correction = Kp·e + Ki·∫e + Kd·de/dt`
- 左 PWM 减 correction/2、右 PWM 加 correction/2

参数（`firmware/src/config.h` 可调）：Kp=0.8, Ki=0.05, Kd=0.1。

### 测速
- IR 中断累加脉冲，10ms 窗口统计
- `RPM = (pulses × 60) / (window_sec × ENCODER_SLOTS)`
- `v_mm_s = π × WHEEL_DIAMETER_MM × RPM / 60`
- `ω_rad_s = (v_right − v_left) / WHEEL_TRACK_MM`

## 多线程架构
| 任务 | 核心 | 栈 | 职责 |
|---|---|---|---|
| camera_task | 1 | 8192 | OV2640 抓帧 QVGA@quality5 入队列 |
| speed_task | 1 | 4096 | IR 中断 → RPM/速度 |
| motor_task | 0 | 4096 | 正弦加速 + PID 10ms 周期 |
| ble_task | 0 | 8192 | BLE GATT + 图像分片 + 遥测 NOTIFY |

## App UI 结构

App 采用状态驱动的顶层路由，不再使用底部 `NavigationBar` 多 tab：

- **入口 / 设备连接页**（`DeviceConnectionScreen` / `devices_screen.dart`）：应用启动后默认进入此页。扫描 BLE 设备 → 列表点选连接 → 连接后显示已连接设备并提供「断开」按钮。UI 按 `BleState.status` 分支（disconnected / scanning / connecting / connected / reconnecting）。
- **控制页**（`ControlScreen` / `control_screen.dart`）：BLE 连接成功后自动进入。横屏布局（`landscapeLeft` / `landscapeRight`）：左侧摄像头预览（`camera_viewport`）+ HUD 遥测覆盖层，右侧单摇杆（`joystick`）+ 紧急停车按钮。离开该页时恢复全方向，设备连接页 / 设置页允许竖屏。
- **设置页**（`SettingsScreen` / `settings_screen.dart`）：不再作为底部 tab，而是通过设备连接页或控制页 AppBar 的 `PopupMenuButton`（菜单 → 设置）以命名路由 `/settings` 进入。提供 PID 参数（Kp/Ki/Kd）/ 物理参数（ramp_ms / 轮径 / 轮距 / 编码器槽数）表单 + WiFi 配置段（SSID / 密码）+ 外观切换（系统/浅色/深色 `SegmentedButton`）。

路由切换由 `main.dart` 中的 `_AppRouter` 根据 `bleControllerProvider.select((s) => s.status)` 驱动：`status == connected` → `ControlScreen`，其余状态 → `DeviceConnectionScreen`。

### 设备参数下发

1. 在设备连接页扫描并连接到小车（状态变为 connected）。
2. 通过 AppBar 菜单进入设置页，调整 PID / 物理参数。
3. 点「保存」按钮：
   - BLE 未连接时按钮禁用，提示「请先连接设备」。
   - 已连接时通过 `BleController.sendParams` 下发 `CMD_SET_PARAMS=0x04`，SnackBar 提示「已保存到设备」。
4. 设备 `ble_task.cpp` `onWrite` 收到 0x04 后调 `motor_set_pid` / `motor_set_ramp` / `motor_set_physical` / `speed_sensor_set_physical`（运行时立即生效）+ `params_store_save_*` 写 NVS。重启后仍生效（首次启动无 NVS 时回退 `config.h` 宏默认）。

### WiFi 配置下发

1. 在设备连接页连接到小车。
2. 通过 AppBar 菜单进入设置页的「WiFi 配置」段，填 SSID 与密码（SSID ≤ 32 / 密码 ≤ 64）。
3. 点「下发到设备」按钮：
   - BLE 未连接时按钮禁用，提示「请先连接设备」。
   - 已连接时通过 `BleController.sendWifiConfig` 下发 `CMD_SET_WIFI=0x05`，SnackBar 提示「WiFi 配置已下发到设备」。
4. 设备写 NVS 存储。**注意**：当前固件仅存储 WiFi 配置，不主动连接（预留后续扩展）。

## App 操作模式
- **手机端**：单摇杆控制；`tilt_controller.dart` 与 `keyboard_controller.dart` 保留在 `app/lib/input/`，可在控制页按需接入作为可选输入方式（当前默认仅摇杆）。
- **桌面端**：单摇杆控制；可接入 WASD 键盘控制（`keyboard_controller.dart`）。
- 紧急停车按钮：立即发送 stop 指令

## 开发规范
- Rust 侧：纯函数优先，函数式风格，适量中文注释
- Flutter 侧：Material Design 3，Riverpod 状态管理
- 固件：FreeRTOS 多任务，volatile + critical section 保护共享数据
- 提交：遵循 Conventional Commits

## 许可
见 [LICENSE](LICENSE)。
