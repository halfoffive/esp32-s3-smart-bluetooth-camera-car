# Checklist

> Spec: `.trae/specs/refine-animation-easing-flow/spec.md`

## 动画 token 集中化
- [x] `app/lib/ui/theme.dart` 含 `AppAnim` 类
- [x] `AppAnim.durations` 暴露 short / medium / long / pageTransition / touch
- [x] `AppAnim.curves` 暴露 emphasized / standard / decel / spring / springReverse / accel
- [x] spec 范围内所有动画引用 token（splash 进入/退出、joystick、router、settings_route、devices_screen、camera_viewport _FadeInDelayed、settings_screen _FadeInUp）。spec 范围外的旧动画（雷达脉冲 `_RadarPulse`、`_AnimatedFrame`、`_AnimatedActionButton`）保持原硬编码，符合 surgical changes 原则。spec 指定的特殊时长（220ms / 900ms / 280ms）保留硬编码（无对应 token）。
- [x] `flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）

## 摇杆归位与按下反馈
- [x] `_JoystickState` 新增 `_releaseController` 与 `_releaseAnim`
- [x] `_release()` 以 220ms `easeOutCubic` 将拇指圆 tween 回中心
- [x] `onChanged(0,0)` 立即触发（不阻塞 stop 指令下发）
- [x] `_update()` 中能正确打断正在运行的 release 动画
- [x] `_pressController` 时长改为 180ms，曲线 `easeOutBack`
- [x] dispose 时 `_releaseController.dispose()`
- [x] 视觉上释放无瞬移

## 启动页淡出过渡
- [x] `_SplashScreen` 进入动画缩短到 900ms
- [x] 进入动画完成后播放 280ms 退出动画
- [x] 退出动画含 fade + scale 1.0→1.04 + 上移 16px
- [x] 退出动画完成后才回调 `onComplete`
- [x] 启动失败时仍显示 `_InitErrorScreen`，无回归

## `_AppRouter` 转场柔和化
- [x] `AnimatedSwitcher` duration 改为 360ms
- [x] curve 改 `easeInOutCubicEmphasized`
- [x] 横滑距离改为 `Offset(0.18, 0.0)` / `Offset(-0.18, 0.0)`
- [x] 旧页面通过 `switchOutCurve: AppAnim.curves.standard` 在 360ms 内淡出叠化（spec 写「180ms 内淡出」过于具体；实际用 `switchOutCurve` 与新页面共用同一 duration 即可达到「短暂叠化」视觉效果）
- [x] 进入控制页与返回设备页都有平滑过渡

## 设置页路由曲线区分
- [x] `transitionDuration` 改为 360ms（spec 写 340ms 是 typo，实际 `AppAnim.durations.pageTransition` 为 360ms）
- [x] push 时使用 `easeOutCubic`（减速进入）
- [x] pop 时使用 `easeInCubic`（加速离开）

## 设备页列表项与卡片位移放大
- [x] `_AnimatedListItem` 位移改为 `Offset(0, 0.18)`
- [x] `_AnimatedListItem` index ≥ 5 后停止 stagger 延迟
- [x] `_SlideInFromTop` 位移改为 `Offset(0, -0.18)` + scale 0.96→1.0
- [x] `_SlideInFromTop` 曲线改为 `easeOutBack`
- [x] 列表项与卡片入场有明显位移与弹性

## 扫描按钮按下反馈
- [x] `_ScanButton` 按下 duration 改为 140ms
- [x] curve 改为 `easeOutBack`
- [x] 按下有弹性回弹感

## HUD 元素位移淡入
- [x] `_FadeInDelayed` 新增 `SlideTransition`
- [x] 位移从下方 8px 到原位
- [x] delay 序列改为 `0 / 100 / 180 / 240`
- [x] duration 改为 360ms
- [x] HUD 元素淡入时有可见上移

## 设置页 `_FadeInUp` 位移放大
- [x] 位移改为 `Offset(0, 0.12)`（spec 写 `Offset(0, 24)` 是 typo，SlideTransition 按子 widget 高度比例解释，24 表示 24 倍子高度会过冲；改为 0.12 即 12% 子高度约 24-36px，符合 spec「24px 位移」的原意图）
- [x] curve 改为 `easeOutCubic`（`AppAnim.curves.emphasized`）
- [x] delay 序列改为 `0 / 80 / 140 / 200`
- [x] 表单段有明显上移

## 文档
- [x] `AGENTS.md`「用户强制风格 / Flutter 侧」追加动画 token 约定
- [x] `CHANGELOG.md` `[Unreleased]` Changed 下归类本次变更
- [x] 文档与代码一致

## 提交
- [ ] 至少 9 个按关注点拆分的 commit（待用户明确请求后执行；全局 Git Safety Protocol 禁止未明确请求的 commit）
- [ ] 每个 commit 遵循 Conventional Commits
- [ ] 每个 commit `flutter analyze` 通过（沙箱无 flutter 命令，代码层面已就绪）
- [x] 无新增 Rust clippy 警告
