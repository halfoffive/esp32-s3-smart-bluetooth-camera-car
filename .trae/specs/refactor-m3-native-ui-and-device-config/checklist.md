# Checklist

> Spec: `.trae/specs/refactor-m3-native-ui-and-device-config/spec.md`

## 字体与 M3 原生组件
- [x] `app/lib/ui/theme.dart` `AppTheme.mono()` 不含 `fontFamily: 'Roboto Mono'`（改为 `'monospace'` 或省略）
- [x] `app/lib/ui/telemetry_panel.dart` 不含 `fontFamily: 'Inter'`
- [x] `grep -rn "Roboto Mono\|'Inter'" app/lib` 无输出
- [x] `pubspec.yaml` 的 `flutter:` 段不含 `fonts:` 声明
- [x] `settings_screen.dart` `_numField` 的 `InputDecoration` 不含自定义 `filled` / `fillColor` / `border`（用 M3 默认 outline）
- [x] `control_panel.dart` 按钮类型符合 M3 角色（`FilledButton` 主 / `FilledTonalButton` 次 / `OutlinedButton` 边界）
- [x] 浅色与深色模式下数值/标签字形一致

## NavigationBar + 设备页
- [x] `app/lib/main.dart` `HomeScreen` 含 `NavigationBar`（驾驶/设备/设置三 destination）
- [x] 切换 tab 用 `IndexedStack`（不重建子页状态）
- [x] 默认进入「驾驶」tab
- [x] `app/lib/main.dart` 不含 `routes: {'/settings': ...}` 与 AppBar 设置 `IconButton`
- [x] `app/lib/ui/devices_screen.dart` 存在
- [x] 设备页含「扫描设备」`FilledButton`，扫描中禁用 + `LinearProgressIndicator`
- [x] 已发现设备 `ListTile` 含设备名 + ID + 「连接」`FilledTonalButton`
- [x] 已连接设备 `Card` 含「断开」`OutlinedButton`
- [x] `errorMessage` 通过 `SnackBar` 显示，文案用户可读（无原始堆栈）

## Rust 协议扩展
- [x] `app/rust/src/ble.rs` 含 `CMD_SET_PARAMS: u8 = 0x04` / `CMD_SET_WIFI: u8 = 0x05`
- [x] `app/rust/src/control.rs` 含 `encode_set_params(...)` 与 `encode_set_wifi(...)` 函数
- [x] `encode_set_params` 载荷 21 字节（f32×3 + u32 + u16×2 + u8）
- [x] `encode_set_wifi` 校验 SSID ≤ 32 / 密码 ≤ 64，超长返回 `Err`
- [x] `app/rust/src/api.rs` `pub use` 重导出两个新函数
- [x] `cd app/rust && cargo clippy --all-features -- -D warnings` 退出码 0
- [x] 已执行 `flutter_rust_bridge_codegen generate` 重新生成 Dart 绑定

## Dart BLE 控制器
- [x] `app/lib/ble/ble_controller.dart` 含 `sendParams(...)` 方法
- [x] `app/lib/ble/ble_controller.dart` 含 `sendWifiConfig({required String ssid, required String password})` 方法
- [x] 两方法调用前校验 `state.status == ConnectionStatus.connected`
- [x] 失败时 `state = state.copyWith(errorMessage: ...)`
- [x] `flutter analyze` 通过

## 固件 NVS + 运行时参数
- [x] `firmware/src/config.h` 含 `WIFI_NVS_NAMESPACE` / `WIFI_NVS_KEY_SSID` / `WIFI_NVS_KEY_PASS` 常量
- [x] `firmware/src/config.h` 含 `PARAMS_NVS_NAMESPACE` 与 PID/物理参数键名常量
- [x] `firmware/src/wifi_config.h` / `wifi_config.cpp` 存在
- [x] `wifi_config_set(ssid, pass)` / `wifi_config_get(...)` / `wifi_config_clear()` 接口存在
- [x] `firmware/src/motor_task.cpp` 用 `static volatile` 运行时 PID 变量替代 `PID_KP/KI/KD` 宏
- [x] `motor_task.h` 导出 `motor_set_pid` / `motor_set_ramp` / `motor_set_physical`
- [x] `motor_init()` 末尾从 NVS 加载已存 PID（无则用 `config.h` 宏默认）
- [x] `speed_sensor` 物理参数改为运行时变量 + setter + NVS 加载（如该模块直接用宏）
- [x] `pio run -d firmware -e esp32s3-ci` 编译通过

## 固件 CMD 分发
- [x] `firmware/src/protocol.h` 含 `CMD_SET_PARAMS 0x04` / `CMD_SET_WIFI 0x05` 常量
- [x] `firmware/src/protocol.h` 含 `SetParamsPayload` 结构（21 字节，`PROTO_STATIC_ASSERT` 校验）
- [x] `firmware/src/ble_task.cpp` `onWrite` 含 `CMD_SET_PARAMS` 分支（校验长度 + `motor_set_pid/ramp/physical` + NVS 保存）
- [x] `firmware/src/ble_task.cpp` `onWrite` 含 `CMD_SET_WIFI` 分支（解析长度前缀 + `wifi_config_set`）
- [x] 未知 CMD 安全丢弃（不崩溃）

## 设置页下发设备 + WiFi 段
- [x] `settings_screen.dart` 不含「仅本地保存」/「未来版本可下发设备」文案
- [x] PID/物理参数「保存」按钮：BLE 未连接时 `onPressed: null` + 提示「请先连接设备」
- [x] 已连接时「保存」调用 `sendParams(...)` + 写 `shared_preferences`
- [x] 成功后 SnackBar「已保存到设备」
- [x] 含「WiFi 配置」段（SSID + 密码 `TextFormField` + 「下发到设备」`FilledButton`）
- [x] WiFi 段 BLE 未连接时禁用 + 提示
- [x] WiFi 下发调用 `sendWifiConfig(ssid, password)`
- [x] 成功后 SnackBar「WiFi 配置已下发到设备」

## 端到端验证
- [x] 设备页扫描 → 发现设备 → 连接 → HUD 显示「已连接」
- [x] 设置页改 PID → 保存 → 设备电机控制行为变化（如积分限幅生效）
- [x] 设置页下发 WiFi → 设备重启 → NVS 中 `ssid` / `pass` 仍可读（固件未主动连 WiFi）
- [x] BLE 断连后设置页「保存」/「下发」按钮禁用
- [x] 浅色/深色 + 系统/浅色/深色主题模式下 UI 一致

## 文档
- [x] `AGENTS.md`「用户强制风格」含 M3 原生组件 + 默认字体约定
- [x] `AGENTS.md`「工具链陷阱」含 BLE 新 CMD + 固件 NVS + frb codegen 重跑约定
- [x] `AGENTS.md`「BLE 关键约定」含 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 载荷格式
- [x] `README.md` UI 结构改为 NavigationBar 三 tab
- [x] `README.md` 协议表含 0x04 / 0x05
- [x] `CHANGELOG.md` `[Unreleased]` 含 Added / Changed / Fixed 三类

## 提交
- [x] 至少 10 个独立 commit，按关注点拆分（字体 / 控件 / NavigationBar / Rust / Dart 控制器 / 固件 NVS / 固件运行时参数 / 固件 CMD 分发 / 设置页 / 文档）
- [x] 每个 commit 遵循 Conventional Commits
- [x] 每个 commit 独立可编译（`pio run` + `flutter analyze` + `cargo clippy` 通过）
- [x] clippy 零警告
