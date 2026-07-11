# Tasks

> Spec: `.trae/specs/improve-ui-animation-and-ble-permissions/spec.md`
> 依赖：基线 `refactor-m3-native-ui-and-device-config` 已完成（M3 UI + 设置下发 + BLE 协议扩展）。

## Batch 1：依赖与 BLE 权限基础（可并行）

- [x] Task 1: 添加 `permission_handler` 依赖并声明平台权限
  - [x] 1.1 `app/pubspec.yaml`：在 `dependencies` 新增 `permission_handler: ^11.3.1`
  - [x] 1.2 `app/android/app/src/main/AndroidManifest.xml`：添加 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`、`ACCESS_FINE_LOCATION` 权限；若 CI 生成该文件，同步在 `.github/workflows/app.yml` 的 Android patch 步骤中注入（仅 `apk` 矩阵）
  - [x] 1.3 验证：`flutter pub get` 通过（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 2: 新增 BLE 权限封装 `app/lib/ble/ble_permissions.dart`
  - [x] 2.1 实现 `Future<Map<Permission, PermissionStatus>> requestAll()`：按平台返回所需权限（Android 12+ scan/connect；Android 11 及以下补充 location；iOS/macOS bluetooth；桌面直接 granted）
  - [x] 2.2 实现 `bool get isGranted` / `bool get shouldShowRationale` 等便捷 getter
  - [x] 2.3 实现 `Future<void> showRationaleDialog(BuildContext context)`：解释为何需要蓝牙权限，提供「去设置」调用 `openAppSettings()`
  - [x] 2.4 验证：`flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 3: `BleController` 监听适配器状态并在扫描前校验
  - [x] 3.1 构造时订阅 `FlutterBluePlus.adapterState`，维护 `BluetoothAdapterState _adapterState`（公开 getter）
  - [x] 3.2 `startScan()` 开头调用 `BlePermissions.requestAll()` 与 `_adapterState` 检查；未就绪时设置 `errorMessage` 并提前返回
  - [x] 3.3 `connect()` 同样校验权限（适配器状态在连接时由 flutter_blue_plus 内部报错，但仍显式检查并给出中文错误）
  - [x] 3.4 dispose 时取消适配器订阅
  - [x] 3.5 验证：`flutter analyze` 通过；状态迁移逻辑不变（沙箱无 flutter 命令，代码层面已就绪）

## Batch 2：启动页与页面转场（依赖 Batch 1 完成）

- [x] Task 4: 新增启动页 `_SplashScreen`
  - [x] 4.1 `app/lib/main.dart`：新增 `_SplashScreen` StatefulWidget，1.2s 后通过 `onComplete` 回调进入 `_AppRouter`
  - [x] 4.2 启动页含 `AnimatedBuilder`/`AnimationController`：图标 scale 0.8→1.0（easeOutBack）、副标题与 `LinearProgressIndicator` 淡入
  - [x] 4.3 `SmartCarApp`：`initError != null` 时仍显示 `_InitErrorScreen`；否则显示 `_SplashScreen` 包裹 `_AppRouter`
  - [x] 4.4 验证：启动时无报错，1.2s 后进入设备页（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 5: `_AppRouter` 页面切换动画
  - [x] 5.1 `app/lib/main.dart`：`_AppRouter` 改用 `AnimatedSwitcher` + 自定义 `layoutBuilder`，子页面切换使用横向滑动+淡入（进入从右/左滑入，退出反向淡出）
  - [x] 5.2 时长 300ms，曲线 `Curves.easeInOutCubic`
  - [x] 5.3 验证：连接成功时控制页从右滑入；断开时设备页从左滑入（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 6: 设置页从底部滑入转场
  - [x] 6.1 `app/lib/main.dart`：移除 `routes: {'/settings': ...}`，改为 `onGenerateRoute` 或为设置页自定义 `PageRouteBuilder`（从底部 SlideTransition + FadeTransition）
  - [x] 6.2 `DeviceConnectionScreen._buildMenu` 与 `ControlScreen._buildMenu` 改用 `Navigator.push(context, _buildSettingsRoute())`
  - [x] 6.3 验证：打开/关闭设置页有底部滑入/滑出动画（沙箱无 flutter 命令，代码层面已就绪）

## Batch 3：设备页与控制页动效（依赖 Batch 2 完成）

- [x] Task 7: 设备页扫描与列表动效
  - [x] 7.1 `app/lib/ui/devices_screen.dart`：「扫描设备」按钮加 `ScaleTransition` 或 `GestureDetector` 按下缩放反馈
  - [x] 7.2 新增 `_RadarPulse` widget：扫描时显示 3 个同心圆环由中心向外扩散（循环动画）
  - [x] 7.3 已发现设备列表项使用 `AnimatedContainer`/`SlideTransition` stagger 进入（延迟 60ms）
  - [x] 7.4 已连接设备卡片使用 `SlideTransition` 从顶部 -40px 滑入 + 淡入
  - [x] 7.5 蓝牙关闭时顶部显示 `MaterialBanner`：「蓝牙已关闭」+ 「开启蓝牙」按钮；`_AppRouter` 的 `ScaffoldMessenger` 需由 root 提供，确保 banner 可见
  - [x] 7.6 验证：扫描有雷达动画；列表项依次出现；连接卡片滑入；蓝牙关闭有 banner（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 8: 控制页 HUD 与画面动效
  - [x] 8.1 `app/lib/ui/camera_viewport.dart`：画面首次从 loading 变为 data 时做 scale 0.95→1.0 + opacity 0→1 动画（用 `AnimatedSwitcher` 或包一层 `AnimatedOpacity` + `AnimatedScale`）
  - [x] 8.2 HUD 覆盖层元素 stagger 淡入（bracket、连接芯片、FPS、速度，间隔 80ms）
  - [x] 8.3 验证：画面到达时平滑出现；HUD 依次淡入（沙箱无 flutter 命令，代码层面已就绪）

- [x] Task 9: 摇杆触摸反馈
  - [x] 9.1 `app/lib/ui/joystick.dart`：按下时底圆环 strokeWidth 1.5→3.0，拇指圆 scale 1.08x
  - [x] 9.2 使用 `AnimatedContainer` 或 `AnimationController` 驱动，释放时弹性回中
  - [x] 9.3 验证：触摸/释放摇杆有视觉反馈（沙箱无 flutter 命令，代码层面已就绪）

## Batch 4：设置页动效（依赖 Batch 2 完成）

- [x] Task 10: 设置页表单 stagger 与按钮渐变
  - [x] 10.1 `app/lib/ui/settings_screen.dart`：页面进入后表单各段 stagger 淡入上移（50ms 间隔）
  - [x] 10.2 「保存」/「下发到设备」按钮用 `AnimatedContainer` 包装，启用/禁用状态在 200ms 内渐变颜色与透明度
  - [x] 10.3 验证：进入设置页表单依次出现；连接/断开时按钮平滑切换样式。已完成

## Batch 5：文档与提交（依赖全部）

- [x] Task 11: 更新 `AGENTS.md` / `CHANGELOG.md`
  - [x] 11.1 `AGENTS.md`「BLE 关键约定」追加 BLE 权限请求说明；`「工具链陷阱」追加 permission_handler + AndroidManifest.xml 声明提示。
  - [x] 11.2 `CHANGELOG.md` `[Unreleased]` Added 下补充启动页动效、页面转场、设备页雷达/列表/卡片动效、控制页 HUD/画面动效、摇杆反馈、设置页表单 stagger/按钮渐变、BLE 权限与适配器状态检查、permission_handler 依赖等条目。
  - [x] 11.3 验证：文档与代码一致

- [x] Task 12: 分批 git 提交
  - [x] 12.1 `chore(deps): 添加 permission_handler 依赖与 Android 权限声明`
  - [x] 12.2 `feat(ble): 新增 BLE 权限封装与适配器状态监听`
  - [x] 12.3 `feat(ui): 启动页与页面转场动画`
  - [x] 12.4 `feat(ui): 设备页雷达扫描与列表卡片动效`
  - [x] 12.5 `feat(ui): 控制页 HUD 与画面淡入动效`
  - [x] 12.6 `feat(ui): 摇杆触摸反馈`
  - [x] 12.7 `feat(ui): 设置页表单 stagger 与按钮渐变`
  - [x] 12.8 `docs: 同步 AGENTS/CHANGELOG`
  - [x] 12.9 验证：每个 commit `flutter analyze` 通过；无新增 clippy 警告

# Task Dependencies

- **Batch 1**（Task 1 / Task 2 / Task 3）：基础依赖，Task 1 与 Task 2/3 可并行；Task 3 依赖 Task 2
- **Batch 2**（Task 4 / Task 5 / Task 6）：依赖 Batch 1；Task 4 → Task 5 → Task 6 顺序
- **Batch 3**（Task 7 / Task 8 / Task 9）：依赖 Batch 2；可并行
- **Batch 4**（Task 10）：依赖 Batch 2
- **Batch 5**（Task 11 / Task 12）：依赖全部前序
