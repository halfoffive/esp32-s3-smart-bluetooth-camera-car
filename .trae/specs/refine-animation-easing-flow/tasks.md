# Tasks

> Spec: `.trae/specs/refine-animation-easing-flow/spec.md`
> 依赖：`improve-ui-animation-and-ble-permissions` 已完成（基础动画已落地）。

## Batch 1：动画 token 集中化（基础，所有后续 batch 依赖）

- [x] Task 1: 新增 `AppAnim` token 类
  - [x] 1.1 `app/lib/ui/theme.dart`：新增 `AppAnim` 抽象类，暴露 `durations`（short 180ms / medium 300ms / long 460ms / pageTransition 360ms / touch 140ms）与 `curves`（emphasized = `easeOutCubic` / standard = `easeInOutCubicEmphasized` / decel = `easeOut` / spring = `easeOutBack` / springReverse = `easeInBack` / accel = `easeInCubic`）静态常量
  - [x] 1.2 验证：`flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）

## Batch 2：摇杆归位与按下反馈（依赖 Batch 1）

- [x] Task 2: 摇杆释放归位动画
  - [x] 2.1 `app/lib/ui/joystick.dart`：`_JoystickState` 新增 `AnimationController _releaseController`（220ms `AppAnim.curves.emphasized`）与 `Animation<Offset> _releaseAnim`
  - [x] 2.2 `_release()` 中：先用 `_releaseController` 从当前 `_thumbOffset` tween 到 `Offset.zero`，**`onChanged(0,0)` 立即触发**（不阻塞 stop 指令）；动画驱动 `setState` 更新 `_thumbOffset`
  - [x] 2.3 `_update()` 中：若 `_releaseController` 仍在运行，调用 `_releaseController.stop()` 并重置 `_thumbOffset` 到 pointer 位置
  - [x] 2.4 `_pressController` 时长 100ms → `AppAnim.durations.short`（180ms），曲线 → `AppAnim.curves.spring`
  - [x] 2.5 dispose 时 `_releaseController.dispose()`
  - [x] 2.6 验证：释放摇杆时拇指圆可见地滑回中心；按下/释放有弹性反馈；`onChanged(0,0)` 立即下发

## Batch 3：启动页与路由转场（依赖 Batch 1）

- [x] Task 3: 启动页淡出过渡
  - [x] 3.1 `app/lib/main.dart` `_SplashScreenState`：新增退出动画 controller（280ms `AppAnim.curves.emphasized`）
  - [x] 3.2 进入动画完成后，forward 退出动画（`FadeTransition` + `ScaleTransition` 1.0→1.04 + `SlideTransition` 上移 16px）
  - [x] 3.3 退出动画 `AnimationStatus.completed` 时再触发 `widget.onComplete()`
  - [x] 3.4 启动页总时长缩短到 900ms（进入动画）
  - [x] 3.5 验证：启动页结束有平滑淡出，无硬切

- [x] Task 4: `_AppRouter` 转场柔和化
  - [x] 4.1 `app/lib/main.dart` `_AppRouterState.build`：`AnimatedSwitcher` duration 改为 `AppAnim.durations.pageTransition`（360ms），curve 改 `AppAnim.curves.standard`
  - [x] 4.2 `transitionBuilder` 中 `Offset(1.0, 0.0)` / `Offset(-1.0, 0.0)` 改为 `Offset(0.18, 0.0)` / `Offset(-0.18, 0.0)`
  - [x] 4.3 `layoutBuilder` 保持原样（`switchOutCurve` 已控制旧页面叠化曲线）
  - [x] 4.4 验证：连接成功时控制页从右侧 18% 屏宽位置滑入；断开时反向；旧页面短暂淡出

- [x] Task 5: 设置页路由曲线区分
  - [x] 5.1 `app/lib/ui/settings_route.dart`：`transitionDuration` 改 `AppAnim.durations.pageTransition`（360ms）
  - [x] 5.2 `transitionsBuilder` 中根据 `animation.status == AnimationStatus.reverse` 判断 push（`AppAnim.curves.emphasized`）或 pop（`AppAnim.curves.accel`）
  - [x] 5.3 验证：打开设置页减速进入；关闭时加速离开

## Batch 4：列表与卡片位移放大（依赖 Batch 1，可与 Batch 3 并行）

- [x] Task 6: 设备页列表项与卡片位移放大
  - [x] 6.1 `app/lib/ui/devices_screen.dart` `_AnimatedListItem`：`Offset(0, 0.05)` → `Offset(0, 0.18)`；duration 400ms → `AppAnim.durations.pageTransition`；curve `easeOutCubic` → `AppAnim.curves.emphasized`
  - [x] 6.2 `_AnimatedListItem` initState：`Duration(milliseconds: widget.index * 60)` 改为 `Duration(milliseconds: (widget.index.clamp(0, 5)) * 60)`（index ≥ 5 后停止延迟）
  - [x] 6.3 `_SlideInFromTop`：`Offset(0, -0.1)` → `Offset(0, -0.18)` + 新增 `ScaleTransition` 0.96→1.0；duration 300ms → `AppAnim.durations.pageTransition`；curve `easeOutCubic` → `AppAnim.curves.spring`
  - [x] 6.4 验证：列表项明显上移；卡片从顶部滑入有轻微弹性

- [x] Task 7: 扫描按钮按下反馈调整
  - [x] 7.1 `app/lib/ui/devices_screen.dart` `_ScanButton`：`AnimatedScale` duration 100ms → `AppAnim.durations.touch`（140ms）
  - [x] 7.2 curve `Curves.easeOut` → `AppAnim.curves.spring`（`easeOutBack`）
  - [x] 7.3 验证：按下有弹性回弹感

## Batch 5：HUD 与设置页位移（依赖 Batch 1，可与 Batch 3/4 并行）

- [x] Task 8: HUD 元素位移淡入
  - [x] 8.1 `app/lib/ui/camera_viewport.dart` `_FadeInDelayed`：改为 `AnimationController` + `FadeTransition` + `SlideTransition` 从 `Offset(0, 0.05)` → `Offset.zero`
  - [x] 8.2 duration 300ms → `AppAnim.durations.pageTransition`；curve `easeOut` → `AppAnim.curves.emphasized`
  - [x] 8.3 调用点 delay 序列改为 `0 / 100 / 180 / 240`（前快后慢）
  - [x] 8.4 验证：HUD 元素淡入时有可见的上移

- [x] Task 9: 设置页 `_FadeInUp` 位移放大
  - [x] 9.1 `app/lib/ui/settings_screen.dart` `_FadeInUp`：`Offset(0, 12)` → `Offset(0, 0.12)`（修正 spec 笔误，原 `Offset(0, 24)` 在 SlideTransition 中按比例解释会过冲）；duration 350ms → `AppAnim.durations.pageTransition`；curve `easeOutCubic` → `AppAnim.curves.emphasized`
  - [x] 9.2 调用点 delay 序列改为 `0 / 80 / 140 / 200`
  - [x] 9.3 验证：设置页表单段有明显上移

## Batch 6：文档与提交（依赖全部）

- [x] Task 10: 更新 `AGENTS.md` / `CHANGELOG.md`
  - [x] 10.1 `AGENTS.md`「用户强制风格 / Flutter 侧」追加：动画时长/曲线统一引用 `AppAnim` token，不再硬编码
  - [x] 10.2 `CHANGELOG.md` `[Unreleased]` Changed 下归类：摇杆归位动画、启动页淡出、路由转场柔和化、列表/卡片/HUD/设置页位移放大、设置页路由曲线区分、扫描按钮反馈
  - [x] 10.3 验证：文档与代码一致

- [ ] Task 11: 分批 git 提交（待用户明确请求后执行；全局 Git Safety Protocol 禁止未明确请求的 commit）
  - [ ] 11.1 `refactor(ui): 新增 AppAnim 动画 token 集中化`
  - [ ] 11.2 `fix(ui): 摇杆释放归位动画与按下弹性反馈`
  - [ ] 11.3 `feat(ui): 启动页淡出过渡`
  - [ ] 11.4 `refactor(ui): _AppRouter 转场柔和化与曲线统一`
  - [ ] 11.5 `feat(ui): 设置页路由曲线区分 push/pop`
  - [ ] 11.6 `refactor(ui): 列表项与卡片位移放大`
  - [ ] 11.7 `refactor(ui): 扫描按钮按下反馈调整`
  - [ ] 11.8 `refactor(ui): HUD 与设置页位移放大`
  - [ ] 11.9 `docs: 同步 AGENTS/CHANGELOG`
  - [ ] 11.10 验证：每个 commit `flutter analyze` 通过；无新增 Rust clippy 警告

# Task Dependencies

- **Batch 1**（Task 1）：所有后续 batch 依赖
- **Batch 2**（Task 2）：依赖 Batch 1
- **Batch 3**（Task 3 / Task 4 / Task 5）：依赖 Batch 1；三者可并行
- **Batch 4**（Task 6 / Task 7）：依赖 Batch 1；可并行
- **Batch 5**（Task 8 / Task 9）：依赖 Batch 1；可并行
- **Batch 6**（Task 10 / Task 11）：依赖全部前序
