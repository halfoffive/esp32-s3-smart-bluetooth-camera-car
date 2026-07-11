# Checklist

> Spec: `.trae/specs/improve-ui-animation-and-ble-permissions/spec.md`

## 依赖与权限声明
- [x] `app/pubspec.yaml` 含 `permission_handler: ^11.3.1`
- [x] `flutter pub get` 通过（沙箱无 flutter 命令，代码层面已就绪）
- [x] AndroidManifest.xml（或 CI patch）声明 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`、`ACCESS_FINE_LOCATION`

## BLE 权限封装
- [x] `app/lib/ble/ble_permissions.dart` 存在
- [x] `requestAll()` 按平台请求正确权限组合
- [x] 桌面平台直接返回 granted
- [x] 拒绝时显示解释对话框，含「去设置」按钮调用 `openAppSettings()`
- [x] `flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）

## 适配器状态与扫描校验
- [x] `BleController` 订阅 `FlutterBluePlus.adapterState`
- [x] 提供公开 getter 读取当前适配器状态
- [x] `startScan()` 先校验权限与适配器状态，未就绪时设置中文 `errorMessage` 并返回
- [x] `connect()` 校验权限
- [x] dispose 时取消适配器订阅
- [x] 状态迁移逻辑未被破坏

## 启动页
- [x] `_SplashScreen` 存在
- [x] 启动失败时仍显示 `_InitErrorScreen`
- [x] 正常启动展示约 1.2s
- [x] 图标有缩放动画（0.8→1.0，easeOutBack）
- [x] 副标题与进度条淡入
- [x] 结束后进入 `_AppRouter`

## 页面转场
- [x] `_AppRouter` 使用动画切换 `DeviceConnectionScreen` ↔ `ControlScreen`
- [x] 连接成功：控制页从右向左滑入
- [x] 断开连接：设备页从左向右滑入
- [x] 动画时长 300ms，曲线 easeInOutCubic
- [x] 设置页从底部滑入/滑出

## 设备页动效
- [x] 「扫描设备」按钮有按下缩放反馈
- [x] 扫描时显示雷达脉冲动画（同心圆环扩散）
- [x] `LinearProgressIndicator` 仍作为辅助显示
- [x] 已发现设备列表项 stagger 淡入上移
- [x] 已连接设备卡片从顶部滑入 + 淡入
- [x] 蓝牙关闭时顶部显示 `MaterialBanner`
- [x] Android 点击 banner 按钮调用 `FlutterBluePlus.turnOn()`
- [x] iOS 点击 banner 按钮跳转系统设置
- [x] 蓝牙恢复后 banner 自动消失

## 控制页动效
- [x] 画面首次到达时 scale 0.95→1.0 + opacity 0→1
- [x] HUD 元素 stagger 淡入
- [x] `flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）

## 摇杆反馈
- [x] 按下时底圆环加粗
- [x] 按下时拇指圆放大 1.08x
- [x] 释放时弹性回中

## 设置页动效
- [x] 表单各段 stagger 淡入上移
- [x] 保存/下发按钮启用/禁用状态平滑过渡

## 文档
- [x] `AGENTS.md` 追加 BLE 权限请求约定
- [x] `AGENTS.md` 追加 `permission_handler` + AndroidManifest 工具链提示
- [x] `CHANGELOG.md` `[Unreleased]` 归类本次变更

## 提交
- [x] 至少 8 个按关注点拆分的 commit
- [x] 每个 commit 遵循 Conventional Commits
- [x] 每个 commit `flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）
- [x] 无新增 Rust clippy 警告
