# UI 动画优化 + 蓝牙权限修复 Spec

## Why

当前 App 存在三个影响体验的短板：
1. **启动与转场生硬**：`_AppRouter` 直接 `if/return` 切换页面，无过渡动画；设置页由 `Navigator.pushNamed` 默认跳转，缺乏与当前 FPV 遥控主题契合的动效语言。
2. **缺少蓝牙权限请求**：`ble_controller.dart` 在 `startScan()` / `connect()` 前未校验或申请平台蓝牙权限，Android 6+ / iOS 13+ 会直接失败或抛异常；用户看不到清晰的权限引导。
3. **未提示开启蓝牙**：未监听 `FlutterBluePlus.adapterState`，若系统蓝牙关闭，用户点击「扫描设备」后没有提示去设置里打开。

本改动将引入一套受 FPV/遥控台启发的动效语言，并补齐 BLE 权限与适配器状态检查，让连接流程更顺畅、可控。

## What Changes

- **新增启动页 `_SplashScreen`**：在 `SmartCarApp` 初始化完成后短暂展示（约 1.2s），含 logo 缩放 + 进度条淡入；结束后进入 `_AppRouter`。启动错误仍优先显示 `_InitErrorScreen`。
- **页面转场动画**：
  - `_AppRouter` 在 `DeviceConnectionScreen` ↔ `ControlScreen` 之间使用自定义 `PageRouteBuilder`（横向滑动 + 淡入淡出，模拟切换控制台界面）。
  - 设置页从底部滑入（`SlideTransition` from bottom），返回时滑出，符合移动端表单页习惯。
- **设备页动效**：
  - 扫描按钮按下缩放回弹。
  - 扫描时展示「雷达脉冲」动画（同心圆环扩散），替代生硬的 `LinearProgressIndicator` 单一条；进度条仍保留作为辅助。
  - 已发现设备列表项 stagger 淡入上移。
  - 已连接设备卡片从顶部滑入 + 淡入。
- **控制页动效**：
  - `CameraViewport` 首次收到画面时由 0.85 缩放到 1.0 淡入。
  - HUD 元素（连接状态、FPS、速度、四角 bracket）在页面进入后 stagger 淡入。
  - 摇杆 touched 时底圆环加粗 + 拇指圆放大 1.08x，释放弹性回中。
- **设置页动效**：
  - 表单字段 stagger 淡入。
  - 保存 / 下发按钮启用/禁用时颜色与透明度渐变。
- **蓝牙权限请求**：新增 `lib/ble/ble_permissions.dart`，封装：
  - Android：`Permission.bluetoothScan`、`Permission.bluetoothConnect`、适配 Android 11 以下补充 `Permission.location`。
  - iOS / macOS：`Permission.bluetooth`。
  - Linux / Windows：无需运行时权限，直接返回 granted。
  - 拒绝时弹出解释性 `AlertDialog`，引导用户去系统设置开启。
- **蓝牙适配器状态监听**：`BleController` 在构造时订阅 `FlutterBluePlus.adapterState`；若蓝牙关闭：
  - 设备页显示「蓝牙已关闭」横幅 + 「去开启」`TextButton`，点击调用 `FlutterBluePlus.turnOn()`（Android）或跳转设置（iOS）。
  - 点击「扫描设备」时若蓝牙未开启，先弹 `SnackBar` 提示开启，不发起扫描。
- **依赖变更**：新增 `permission_handler: ^11.3.1` 到 `pubspec.yaml`。
- **文档同步**：更新 `AGENTS.md` 追加 BLE 权限请求约定；`CHANGELOG.md` `[Unreleased]` 归类 Added / Changed / Fixed。

## Impact

- 受影响代码：
  - `app/lib/main.dart` — 新增 `_SplashScreen`，`_AppRouter` 改用动画过渡。
  - `app/lib/ui/devices_screen.dart` — 扫描雷达动画、列表 stagger、连接卡片滑入、蓝牙关闭横幅。
  - `app/lib/ui/control_screen.dart` — 页面转场、菜单/设置页转场包装。
  - `app/lib/ui/camera_viewport.dart` — 画面首次到达缩放淡入、HUD stagger。
  - `app/lib/ui/joystick.dart` — 触摸反馈缩放/加粗。
  - `app/lib/ui/settings_screen.dart` — 表单 stagger、按钮启用渐变。
  - `app/lib/ble/ble_permissions.dart` — **新增**（权限请求/解释对话框）。
  - `app/lib/ble/ble_controller.dart` — 监听 adapterState、扫描前权限校验、蓝牙关闭提示。
  - `app/pubspec.yaml` — 新增 `permission_handler`。
  - `app/android/app/src/main/AndroidManifest.xml`（CI 生成后 patch）— 添加 BLUETOOTH_SCAN / BLUETOOTH_CONNECT / ACCESS_FINE_LOCATION 权限。
  - `AGENTS.md` / `CHANGELOG.md`
- 不影响：BLE 帧协议、Rust 编码函数、固件协议、PID/WiFi 下发逻辑、自动重连机制。
- **BREAKING**：无。

## ADDED Requirements

### Requirement: 启动页动效
App SHALL 在初始化完成后展示约 1.2 秒的启动页，包含应用图标缩放动画与进度条/副标题淡入；启动失败时直接显示 `_InitErrorScreen`。

#### Scenario: 正常启动
- **WHEN** Rust 桥接与主题加载成功
- **THEN** 显示 `_SplashScreen` 1.2s
- **AND** 图标由 0.8 → 1.0 缩放（easeOutBack）
- **AND** 副标题与进度条淡入
- **AND** 结束后进入 `_AppRouter`

#### Scenario: 启动失败
- **WHEN** Rust 桥接初始化失败
- **THEN** 不显示启动页，直接显示 `_InitErrorScreen`

### Requirement: 页面转场动画
App SHALL 为 `_AppRouter` 的页面切换与设置页导航提供一致动效：设备页↔控制页使用横向滑动+淡入；设置页从底部滑入/滑出。

#### Scenario: 连接成功后进入控制页
- **WHEN** `BleState.status` 由非 connected 变为 connected
- **THEN** `ControlScreen` 从右向左滑入，同时旧页面淡出
- **AND** 动画时长 300ms

#### Scenario: 断开后回到设备页
- **WHEN** `BleState.status` 由 connected 变为非 connected（用户主动断开或重连耗尽）
- **THEN** `DeviceConnectionScreen` 从左向右滑入
- **AND** 动画时长 300ms

#### Scenario: 打开设置页
- **WHEN** 用户点击 AppBar 菜单「设置」
- **THEN** `SettingsScreen` 从底部向上滑入
- **AND** 返回时向下滑出

### Requirement: 设备页扫描动效
设备页 SHALL 在扫描时展示雷达脉冲动画；已发现设备列表项 stagger 进入；已连接设备卡片滑入。

#### Scenario: 开始扫描
- **WHEN** 用户点击「扫描设备」
- **THEN** 按钮短暂缩小回弹
- **AND** 雷达脉冲圆环从中心向外扩散（3 个环，依次 0.8s）
- **AND** `LinearProgressIndicator` 同时显示

#### Scenario: 发现设备
- **WHEN** 扫描到设备并加入列表
- **THEN** 新列表项从下方 16px 处淡入上移，持续 250ms
- **AND** 多项依次延迟 60ms

#### Scenario: 连接成功
- **WHEN** 状态变为 connected
- **THEN** 已连接卡片从顶部 -40px 滑入并淡入
- **AND** 列表项同步淡出或被卡片替换

### Requirement: 控制页动效
控制页 SHALL 在画面首次到达与 HUD 元素进入时提供平滑动画；摇杆提供触摸反馈。

#### Scenario: 画面首次到达
- **WHEN** `frameStreamProvider` 从 loading 变为 data
- **THEN** 画面由 scale 0.95、opacity 0 动画到 scale 1.0、opacity 1
- **AND** 时长 300ms

#### Scenario: HUD 进入
- **WHEN** 进入控制页
- **THEN** 四角 bracket、连接芯片、FPS 芯片、速度数字依次淡入
- **AND** stagger 间隔 80ms

#### Scenario: 摇杆触摸反馈
- **WHEN** 用户按下摇杆
- **THEN** 底圆环宽度由 1.5 → 3.0
- **AND** 拇指圆放大至 1.08x
- **AND** 释放时弹性回中

### Requirement: 设置页动效
设置页 SHALL 在表单进入时提供 stagger 淡入；保存/下发按钮启用状态变化时平滑过渡。

#### Scenario: 进入设置页
- **WHEN** 设置页从底部滑入完成
- **THEN** 表单各段（外观、PID、物理参数、WiFi）依次从下方 12px 淡入
- **AND** stagger 间隔 50ms

#### Scenario: 连接状态变化
- **WHEN** BLE 连接状态由 connected 变为 disconnected
- **THEN** 「保存」/「下发到设备」按钮在 200ms 内渐变到禁用样式

### Requirement: 蓝牙权限请求
App SHALL 在发起 BLE 扫描或连接前请求平台所需权限；拒绝时给出解释并引导用户去系统设置开启。

#### Scenario: Android 首次扫描
- **WHEN** 用户点击「扫描设备」（Android 12+）
- **THEN** 先请求 `bluetoothScan` 与 `bluetoothConnect`
- **AND** 授予后继续扫描
- **AND** 拒绝时弹出对话框说明「需要蓝牙权限以发现小车」并提供「去设置」按钮

#### Scenario: Android 11 及以下扫描
- **WHEN** 用户点击「扫描设备」（Android 11 及以下）
- **THEN** 额外请求 `location` 权限
- **AND** 授予后继续扫描

#### Scenario: iOS 首次扫描
- **WHEN** 用户点击「扫描设备」（iOS）
- **THEN** 请求 `bluetooth` 权限
- **AND** 授予后继续扫描

#### Scenario: 权限永久拒绝
- **WHEN** 权限状态为 `permanentlyDenied`
- **THEN** 显示解释对话框
- **AND** 点击「去设置」调用 `openAppSettings()`

### Requirement: 蓝牙适配器状态检查
App SHALL 监听系统蓝牙开关状态；蓝牙关闭时阻止扫描并提示用户开启。

#### Scenario: 蓝牙关闭时点击扫描
- **WHEN** 系统蓝牙关闭且用户点击「扫描设备」
- **THEN** 不发起扫描
- **AND** `SnackBar` 提示「蓝牙已关闭，请先开启蓝牙」

#### Scenario: 蓝牙关闭横幅
- **WHEN** 进入设备页且蓝牙关闭
- **THEN** 页面顶部显示 Material Banner：「蓝牙已关闭」+ 「开启蓝牙」按钮
- **AND** Android 上点击按钮调用 `FlutterBluePlus.turnOn()`
- **AND** iOS 上点击按钮跳转系统设置

#### Scenario: 蓝牙恢复
- **WHEN** 用户开启系统蓝牙
- **THEN** 横幅自动消失
- **AND** 设备页恢复可扫描状态

## MODIFIED Requirements

### Requirement: 蓝牙扫描流程
`BleController.startScan()` SHALL 在真正调用 `FlutterBluePlus.startScan()` 前先通过 `BlePermissions.requestAll()` 确认权限已授予且适配器状态为 `on`；任一条件不满足时设置可读错误信息并由 UI 展示。

#### Scenario: 权限或蓝牙未就绪
- **WHEN** `startScan()` 被调用但权限未 granting 或蓝牙关闭
- **THEN** 状态保持 disconnected
- **AND** `errorMessage` 设为「蓝牙权限未授予」或「蓝牙已关闭，请先开启蓝牙」
- **AND** UI 通过 SnackBar/Banner 展示

## REMOVED Requirements

无。
