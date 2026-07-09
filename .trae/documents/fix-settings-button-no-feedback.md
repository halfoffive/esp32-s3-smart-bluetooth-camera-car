# Fix: 设置页按钮点击无反馈

## 问题定位

用户报告"设置点了，没反应"。经代码审查定位到 **错误反馈 SnackBar 弹在了不可见的 tab**：

- `devices_screen.dart` 第 31-38 行用 `ref.listen(bleControllerProvider, ...)` 监听 `errorMessage` 变化，通过 `ScaffoldMessenger.of(context)` 弹 SnackBar
- 但 `context` 是 `DevicesScreen.build` 的 context，`ScaffoldMessenger.of` 找到的是 **DevicesScreen 自己的 Scaffold**（第 45 行）
- 当用户在**设置 tab** 点「保存」/「下发到设备」时，`sendParams` / `sendWifiConfig` 失败会写 `errorMessage`，触发 devices_screen 的 ref.listen，SnackBar 弹在 **隐藏的 devices tab**，用户完全看不到 → "点了没反应"

### 次要问题

`ble_controller.dart` 第 525 行 `sendParams` 在 `deviceId == null` 时静默 `return`（不置 errorMessage）。`settings_screen.dart` 第 94 行用 `errorMessage == errBefore` 判断是否成功，此时会误判为成功弹「已保存到设备」SnackBar，实际未下发。

## 修复方案

**把 errorMessage 的 SnackBar 监听从 devices_screen 上移到 HomeScreen 顶层**，用 HomeScreen 的 ScaffoldMessenger 弹 SnackBar，这样无论在哪个 tab 操作都能看到错误反馈。

### 改动 1: `app/lib/main.dart` — HomeScreen 加错误监听

在 `_HomeScreenState.build` 中增加 `ref.listen(bleControllerProvider, ...)`，监听 `errorMessage` 变化，非空且变化时用 `ScaffoldMessenger.of(context)` 弹 SnackBar。HomeScreen 的 Scaffold 是 root Scaffold（第 55 行），SnackBar 在所有 tab 可见。

### 改动 2: `app/lib/ui/devices_screen.dart` — 移除冗余的错误监听

删除第 29-38 行的 `ref.listen(bleControllerProvider, ...)` 块（已上移到 HomeScreen）。`state` 变量的 `cs` 未使用也可清理（保留 `cs` 是 colorScheme，第 27 行，后续仍在用——保留）。

### 改动 3: `app/lib/ble/ble_controller.dart` — sendParams 防御性 errorMessage

第 524-525 行 `deviceId == null` 时改为置 `errorMessage: '设备未连接'` 后 return（与 `status != connected` 分支一致），避免 settings_screen 误判成功。`sendWifiConfig` 第 564-565 行同理。

## 验证

- 设置 tab 点「保存」：BLE 未连接 → 按钮禁用（保持现状）+ 「请先连接设备」提示可见
- 设置 tab 点「保存」：BLE 已连接但下发失败 → SnackBar 显示错误（现在可见）
- 设置 tab 点「保存」：BLE 已连接且成功 → SnackBar 显示「已保存到设备」
- 设备 tab 操作（扫描/连接）的错误也仍由 HomeScreen 统一弹 SnackBar
- `flutter analyze` + CI 通过

## 不做的事

- 不加 loading 指示（async 期间 UI 不阻塞，按钮点击有 FilledButton 自带的 ripple 反馈）
- 不重构 `_save` 的 `errorMessage == errBefore` 判断逻辑（改动 3 修复后该逻辑正确）
- 不改 validate 失败的反馈（TextFormField 的 validator 红字提示是 M3 标准行为，足够）
