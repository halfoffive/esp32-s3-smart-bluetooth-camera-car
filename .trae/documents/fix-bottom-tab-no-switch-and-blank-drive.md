# Plan: 修复底部 tab 不切换 + 驾驶页空白

## Summary

用户报告两个 UI bug：
1. **底部 NavigationBar tab 点击不切换页面**
2. **驾驶 tab 页面空白**

要求：修复后用 gh-cli 触发 GitHub Action 构建，确认无报错后汇报。遵循 AGENTS.md 约定（M3 原生组件、中文注释、Conventional Commits、文档同步）。

## Current State Analysis（Phase 1 探索结论）

### 代码结构（[app/lib/main.dart](file:///workspace/app/lib/main.dart)）

`_HomeScreenState.build` 当前结构：

```dart
@override
Widget build(BuildContext context) {
  // ← 上一轮修复（commit a52a9e1）新增的 ref.listen
  ref.listen(bleControllerProvider, (previous, next) { ... });
  return Scaffold(
    body: IndexedStack(
      index: _currentIndex,
      children: const [_DriveTab(), DevicesScreen(), SettingsScreen()],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      ...
    ),
  );
}
```

### 三个 tab 的结构不对称（关键发现）

| Tab | 类型 | 是否有 Scaffold | 是否有 AppBar |
|-----|------|----------------|--------------|
| `_DriveTab` | `StatelessWidget` | **否（裸 Column）** | 否 |
| `DevicesScreen` | `ConsumerWidget` | 是 | 是（"设备"） |
| `SettingsScreen` | `ConsumerStatefulWidget` | 是 | 是（"参数设置"） |

`_DriveTab` 是**唯一直接返回 `Column` 而非 `Scaffold` 的 tab**：

```dart
class _DriveTab extends StatelessWidget {
  const _DriveTab();
  @override
  Widget build(BuildContext context) {
    return const Column(   // ← 裸 Column，无 Scaffold
      children: [
        Expanded(flex: 3, child: CameraViewport()),
        TelemetryPanel(),
        Expanded(flex: 2, child: ControlPanel()),
      ],
    );
  }
}
```

### 上一轮修复引入的副作用（次级嫌疑）

`_HomeScreenState.build` 顶部新增的 `ref.listen(bleControllerProvider, ...)` 会在 HomeScreen **首次构建时**就强制构造 `BleController`（其字段 `final FlutterReactiveBle _ble = FlutterReactiveBle();`）。M3 重构前（commit 2ebc537）HomeScreen 不读 `bleControllerProvider`，provider 是懒构造的。

`flutter_reactive_ble` 在桌面平台（Linux/Windows/macOS 桌面无 BLE 适配时）或未完成平台插件初始化时，`FlutterReactiveBle()` 构造或后续 stream 订阅可能抛 `MissingPluginException`。若该异常在 HomeScreen 首次 build 期间触发，整个 widget 树构建失败 → **release 模式下表现为白屏**（debug 模式下为红屏 ErrorWidget），完美吻合用户描述的"驾驶页空白 + tab 不切换"。

## Root Cause Hypothesis（按可能性排序）

### 假设 A（主因）：`_DriveTab` 裸 Column 与其他 tab 结构不对称 + IndexedStack sizing 歧义

`IndexedStack` 默认 `sizing: StackFit.loose`，给子节点 `BoxConstraints(0..maxH, 0..maxW)`。裸 `Column`（`MainAxisSize.max`）理论上应填满 `maxH`，但在某些 Flutter 版本/平台下，**无 `Scaffold` 父级的 Column 在 IndexedStack loose 约束下可能 sizing 异常**，导致 Drive tab 渲染为 0 高度 → 空白。

### 假设 B（次因，由上一轮修复引入）：`ref.listen` 强制早构造 BleController

`ref.listen(bleControllerProvider)` 在 HomeScreen build 期间触发 `BleController()` 构造 → `FlutterReactiveBle()` 实例化。若该实例化在用户平台抛异常，HomeScreen build 失败 → 白屏。

## Proposed Changes

### 改动 1：`app/lib/main.dart` — `_DriveTab` 包 Scaffold + SafeArea（修假设 A）

让三个 tab 结构对称（都有 Scaffold），消除裸 Column 在 IndexedStack 中的 sizing 风险：

```dart
/// 驾驶 tab：摄像头视口 + 遥测面板 + 操控面板。
class _DriveTab extends StatelessWidget {
  const _DriveTab();

  @override
  Widget build(BuildContext context) {
    // 包 Scaffold 与其他 tab 结构对称；无 AppBar 保留全屏沉浸感。
    // SafeArea 处理状态栏/刘海，避免 HUD 被系统 UI 遮挡。
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: const [
            Expanded(flex: 3, child: CameraViewport()),
            TelemetryPanel(),
            Expanded(flex: 2, child: ControlPanel()),
          ],
        ),
      ),
    );
  }
}
```

### 改动 2：`app/lib/main.dart` — IndexedStack 加 `sizing: StackFit.expand`（修假设 A，防御性）

强制所有 tab 子节点填满 body，消除 loose 约束下的 sizing 歧义：

```dart
body: IndexedStack(
  sizing: StackFit.expand,   // ← 新增
  index: _currentIndex,
  children: const [_DriveTab(), DevicesScreen(), SettingsScreen()],
),
```

`Scaffold` 子节点接受 tight 约束无副作用（Scaffold 本就填满父级）。

### 改动 3：`app/lib/main.dart` — `ref.listen` 改为 `ref.listen` + manual guard（修假设 B，可选）

如果改动 1+2 后用户仍报告白屏，则怀疑是 `FlutterReactiveBle()` 构造抛异常。此时把 `ref.listen` 包到 `WidgetsBinding.instance.addPostFrameCallback` 中延迟注册，或在 listener 内 try/catch。**先不动**，等改动 1+2 + CI 验证后看用户反馈。

> 决策：本轮先做改动 1+2（最小、最直接对应"驾驶页空白"症状）。改动 3 留作 fallback，避免过度工程化。

### 改动 4：触发 CI 构建（gh-cli）

按用户要求："通过触发 action，构建，查看是否报错，请合格后汇报"。

- 用 `gh` CLI 触发 `.github/workflows/app.yml`（`workflow_dispatch` 或 push commit 触发 push event）
- 等 `cargo-doc` + `build-matrix`（apk/linux/windows/macos）全绿
- 汇报 CI 结果给用户

> 若 token 缺 `workflow` scope 无法 dispatch，则 push commit 触发 push event（与上一轮相同策略）。

## Assumptions & Decisions

1. **用户偏好"优先使用 rust 编写代码"**：此 bug 是 Flutter UI 渲染层（Dart），Rust 不适用。Rust 侧（`encode_control`/`encode_set_params`/`encode_set_wifi`）与本 bug 无关，无需改动。后续若涉及跨 FFI 的新逻辑，优先 Rust 实现。
2. **不重构 NavigationBar/IndexedStack 主结构**：`setState` + `onDestinationSelected` 是标准 M3 写法，代码正确。"tab 不切换"很可能是由"驾驶页空白"引发的感知（IndexedStack 渲染失败时所有 tab 都看不到内容）。修复 Drive tab 渲染后应同时解决两个症状。
3. **遵循 AGENTS.md**：M3 原生组件、中文注释、Conventional Commits、提交后同步 CHANGELOG/README/AGENTS（若引入新约定）。
4. **Surgical Changes**：仅改 `app/lib/main.dart` 一个文件、两处（`_DriveTab` + `IndexedStack` sizing）。不动 `devices_screen.dart`/`settings_screen.dart`/Rust/固件。
5. **行为准则遵循**：本计划已 surface 假设（A/B 两个根因假设）、选择最简方案（先做 1+2，留 3 作 fallback）、定义可验证目标（CI 全绿 + 用户确认 tab 切换 + 驾驶页可见）。

## Verification（目标驱动）

### 静态验证
- `flutter analyze`（本地若有 flutter 命令）零警告
- `cargo clippy --all-features -- -D warnings`（Rust 侧未改，应保持零警告）

### CI 验证（用户明确要求）
1. 提交改动到分支
2. `gh workflow run app.yml` 或 push commit 触发 push event
3. `gh run watch` 等待完成
4. 检查 `cargo-doc` + 4 平台 `build-matrix` 全 success
5. 汇报 CI run URL + 结论给用户

### 用户实测验证（CI 通过后请用户确认）
- 启动 app → 默认在"驾驶" tab → 应看到摄像头占位（"等待画面..."）+ 遥测面板（——）+ 操控面板（摇杆/键盘提示），**不再空白**
- 点击底部"设备" tab → 应切换到设备页（AppBar 显示"设备" + 扫描按钮）
- 点击底部"设置" tab → 应切换到设置页（AppBar 显示"参数设置" + 表单）
- 点击底部"驾驶" tab → 切回驾驶页

### Fallback（若 CI 绿但用户仍报告白屏）
- 执行改动 3（延迟 `ref.listen` 注册）
- 或请用户提供 `flutter run` 控制台日志 / 截图，定位是否为 `FlutterReactiveBle` 构造异常
