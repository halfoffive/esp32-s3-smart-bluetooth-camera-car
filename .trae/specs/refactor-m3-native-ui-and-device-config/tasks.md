# Tasks

> Spec: `.trae/specs/refactor-m3-native-ui-and-device-config/spec.md`
> 依赖：基线 `apply-m3-default-theme-and-ci-gates` 已完成（M3 默认配色 + 深浅色 + clippy 门槛）。

## Batch 1：字体与 M3 原生组件（纯前端，可并行，互不依赖）

- [x] Task 1: 移除自定义字体引用，改用 M3 textTheme 角色
  - [ ] 1.1 `app/lib/ui/theme.dart`：`AppTheme.mono()` 的 `fontFamily: 'Roboto Mono'` 改为 `fontFamily: 'monospace'`（系统等宽 fallback）；`fontFamilyFallback` 保留；保留 `mono()` 薄封装供等宽数值用
  - [ ] 1.2 `app/lib/ui/telemetry_panel.dart`：`_cell` / `_batteryCell` 标签的 `fontFamily: 'Inter'` 删除，改 `Theme.of(context).textTheme.labelSmall`；数值用 `AppTheme.mono()` 或 `textTheme.titleMedium`
  - [ ] 1.3 `app/lib/ui/camera_viewport.dart`：HUD 速度数字 / FPS 芯片字样保持 `AppTheme.mono()`（已等宽 fallback），不再依赖未声明字体；确认无 `'Inter'` / `'Roboto Mono'` 残留
  - 验证：`grep -rn "Roboto Mono\|'Inter'" app/lib` 无输出；浅色/深色下数值字形一致

- [x] Task 2: UI 控件归一为 M3 原生类型（不动 NavigationBar 结构）
  - [ ] 2.1 `app/lib/ui/control_panel.dart`：「紧急停车」保留 `FilledButton` + `colorScheme.error` 背景（语义危险）；模式切换继续 `SegmentedButton`；移除任何自定义 `InputDecoration.border` / `fillColor`（若 `settings_screen` 内有则一并清掉）
  - [ ] 2.2 `app/lib/ui/settings_screen.dart`：`_numField` 的 `InputDecoration` 改为 M3 默认（删除 `filled` / `fillColor` / 自定义 `border`），仅保留 `labelText`
  - 验证：`flutter analyze` 通过；控件外观为 M3 默认 outline

## Batch 2：NavigationBar + 设备页（依赖 Batch 1 完成）

- [x] Task 3: `HomeScreen` 改 NavigationBar 三 tab（依赖 Task 1/2）
  - [ ] 3.1 `app/lib/main.dart`：`HomeScreen` 改为 `Scaffold` + `NavigationBar`（destinations: 驾驶 / 设备 / 设置）+ `IndexedStack` 持有三个子页（不重建）；移除 `routes: {'/settings': ...}` 与 AppBar 的设置 `IconButton`（改由 NavigationBar 进入设置 tab）
  - [ ] 3.2 驾驶 tab = `Column(CameraViewport, TelemetryPanel, ControlPanel)`（保留现有 flex 比例）
  - [ ] 3.3 设置 tab = `SettingsScreen()`（去掉 `Scaffold.appBar`，由父 `HomeScreen` 提供或自留 AppBar——实现时择一，保持 M3 一致性）
  - 验证：切换 tab 不丢摄像头/连接状态；默认进入「驾驶」

- [x] Task 4: 新增 `app/lib/ui/devices_screen.dart`（依赖 Task 3）
  - [ ] 4.1 新建 `DevicesScreen extends ConsumerWidget`：`Scaffold(appBar: AppBar(title: Text('设备')), body: ...)`
  - [ ] 4.2 body 按 `ref.watch(bleControllerProvider).status` 分支：
    - `scanning` / 顶部 `LinearProgressIndicator` + 「扫描中...」`Text`
    - 否则 `FilledButton.icon('扫描设备', icon: Icons.bluetooth_searching)` 居顶；扫描中禁用
  - [ ] 4.3 已发现设备列表 `ListView`：每项 `ListTile(title: 设备名, subtitle: 设备 ID, trailing: FilledTonalButton('连接'))`；点击「连接」→ `ref.read(bleControllerProvider.notifier).connect(device)`
  - [ ] 4.4 已连接卡片 `Card`：`status == connected` 时显示设备名 + ID + `OutlinedButton('断开')` → `disconnect()`
  - [ ] 4.5 `errorMessage != null` 时 `ScaffoldMessenger` 弹 `SnackBar(content: Text(错误文案))`；文案转译为用户可读（不直接吐异常）
  - 验证：首次进入点「扫描设备」→ 5s 后列表出现或 SnackBar 提示；点击「连接」→ 状态变 connected + 卡片出现

## Batch 3：BLE 协议扩展 + Rust 编码（与 Batch 4 并行）

- [x] Task 5: Rust 侧新增协议常量 + 编码函数
  - [ ] 5.1 `app/rust/src/ble.rs`：新增 `pub const CMD_SET_PARAMS: u8 = 0x04;` / `pub const CMD_SET_WIFI: u8 = 0x05;`；新增 `SetParamsPayload` 结构（Kp/Ki/Kd f32 + T_ramp_ms u32 + wheel_diameter_mm u16 + wheel_base_mm u16 + encoder_slots u8）；`PacketKind` 暂不扩展解析（设备→App 不回这两个 CMD）
  - [ ] 5.2 `app/rust/src/control.rs`：新增 `encode_set_params(kp: f32, ki: f32, kd: f32, ramp_ms: u32, wheel_diameter_mm: u16, wheel_base_mm: u16, encoder_slots: u8) -> Result<Vec<u8>, String>`，载荷 21 字节小端；新增 `encode_set_wifi(ssid: String, password: String) -> Result<Vec<u8>, String>`，载荷 = `ssid_len(u8) + ssid + pass_len(u8) + pass`，SSID > 32 / 密码 > 64 返回 `Err`
  - [ ] 5.3 `app/rust/src/api.rs`：`pub use crate::control::{encode_set_params, encode_set_wifi};`（重导出供 frb codegen 扫描）
  - 验证：`cd app/rust && cargo clippy --all-features -- -D warnings` 退出 0；`cargo test`（如有）通过；单测：`encode_set_params(0.8, 0.05, 0.1, 1500, 65, 130, 20)` 生成 27 字节帧 + CRC 正确

- [x] Task 6: Flutter 侧 BLE 控制器新增下发方法（依赖 Task 5 codegen 产物）
  - [ ] 6.1 执行 `flutter_rust_bridge_codegen generate` 重新生成 Dart 绑定
  - [ ] 6.2 `app/lib/ble/ble_controller.dart`：新增 `Future<void> sendParams({required double kp, required double ki, required double kd, required int rampMs, required int wheelDiameterMm, required int wheelBaseMm, required int encoderSlots})`，校验 `status==connected`，调 `control_rust.encodeSetParams(...)` 编码后写控制特征
  - [ ] 6.3 新增 `Future<void> sendWifiConfig({required String ssid, required String password})`，同理用 `encodeSetWifi`
  - 验证：`flutter analyze` 通过；方法签名与 Rust 对齐

## Batch 4：固件 NVS + 运行时参数 + CMD 分发（与 Batch 3 并行）

- [x] Task 7: 新增 `firmware/src/wifi_config.{h,cpp}` + NVS 常量
  - [ ] 7.1 `firmware/src/config.h`：新增 `#define WIFI_NVS_NAMESPACE "wifi_cfg"` / `#define WIFI_NVS_KEY_SSID "ssid"` / `#define WIFI_NVS_KEY_PASS "pass"`；新增 `#define PARAMS_NVS_NAMESPACE "params"` / `#define PARAMS_NVS_KEY_KP "kp"` / `..._KI` / `..._KD` / `..._RAMP_MS` / `..._WHEEL_DIA` / `..._WHEEL_BASE` / `..._ENC_SLOTS`
  - [ ] 7.2 新建 `firmware/src/wifi_config.h`：`bool wifi_config_set(const char* ssid, const char* pass);` / `bool wifi_config_get(char* ssid_out, size_t ssid_cap, char* pass_out, size_t pass_cap);` / `void wifi_config_clear();`
  - [ ] 7.3 新建 `firmware/src/wifi_config.cpp`：基于 `Preferences.h`（Arduino-ESP32 内置）实现 NVS 读写；SSID/密码以长度前缀字符串存（或直接 `putString`/`getString`）
  - 验证：`pio run -d firmware -e esp32s3-ci` 编译通过；`wifi_config_get` 在未设置时返回 false（调用方回退默认）

- [x] Task 8: `motor_task` / `speed_sensor` 运行时参数 + NVS 加载（依赖 Task 7 常量）
  - [ ] 8.1 `firmware/src/motor_task.cpp`：`PID_KP/KI/KD` / `T_RAMP_MS` 改 `static volatile float g_kp / g_ki / g_kd` / `static volatile uint32_t g_ramp_ms`；新增 `void motor_set_pid(float kp, float ki, float kd)` / `void motor_set_ramp(uint32_t ms)`；`motor_init()` 末尾从 NVS 加载已存值（无则用 `config.h` 宏）；控制循环用运行时变量替代宏
  - [ ] 8.2 `firmware/src/motor_task.h`：导出 `motor_set_pid` / `motor_set_ramp` / `motor_set_physical(uint16_t wheel_dia_mm, uint16_t wheel_base_mm, uint8_t enc_slots)`
  - [ ] 8.3 `firmware/src/speed_sensor.{cpp,h}`：核实当前是否直接用 `WHEEL_DIAMETER_MM` / `WHEEL_TRACK_MM` / `ENCODER_SLOTS` 宏；若是，改为运行时变量 + setter + `speed_sensor_init()` 从 NVS 加载
  - 8.4 新建 `firmware/src/params_store.{h,cpp}`（或合并入 `wifi_config`）：`params_store_load_pid(float* kp, float* ki, float* kd, uint32_t* ramp_ms)` / `params_store_save_pid(...)` / 物理参数同理
  - 验证：`pio run -d firmware -e esp32s3-ci` 编译通过；首次启动（NVS 空）行为与当前一致；下发后 `motor_set_pid` 生效

- [x] Task 9: `ble_task.cpp` `onWrite` 新增 CMD 分发（依赖 Task 7/8）
  - [ ] 9.1 `firmware/src/protocol.h`：新增 `#define CMD_SET_PARAMS 0x04` / `#define CMD_SET_WIFI 0x05`；新增 `#pragma pack(push,1) struct SetParamsPayload { float kp; float ki; float kd; uint32_t ramp_ms; uint16_t wheel_dia_mm; uint16_t wheel_base_mm; uint8_t enc_slots; };`（21 字节，`PROTO_STATIC_ASSERT` 校验）；新增 `SetWifiPayload` 长度前缀结构（或直接按偏移解析）
  - [ ] 9.2 `firmware/src/ble_task.cpp` `ControlCharacteristicCallbacks::onWrite`：`proto_validate` 通过后按 `buf[4]`（CMD）分发：`CMD_CONTROL` 走现有 `proto_parse_control` + `motor_set_target`；`CMD_SET_PARAMS` 校验 `proto_len == 1+21`，`memcpy` 出 `SetParamsPayload`，调 `motor_set_pid` + `motor_set_ramp` + `motor_set_physical` + `params_store_save_*`；`CMD_SET_WIFI` 解析 `ssid_len + ssid + pass_len + pass`，调 `wifi_config_set`；其它 CMD 丢弃
  - [ ] 9.3 `firmware/src/main.cpp` `setup()`：`ble_init()` 后无需改动（CMD 分发在 onWrite 内部）
  - 验证：`pio run -d firmware -e esp32s3-ci` 编译通过；下发 `CMD_SET_PARAMS` 后 `motor_set_pid` 被调用；下发 `CMD_SET_WIFI` 后 NVS 有 `ssid` / `pass` 键

## Batch 5：设置页下发设备 + WiFi 段（依赖 Batch 2 + Batch 3）

- [x] Task 10: `settings_screen.dart` 改造（依赖 Task 3 + Task 6）
  - [ ] 10.1 移除顶部「仅本地保存」说明卡片（含 `Icons.info_outline` 整块）
  - [ ] 10.2 PID/物理参数「保存」按钮：BLE 未连接时 `onPressed: null`（禁用）+ 下方 `Text('请先连接设备')`；已连接时调用 `ref.read(bleControllerProvider.notifier).sendParams(...)`，成功后 SnackBar「已保存到设备」
  - [ ] 10.3 新增「WiFi 配置」段：SSID `TextFormField` + 密码 `TextFormField`（`obscureText: true`）+ 「下发到设备」`FilledButton`；BLE 未连接时禁用 + 提示；SSID/密码非空校验；调用 `sendWifiConfig(ssid, password)`，成功后 SnackBar「WiFi 配置已下发到设备」
  - 验证：未连接时按钮禁用 + 提示可见；已连接时下发成功 + SnackBar；WiFi 段表单校验生效

## Batch 6：文档与提交（依赖全部）

- [x] Task 11: 更新 `AGENTS.md` / `README.md` / `CHANGELOG.md`
  - [ ] 11.1 `AGENTS.md`「用户强制风格」Flutter 侧补充：M3 原生组件（`FilledButton` / `FilledTonalButton` / `OutlinedButton` / `TextButton` / `NavigationBar` / `SegmentedButton` / M3 默认 `TextField` outline）；默认字体（不引入第三方字体包，等宽用 `'monospace'` fallback）
  - [ ] 11.2 `AGENTS.md`「工具链陷阱」追加：BLE 协议新增 `CMD_SET_PARAMS=0x04` / `CMD_SET_WIFI=0x05` 复用控制 WRITE 特征；固件 PID 改运行时变量 + NVS 持久化（`Preferences.h`）；改 Rust 接口后须重跑 `flutter_rust_bridge_codegen generate`
  - [ ] 11.3 `AGENTS.md`「BLE 关键约定」段：追加 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 载荷格式说明
  - [ ] 11.4 `README.md`：UI 结构改为 NavigationBar 三 tab（驾驶/设备/设置）；新增「设备设置下发」与「WiFi 配置」操作说明；协议表追加 0x04 / 0x05
  - [ ] 11.5 `CHANGELOG.md` `[Unreleased]`：Added（NavigationBar + 设备页 / WiFi 配置 / 设置下发设备 / 固件 NVS + 运行时 PID）、Changed（M3 默认字体替代未声明字体 / 设置页组件归一）、Fixed（扫描连接按钮缺失）
  - 验证：文档与代码一致；`grep` 检查无遗漏

- [ ] Task 12: 分批 git 提交（依赖 Task 1-11，按关注点拆分）
  - [ ] 12.1 `refactor(ui): 移除未声明字体引用，统一用 M3 textTheme 角色`（Task 1）
  - [ ] 12.2 `refactor(ui): 控件归一为 M3 原生类型`（Task 2）
  - [ ] 12.3 `feat(ui): NavigationBar 三 tab + 设备扫描连接页`（Task 3 + 4）
  - [ ] 12.4 `feat(rust): 新增 CMD_SET_PARAMS/CMD_SET_WIFI 编码`（Task 5）
  - [ ] 12.5 `feat(ble): BleController 新增 sendParams/sendWifiConfig`（Task 6）
  - [ ] 12.6 `feat(fw): 新增 wifi_config NVS 模块 + 协议常量`（Task 7）
  - [ ] 12.7 `feat(fw): motor/speed_sensor 运行时参数 + NVS 加载`（Task 8）
  - [ ] 12.8 `feat(fw): ble_task onWrite 新增 CMD_SET_PARAMS/CMD_SET_WIFI 分发`（Task 9）
  - [ ] 12.9 `feat(ui): 设置页下发设备 + WiFi 配置段`（Task 10）
  - [ ] 12.10 `docs: 同步 AGENTS/README/CHANGELOG`（Task 11）
  - 验证：每个 commit 独立可编译；遵循 Conventional Commits；clippy 零警告；`pio run` + `flutter analyze` 通过

# Task Dependencies

- **Batch 1**（Task 1 / Task 2）：纯前端，互不依赖，可并行
- **Batch 2**（Task 3 / Task 4）：依赖 Batch 1；Task 3 → Task 4 顺序
- **Batch 3**（Task 5 / Task 6）：Rust + Dart 控制器，Task 5 → codegen → Task 6
- **Batch 4**（Task 7 / Task 8 / Task 9）：固件；Task 7 → Task 8 → Task 9 顺序
- **Batch 5**（Task 10）：依赖 Batch 2（结构）+ Batch 3（控制器方法）
- **Batch 3 与 Batch 4 可并行**（前端协议层 vs 固件层，接口在 spec 已锁定）
- **Batch 6**（Task 11 / Task 12）：依赖全部前序
