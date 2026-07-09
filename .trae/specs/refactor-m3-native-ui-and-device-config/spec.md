# M3 原生 UI 重构 + 设备设置下发 + WiFi 配置 Spec

## Why

当前 App 存在四个用户可感知的缺陷：
1. **看不到扫描/连接按钮**：`ble_controller.dart` 暴露了 `startScan()` / `connect(device)` / `disconnect()`，但 UI 层没有任何控件调用它们——HUD 只被动显示连接状态，用户永远卡在「未连接」，无法发起扫描或选设备连接。
2. **字体奇怪**：`theme.dart` 的 `AppTheme.mono()` 引用 `'Roboto Mono'`、`telemetry_panel.dart` 标签引用 `'Inter'`，但 `pubspec.yaml` 未声明任何字体资产（`flutter: uses-material-design: true` 只引入 Material 图标），运行时回退到系统默认 + `monospace` fallback，深浅色下数值/标签字形不一致。
3. **设置仅本地**：`settings_screen.dart` 把 PID/物理参数存进 `shared_preferences`，附注「未来版本可下发设备」，从未真正下发；固件 PID 当前是 `config.h` 编译期宏（`PID_KP` / `PID_KI` / `PID_KD` / `T_RAMP_MS`），无运行时覆盖入口。
4. **设备无 WiFi 配置**：固件无 WiFi NVS 存储，未来想做 WiFi 推流 / OTA 升级缺基础设施。

需统一按 Material 3 原生 Flutter（<https://m3.material.io/develop/flutter>）重构 UI，打通「App 设置 → BLE → 设备 NVS」链路，并为设备端新增 WiFi 配置存储（不主动连 WiFi，"以后有用"）。

## What Changes

- **移除自定义字体引用**：删除 `AppTheme.mono()` 的 `fontFamily: 'Roboto Mono'` 与 `telemetry_panel.dart` 标签的 `fontFamily: 'Inter'`；数值/标签一律使用 `Theme.of(context).textTheme` 的 M3 角色（如 `titleMedium` / `labelSmall`）。需要等宽对齐时用 Flutter 内建 `'monospace'` fallback（系统等宽，不引入第三方字体包）。`AppTheme.mono()` 保留为薄封装但不再硬编码字体名。
- **底部 NavigationBar 三 tab**：`HomeScreen` 改为 `Scaffold` + `NavigationBar`（驾驶 / 设备 / 设置），各 tab 为独立页面（不再用 `/settings` 命名路由，统一在 NavigationBar 内切换）。
- **新增设备页 `DevicesScreen`**：含「扫描设备」`FilledButton`、扫描中 `LinearProgressIndicator`、已发现设备 `ListTile` 列表（设备名 + 设备 ID + 「连接」`FilledTonalButton`）、已连接设备 `Card`（含「断开」`OutlinedButton`）、错误信息 `SnackBar`。直接读写 `bleControllerProvider`，调用 `startScan` / `connect` / `disconnect`。
- **M3 原生组件落地**：按钮按 M3 角色区分（`FilledButton` 主操作 / `FilledTonalButton` 次操作 / `OutlinedButton` 边界操作 / `TextButton` 文本操作）；`TextField` 用 M3 默认外观（不自定义 `border` / `fillColor`，保持 `useMaterial3: true` 默认 outline）；列表用 `ListTile` / `Card`；导航用 `NavigationBar`；分段选择继续用 `SegmentedButton`；进度用 `LinearProgressIndicator` / `CircularProgressIndicator`。
- **设置页改造**：移除「仅本地保存」提示文案；PID/物理参数「保存」按钮改为**同时**写 `shared_preferences` + 下发设备（新增 BLE 命令 `CMD_SET_PARAMS=0x04`），BLE 未连接时禁用并提示「请先连接设备」；新增「WiFi 配置」段（SSID `TextFormField` + 密码 `TextFormField` + 「下发到设备」`FilledButton`，仅 BLE 已连接时可点；下发后仅持久化到设备 NVS，不触发 WiFi 连接）。
- **BLE 协议扩展（BREAKING）**：新增命令
  - `CMD_SET_PARAMS=0x04`（App → 固件）：载荷 = `Kp(f32) + Ki(f32) + Kd(f32) + T_ramp_ms(u32) + wheel_diameter_mm(u16) + wheel_base_mm(u16) + encoder_slots(u8)` = 21 字节，固件存 NVS 并更新运行时 PID。
  - `CMD_SET_WIFI=0x05`（App → 固件）：载荷 = `ssid_len(u8) + ssid(≤32) + pass_len(u8) + pass(≤64)`，固件存 NVS（`wifi_ssid` / `wifi_password` 键），不主动连 WiFi。
  - 二者复用现有控制 WRITE 特征（`...cdef2`），不新增 GATT 特征，不影响 image/telemetry NOTIFY 通道。
- **固件 NVS 存储 + 运行时参数**：
  - 新增 `firmware/src/wifi_config.{h,cpp}`：基于 `Preferences.h` 读写 WiFi NVS，暴露 `wifi_config_set(ssid, pass)` / `wifi_config_get(ssid_out, pass_out)` / `wifi_config_clear()`。
  - `motor_task.cpp`：`PID_KP/KI/KD` / `T_RAMP_MS` 改为 `static volatile` 运行时变量，新增 `motor_set_pid(kp, ki, kd)` / `motor_set_ramp(ramp_ms)`；`motor_init()` 启动时从 NVS 加载已存值（无则回退 `config.h` 宏默认）。
  - `speed_sensor.cpp` 同理：`WHEEL_DIAMETER_MM` / `WHEEL_TRACK_MM` / `ENCODER_SLOTS` 改运行时变量 + setter + NVS 加载（如该模块当前直接使用宏——实现阶段核实）。
  - `ble_task.cpp` `ControlCharacteristicCallbacks::onWrite`：在现有 `CMD_CONTROL` 分支外，新增 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 分支，校验长度后调用对应存储/设置接口。
  - `config.h`：新增 NVS 命名空间与键名常量（`NVS_NAMESPACE` / `NVS_KEY_KI` / `NVS_KEY_WIFI_SSID` 等），保留编译期宏作为默认值回退。
- **Rust 侧编码函数**：`app/rust/src/ble.rs` 新增 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 常量与载荷结构；`app/rust/src/control.rs` 新增 `encode_set_params(kp, ki, kd, ramp_ms, wheel_diameter, wheel_base, encoder_slots) -> Vec<u8>` 与 `encode_set_wifi(ssid: String, password: String) -> Vec<u8>`，复用现有 `crc8` + 帧头组装；`app/rust/src/api.rs` `pub use` 重导出。改 Rust 接口后必须 `flutter_rust_bridge_codegen generate`。
- **Dart 侧控制器**：`ble_controller.dart` 新增 `sendParams(...)` / `sendWifiConfig(ssid, password)` 方法，写控制特征；调用前校验 `state.status == connected`，失败时 `errorMessage` 上抛。
- **文档同步**：`AGENTS.md` 追加 M3 原生组件 + 默认字体（不引入第三方字体）+ 协议新 CMD 约定；`README.md` 同步 UI 结构（NavigationBar 三 tab）与新协议命令；`CHANGELOG.md` `[Unreleased]` 归类 Added / Changed / Fixed。

## Impact

- 受影响代码：
  - `app/lib/ui/theme.dart` — `mono()` 不再硬编码 `'Roboto Mono'`，改 `fontFamily: 'monospace'` fallback；新增 `textTheme` 便捷访问的文档/示例（不强制）
  - `app/lib/ui/camera_viewport.dart` — HUD 数值/芯片用 `textTheme` 角色，移除 `AppTheme.mono(fontFamily)` 隐式依赖
  - `app/lib/ui/telemetry_panel.dart` — 移除 `fontFamily: 'Inter'`，数值用 `textTheme.titleMedium`
  - `app/lib/ui/control_panel.dart` — 按钮归一为 M3 类型，移除自定义 `border`/`fillColor`
  - `app/lib/ui/settings_screen.dart` — 新增 WiFi 段 + 下发设备按钮；移除「仅本地」提示；输入框用 M3 默认外观
  - `app/lib/ui/joystick.dart` — 无结构变化（painter 已从 colorScheme 取色）
  - `app/lib/main.dart` — `HomeScreen` 改 `NavigationBar` + IndexedStack 三 tab；移除 `/settings` 命名路由
  - `app/lib/ui/devices_screen.dart` — **新增**（扫描/连接/断开 UI）
  - `app/lib/ble/ble_controller.dart` — 新增 `sendParams` / `sendWifiConfig`
  - `app/rust/src/ble.rs` — 新增 `CMD_SET_PARAMS` / `CMD_SET_WIFI` 常量 + 载荷结构
  - `app/rust/src/control.rs` — 新增 `encode_set_params` / `encode_set_wifi`
  - `app/rust/src/api.rs` — `pub use` 重导出新函数
  - `firmware/src/protocol.h` — 新增 CMD 常量 + `SetParamsPayload` / `SetWifiPayload` 结构
  - `firmware/src/wifi_config.h` / `firmware/src/wifi_config.cpp` — **新增**（NVS 读写）
  - `firmware/src/motor_task.cpp` / `.h` — PID 改运行时变量 + setter + NVS 加载
  - `firmware/src/speed_sensor.cpp` / `.h` — 物理参数改运行时变量 + setter + NVS 加载（实现阶段确认当前是否直接用宏）
  - `firmware/src/ble_task.cpp` — `onWrite` 新增 CMD 分支
  - `firmware/src/config.h` — NVS 命名空间/键名常量 + 保留宏作默认值
  - `AGENTS.md` / `README.md` / `CHANGELOG.md`
- 不影响：BLE 自动重连机制、CRC8 算法、摄像头采集/分片、遥测 NOTIFY 周期、断连紧急停车、MTU 协商
- **BREAKING**：BLE 协议新增 0x04 / 0x05 命令字节；旧版固件收到未知 CMD 会走 `proto_parse_control` 失败分支丢弃（`PacketKind::Unknown`），不会崩溃；但旧 App 无法下发新参数。App 与固件须同步升级。

## ADDED Requirements

### Requirement: Material 3 默认字体 + textTheme 角色
App SHALL 使用 Material 3 默认 `TextTheme`（不引入第三方字体包、不硬编码 `'Roboto Mono'` / `'Inter'` 等未打包字体名）；数值/标签文本通过 `Theme.of(context).textTheme` 角色（如 `titleMedium` / `labelSmall`）取样式，仅当确实需要等宽对齐时使用 `TextStyle(fontFamily: 'monospace')` 系统等宽 fallback。

#### Scenario: 数值字体一致
- **WHEN** 系统切换浅色 / 深色
- **THEN** 遥测面板数值 / HUD 速度数字 / FPS 芯片字形一致
- **AND** 不出现 `'Roboto Mono'` / `'Inter'` 回退到不同字形的情况

#### Scenario: 无未声明字体资产
- **WHEN** 检查 `pubspec.yaml` 的 `flutter:` 段
- **THEN** 不含 `fonts:` 声明
- **AND** `grep -rn "Roboto Mono\|'Inter'" app/lib` 无输出

### Requirement: NavigationBar 三 tab 导航
App SHALL 在 `HomeScreen` 使用 M3 `NavigationBar`，提供「驾驶 / 设备 / 设置」三个目的地；切换不销毁页面状态（`IndexedStack` 持有三个子页），驾驶 tab 保留 `CameraViewport + TelemetryPanel + ControlPanel` 组合。

#### Scenario: 默认进入驾驶 tab
- **WHEN** App 启动
- **THEN** NavigationBar 选中「驾驶」
- **AND** 显示摄像头画面 + 遥测 + 操控面板

#### Scenario: 切换 tab 不丢状态
- **WHEN** 用户在驾驶 tab 连接小车后切到设备 tab 再切回
- **THEN** 摄像头画面 / 遥测 / 操控模式保持原状（不重建）

### Requirement: 设备扫描 / 连接 / 断开 UI
设备页 SHALL 提供：
- 「扫描设备」`FilledButton`，点击调用 `bleControllerProvider.notifier.startScan()`；扫描中按钮禁用并显示 `LinearProgressIndicator`
- 已发现设备列表（`ListTile`，标题=设备名、副标题=设备 ID、trailing=`FilledTonalButton`「连接」），点击「连接」调用 `connect(device)`
- 已连接设备 `Card`（设备名 + 设备 ID + `OutlinedButton`「断开」），点击调用 `disconnect()`
- 扫描失败 / 连接失败 / 重连耗尽时通过 `SnackBar` 显示 `BleState.errorMessage`，文案明确指出下一步（如「未发现设备 ESP32S3_SmartCar，请确认小车已上电」）

#### Scenario: 用户首次发起扫描
- **WHEN** 用户进入设备页点击「扫描设备」
- **THEN** 按钮禁用 + 进度条出现
- **AND** 5 秒后扫描结束，列表显示发现的设备 或 SnackBar 提示未发现

#### Scenario: 用户连接设备
- **WHEN** 列表中点击某设备的「连接」按钮
- **THEN** 状态变 `connecting` → `connected`
- **AND** 已连接卡片出现，列表项消失

#### Scenario: 错误信息可读
- **WHEN** 扫描无果
- **THEN** SnackBar 显示「未发现设备 ESP32S3_SmartCar，请确认小车已上电」
- **AND** 不出现原始异常堆栈

### Requirement: 设置下发设备
设置页 PID/物理参数 SHALL 在「保存」时同时写 `shared_preferences` 与下发设备（BLE 命令 `CMD_SET_PARAMS=0x04`）；BLE 未连接时「保存」按钮禁用并提示「请先连接设备」；下发成功后 SnackBar 显示「已保存到设备」。

#### Scenario: 已连接时保存
- **WHEN** BLE 已连接 + 表单校验通过 + 点击「保存」
- **THEN** 参数写入 `shared_preferences`
- **AND** 通过 BLE 发送 `CMD_SET_PARAMS` 帧到设备
- **AND** SnackBar 显示「已保存到设备」

#### Scenario: 未连接时禁用
- **WHEN** BLE 未连接
- **THEN** 「保存」按钮禁用
- **AND** 按钮下方/附近提示「请先连接设备」

### Requirement: 设备 WiFi 配置存储
设置页 SHALL 提供 WiFi 配置段（SSID + 密码 `TextFormField` + 「下发到设备」`FilledButton`）；下发时通过 BLE 命令 `CMD_SET_WIFI=0x05` 发送到设备；设备固件 SHALL 将 SSID/密码存入 NVS（键 `wifi_ssid` / `wifi_password`），不主动发起 WiFi 连接（"以后有用"）。仅 BLE 已连接时可下发。

#### Scenario: 下发 WiFi 配置
- **WHEN** BLE 已连接 + SSID/密码非空 + 点击「下发到设备」
- **THEN** App 通过 BLE 发送 `CMD_SET_WIFI` 帧
- **AND** 固件将 SSID/密码写入 NVS
- **AND** SnackBar 显示「WiFi 配置已下发到设备」

#### Scenario: 设备重启后配置保留
- **WHEN** 设备下发 WiFi 配置后断电重启
- **THEN** NVS 中 `wifi_ssid` / `wifi_password` 仍可读
- **AND** 固件未发起 WiFi 连接（当前阶段仅存储）

#### Scenario: 未连接时禁用
- **WHEN** BLE 未连接
- **THEN** WiFi「下发到设备」按钮禁用
- **AND** 提示「请先连接设备」

### Requirement: BLE 协议新增 CMD_SET_PARAMS / CMD_SET_WIFI
协议 SHALL 新增两个命令字节：
- `CMD_SET_PARAMS = 0x04`，载荷 = `Kp(f32) + Ki(f32) + Kd(f32) + T_ramp_ms(u32) + wheel_diameter_mm(u16) + wheel_base_mm(u16) + encoder_slots(u8)` = 21 字节，多字节小端
- `CMD_SET_WIFI = 0x05`，载荷 = `ssid_len(u8) + ssid(≤32B) + pass_len(u8) + pass(≤64B)`，长度可变
- 二者复用现有控制 WRITE 特征（UUID `...cdef2`），帧格式遵循现有 `SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD CRC8`
- 固件 `onWrite` 校验 `proto_validate` 通过后按 CMD 分发；载荷长度不符则丢弃

#### Scenario: 参数帧校验
- **WHEN** App 发送 `CMD_SET_PARAMS` 帧
- **THEN** 帧总长 = 5（头）+ 21（载荷）+ 1（CRC）= 27 字节
- **AND** CRC 覆盖 `LEN_HI..PAYLOAD` 末字节

#### Scenario: WiFi 帧长度可变
- **WHEN** SSID="MyHome" (6B) + 密码="12345678" (8B)
- **THEN** 载荷 = 1+6+1+8 = 16 字节
- **AND** 帧总长 = 5 + 16 + 1 = 22 字节

#### Scenario: 超长 SSID/密码被拒绝
- **WHEN** SSID 长度 > 32 或密码长度 > 64
- **THEN** Rust `encode_set_wifi` 返回 `Err`
- **AND** App 不发送该帧，显示校验错误

### Requirement: 固件运行时 PID 参数 + NVS 持久化
固件 SHALL 将 `PID_KP/KI/KD` / `T_RAMP_MS` 改为运行时可变（`static volatile` + setter），`motor_init()` 启动时从 NVS 加载已存值（无则用 `config.h` 宏默认）；收到 `CMD_SET_PARAMS` 时更新运行时变量 + 写 NVS。物理参数（`WHEEL_DIAMETER_MM` / `WHEEL_TRACK_MM` / `ENCODER_SLOTS`）同理。

#### Scenario: 首次启动用默认值
- **WHEN** NVS 中无 PID 键
- **THEN** 运行时 PID = `config.h` 宏默认值
- **AND** 电机控制行为与当前一致

#### Scenario: 下发后立即生效
- **WHEN** App 下发 `Kp=1.5`
- **THEN** 电机任务下一控制周期使用 `g_kp=1.5`
- **AND** NVS 中 `pid_kp` = 1.5

#### Scenario: 重启后恢复
- **WHEN** 下发参数后断电重启
- **THEN** `motor_init()` 从 NVS 读回 `pid_kp=1.5`
- **AND** 控制行为使用上次下发的值

## MODIFIED Requirements

### Requirement: Flutter UI 风格
Flutter 侧 SHALL 使用 Material Design 3 默认配色（`useMaterial3: true`，不设 `colorSchemeSeed`）与**默认字体**（不引入第三方字体包、不硬编码未打包字体名）；结构色一律取自 `Theme.of(context).colorScheme`；状态语义色（正常/警告/危险）使用 Material 默认色（`Colors.green` / `Colors.amber` / `colorScheme.error`），由 `HudStatus` 承载。组件类型按 M3 角色区分（`FilledButton` 主操作 / `FilledTonalButton` 次操作 / `OutlinedButton` 边界操作 / `TextButton` 文本操作），`TextField` 用 M3 默认 outline 外观不自定义 `border` / `fillColor`。Riverpod 状态管理。导航用 `NavigationBar`。

#### Scenario: UI 跟随主题
- **WHEN** 系统切换浅色/深色
- **THEN** 所有面板 / 摇杆 / HUD / 输入框结构色随 `ColorScheme` 变化
- **AND** 字形一致（无未声明字体回退差异）

## REMOVED Requirements

### Requirement: 自定义未打包字体引用
**Reason**: `'Roboto Mono'` / `'Inter'` 未在 `pubspec.yaml` 声明资产，运行时回退导致字形不一致
**Migration**: `AppTheme.mono()` 保留为薄封装但 `fontFamily` 改为 `'monospace'`（系统等宽 fallback）或省略；调用方优先改用 `Theme.of(context).textTheme.titleMedium` 等 M3 角色

### Requirement: 「参数仅本地保存」提示文案
**Reason**: 设置已能下发设备，「仅本地」提示不再准确
**Migration**: 移除 `settings_screen.dart` 顶部说明卡片中的「未来版本可下发设备」文案；改由按钮禁用状态 + 提示「请先连接设备」表达
