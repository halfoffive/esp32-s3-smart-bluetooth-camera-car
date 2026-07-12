# 动画流畅性优化 Spec

## Why

`improve-ui-animation-and-ble-permissions` 已落地基础动画，但用户反馈「动画突兀」。审查代码后定位到 9 个具体突兀点（详见 What Changes），根因集中在三处：

1. **硬切**：摇杆释放瞬间 `setState` 归零；启动页 `onComplete` 在 `controller.completed` 时直接换页，无淡出。
2. **位移不可读**：列表项 `Offset(0, 0.05)` 仅 5% 屏高、设置页 `Offset(0, 12)` 仅 12px，视觉上等于纯淡入，丢失「滑入」语义。
3. **曲线分散**：`easeOut` / `easeOutCubic` / `easeInOutCubic` / `easeOutBack` / `easeOutQuad` 在 7 个文件中混用，没有统一 token，导致整体节奏断裂。

本改动**只修突兀，不重写动画体系**，不引入新依赖，不改 widget 结构。

## What Changes

- **新增动画 token**：`app/lib/ui/theme.dart` 新增 `AppAnim` 类，集中暴露 `Durations`（short 180ms / medium 300ms / long 460ms）与 `Curves`（emphasized = `easeOutCubic` / standard = `easeInOutCubicEmphasized` / decel = `easeOut` / spring = `easeOutBack`）。所有散落的 `Duration(milliseconds: ...)` 与 `Curves.xxx` 改为引用 token。
- **摇杆归位动画**：`joystick.dart` `_release()` 不再 `setState` 瞬间归零；新增 `AnimationController` tween 从当前 `_thumbOffset` → `Offset.zero`，220ms `easeOutCubic`，**释放时拇指圆可见地滑回中心**。`_pressController` 时长 100ms → 180ms，曲线改 `Curves.easeOutBack`，按下/释放有弹性反馈。
- **启动页淡出过渡**：`main.dart` `_SplashScreen` 缩短到 900ms；`onComplete` 触发前先播放 280ms 的退出动画（整体内容 `FadeTransition` + `ScaleTransition` 1.0→1.04 + `SlideTransition` 上移 16px）。退出动画完成后才回调 `onComplete`，避免硬切。
- **`_AppRouter` 转场柔和化**：横滑距离 `Offset(1.0, 0.0)` → `Offset(0.18, 0.0)`（仅 18% 屏宽位移），保留淡入；时长 300ms → 360ms；曲线改 `Curves.easeInOutCubicEmphasized`；旧页面通过 `layoutBuilder` 保留 `FadeTransition` 短暂叠化（180ms）。
- **设备页列表项位移放大**：`devices_screen.dart` `_AnimatedListItem` 的 `Offset(0, 0.05)` → `Offset(0, 0.18)`（18% 屏高，可见的「上移」）；stagger 60ms 不变，但**index ≥ 5 后停止延迟**（避免长列表尾部滞后过大）。
- **已连接卡片入场**：`_SlideInFromTop` 的 `Offset(0, -0.1)` → `Offset(0, -0.18)` + 加入 `ScaleTransition` 0.96→1.0；时长 300ms → 360ms；曲线改 `Curves.easeOutBack`（轻微弹性）。
- **HUD 元素加位移**：`camera_viewport.dart` `_FadeInDelayed` 包装一层 `SlideTransition`，从 `Offset(0, 8px)` → `Offset.zero`；delay 序列改为 `0/100/180/240`（前快后慢，避免机械等距）；时长 300ms → 360ms。
- **设置页 `_FadeInUp` 位移放大**：`Offset(0, 12)` → `Offset(0, 24)`（24px，肉眼可见的滑入）；delay 序列改为 `0/80/140/200`；curve 改 `Curves.easeOutCubic`。
- **设置页路由曲线区分**：`settings_route.dart` push 用 `Curves.easeOutCubic`（减速进入），pop 用 `Curves.easeInCubic`（加速离开）；时长 300ms → 340ms。
- **扫描按钮按下反馈**：`_ScanButton` 的 `AnimatedScale` 100ms → 140ms，曲线 `Curves.easeOut` → `Curves.easeOutBack`（轻微回弹）。
- **文档同步**：`AGENTS.md` 「用户强制风格 / Flutter 侧」追加动画 token 约定；`CHANGELOG.md` `[Unreleased]` Changed 归类。

## Impact

- 受影响代码：
  - `app/lib/ui/theme.dart` — 新增 `AppAnim` token 类
  - `app/lib/ui/joystick.dart` — 摇杆归位动画 + press 时长调整
  - `app/lib/main.dart` — 启动页淡出 + `_AppRouter` 转场参数
  - `app/lib/ui/devices_screen.dart` — 列表项位移放大 + 卡片 scale
  - `app/lib/ui/camera_viewport.dart` — HUD 元素加 SlideTransition
  - `app/lib/ui/settings_screen.dart` — `_FadeInUp` 位移放大 + delay 调整
  - `app/lib/ui/settings_route.dart` — push/pop 曲线区分
  - `AGENTS.md` / `CHANGELOG.md`
- 不影响：BLE 协议、Rust 编码、固件、PID/WiFi 下发、自动重连、权限请求逻辑、雷达脉冲的核心结构（仅微调参数）、`_AnimatedActionButton` 的启用/禁用渐变（保持现状）。
- **BREAKING**：无。

## ADDED Requirements

### Requirement: 动画 token 集中化
App SHALL 在 `AppAnim` 类暴露统一的 `Durations` 与 `Curves` token，所有 UI 动画引用这些 token 而非硬编码 `Duration`/`Curves`。

#### Scenario: 引用 token
- **WHEN** 任意 widget 设置动画时长或曲线
- **THEN** 使用 `AppAnim.Durations.medium` / `AppAnim.Curves.emphasized` 等 token
- **AND** 不再硬编码 `Duration(milliseconds: 300)` 或裸 `Curves.easeOutCubic`

### Requirement: 摇杆释放归位动画
Joystick SHALL 在释放时以 220ms `easeOutCubic` 动画将拇指圆从当前位置滑回中心，而非瞬间归零。

#### Scenario: 释放摇杆
- **WHEN** 用户手指离开摇杆
- **THEN** 拇指圆从释放位置以 220ms `easeOutCubic` 滑回中心
- **AND** 期间 `onChanged(0, 0)` 立即触发（不阻塞 stop 指令下发）
- **AND** 视觉上无瞬移

#### Scenario: 按下与释放弹性反馈
- **WHEN** 用户按下摇杆
- **THEN** `pressProgress` 以 180ms `easeOutBack` 推进到 1.0
- **AND** 释放时以 180ms `easeOutBack` 反向回 0.0
- **AND** 拇指圆半径与底圆环描边随之平滑过渡

### Requirement: 启动页淡出过渡
`_SplashScreen` SHALL 在内容展示完成后播放 280ms 退出动画（fade + scale 1.0→1.04 + 上移 16px），退出完成后才回调 `onComplete`。

#### Scenario: 正常启动结束
- **WHEN** 启动页进入动画完成
- **THEN** 整体内容淡出 + 轻微放大 + 上移 16px
- **AND** 280ms 后回调 `onComplete`
- **AND** 进入 `_AppRouter` 时无硬切感

### Requirement: `_AppRouter` 转场柔和化
`_AppRouter` SHALL 在 `DeviceConnectionScreen` ↔ `ControlScreen` 之间使用 18% 屏宽位移 + 淡入 + 360ms `easeInOutCubicEmphasized` 转场；旧页面在 180ms 内短暂叠化淡出。

#### Scenario: 进入控制页
- **WHEN** `BleState.status` 变为 connected
- **THEN** `ControlScreen` 从右侧 18% 屏宽位置滑入并淡入
- **AND** 时长 360ms
- **AND** 曲线 `Curves.easeInOutCubicEmphasized`
- **AND** 旧 `DeviceConnectionScreen` 在 180ms 内淡出

### Requirement: 列表项位移可读化
`_AnimatedListItem` SHALL 以 18% 屏高位移 + 360ms `easeOutCubic` 淡入上移；index ≥ 5 后停止 stagger 延迟。

#### Scenario: 列表项入场
- **WHEN** 设备列表新增项进入
- **THEN** 该项从下方 18% 屏高位置淡入上移
- **AND** 时长 360ms，曲线 `easeOutCubic`
- **AND** 前 5 项依次延迟 60ms × index
- **AND** 第 6 项及之后无额外延迟

### Requirement: HUD 元素位移淡入
`_FadeInDelayed` SHALL 在淡入的同时从下方 8px 上移到原位；delay 序列 `0/100/180/240`，时长 360ms。

#### Scenario: HUD 进入
- **WHEN** 进入控制页
- **THEN** 四角 bracket、连接芯片、FPS 芯片、速度数字依次淡入上移
- **AND** 每项从下方 8px 滑到原位
- **AND** delay 序列 `0ms / 100ms / 180ms / 240ms`
- **AND** 时长 360ms

## MODIFIED Requirements

### Requirement: 已连接设备卡片入场
`_SlideInFromTop` SHALL 从顶部 18% 屏高位置 + scale 0.96 滑入并淡入，时长 360ms，曲线 `Curves.easeOutBack`。

#### Scenario: 连接成功
- **WHEN** 状态变为 connected
- **THEN** 已连接卡片从顶部 18% 屏高 + scale 0.96 滑入并淡入
- **AND** 时长 360ms
- **AND** 曲线 `Curves.easeOutBack`（轻微弹性）

### Requirement: 设置页表单位移放大
`_FadeInUp` SHALL 以 24px 位移 + 350ms `easeOutCubic` 淡入上移；delay 序列 `0/80/140/200`。

#### Scenario: 进入设置页
- **WHEN** 设置页从底部滑入完成
- **THEN** 表单各段从下方 24px 淡入上移
- **AND** delay 序列 `0ms / 80ms / 140ms / 200ms`
- **AND** 时长 350ms
- **AND** 曲线 `Curves.easeOutCubic`

### Requirement: 设置页路由曲线区分
`buildSettingsRoute` SHALL 在 push 时使用 `Curves.easeOutCubic`（减速进入），pop 时使用 `Curves.easeInCubic`（加速离开），时长 340ms。

#### Scenario: 打开设置页
- **WHEN** 用户点击菜单「设置」
- **THEN** `SettingsScreen` 从底部以 `easeOutCubic` 减速滑入
- **AND** 时长 340ms

#### Scenario: 关闭设置页
- **WHEN** 用户返回
- **THEN** `SettingsScreen` 以 `easeInCubic` 加速向下滑出
- **AND** 时长 340ms

### Requirement: 扫描按钮按下反馈
`_ScanButton` SHALL 以 140ms `easeOutBack` 按下缩放反馈，scale 1.0→0.96。

#### Scenario: 按下扫描按钮
- **WHEN** 用户按下「扫描设备」
- **THEN** 按钮以 140ms `easeOutBack` 缩放到 0.96
- **AND** 释放时以同曲线回弹到 1.0

## REMOVED Requirements

无。
