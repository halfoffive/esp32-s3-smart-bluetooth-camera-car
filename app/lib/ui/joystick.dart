// joystick.dart - 自定义虚拟摇杆
//
// GestureDetector + CustomPainter 实现：
//   - 底圆（凹陷区）+ 十字准星 + 拇指圆
//   - 拇指拖动归一化为 (dx, dy) ∈ [-1, 1]
//   - dy 上推为正（注意屏幕坐标 y 向下为正，需翻转）
//   - 释放自动回中并回调 (0, 0)

import 'package:flutter/material.dart';

/// 虚拟摇杆。
///
/// [onChanged] 在拖动期间持续触发，释放时触发 (0, 0)。
/// - [dx] 横向偏移，右为正
/// - [dy] 纵向偏移，前推（上）为正
class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.onChanged});

  final void Function(double dx, double dy) onChanged;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick>
    with SingleTickerProviderStateMixin {
  /// 拇指圆相对中心的偏移（屏幕坐标，y 向下为正）
  Offset _thumbOffset = Offset.zero;

  /// 拇指中心距圆心的最大允许距离（layout 时计算）
  double _maxRadius = 1;

  /// 当前是否处于按压/拖动激活状态
  bool _active = false;

  /// 按压动画控制器：0.0 -> 1.0 表示从静止到按下
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = Offset(size.width / 2, size.height / 2);
        // 底圆半径：取较短边的一半减去边距
        final baseRadius = (size.shortestSide / 2) - 6;
        // 拇指圆半径
        final thumbRadius = baseRadius * 0.42;
        // 拇指中心活动范围 = 底圆半径 - 拇指半径（让拇指圆不超出底圆）
        _maxRadius = (baseRadius - thumbRadius).clamp(1.0, double.infinity);

        final cs = Theme.of(context).colorScheme;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _update(d.localPosition, center),
          onPanUpdate: (d) => _update(d.localPosition, center),
          onPanEnd: (_) => _release(),
          child: AnimatedBuilder(
            animation: _pressController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _JoystickPainter(
                  center: center,
                  thumb: center + _thumbOffset,
                  baseRadius: baseRadius,
                  thumbRadius: thumbRadius,
                  active: _active,
                  pressProgress: _pressController.value,
                  baseFill: cs.surfaceContainerHigh,
                  baseStroke: cs.primary,
                  crossColor: cs.onSurfaceVariant,
                  thumbShadow: cs.surface,
                  thumbIdle: cs.onSurface,
                  thumbActive: cs.primary,
                  thumbHighlight: cs.onSurface,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 根据指针位置更新拇指偏移并回调归一化值。
  void _update(Offset local, Offset center) {
    if (!_active) {
      _pressController.forward();
      _active = true;
    }
    var delta = local - center;
    final dist = delta.distance;
    if (dist > _maxRadius) {
      // 超出范围，钳制到圆周
      delta = Offset(
        delta.dx / dist * _maxRadius,
        delta.dy / dist * _maxRadius,
      );
    }
    setState(() => _thumbOffset = delta);
    final nx = (delta.dx / _maxRadius).clamp(-1.0, 1.0);
    // 翻转 y：屏幕向下为正 → 用户前推（向上）应为正
    final ny = (-delta.dy / _maxRadius).clamp(-1.0, 1.0);
    widget.onChanged(nx, ny);
  }

  /// 释放：回中并回调 (0, 0)。
  void _release() {
    _pressController.reverse();
    _active = false;
    setState(() => _thumbOffset = Offset.zero);
    widget.onChanged(0, 0);
  }
}

/// 摇杆画笔：底圆 + 十字准星 + 拇指圆。
class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.center,
    required this.thumb,
    required this.baseRadius,
    required this.thumbRadius,
    required this.active,
    required this.pressProgress,
    required this.baseFill,
    required this.baseStroke,
    required this.crossColor,
    required this.thumbShadow,
    required this.thumbIdle,
    required this.thumbActive,
    required this.thumbHighlight,
  });

  final Offset center;
  final Offset thumb;
  final double baseRadius;
  final double thumbRadius;
  final bool active;

  /// 按压动画进度，0.0 为未按压，1.0 为完全按下
  final double pressProgress;

  // 颜色字段：CustomPainter 无 BuildContext，由调用方从 colorScheme 注入
  final Color baseFill;
  final Color baseStroke;
  final Color crossColor;
  final Color thumbShadow;
  final Color thumbIdle;
  final Color thumbActive;
  final Color thumbHighlight;

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 底圆外阴影（增加深度） ----
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: baseRadius)),
      Colors.black.withValues(alpha: 0.2),
      2.0,
      false,
    );

    // ---- 底圆填充（径向渐变，模拟凹陷） ----
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [baseFill, baseFill.withValues(alpha: 0.7)],
          center: Alignment.center,
          radius: 1.0,
        ).createShader(
          Rect.fromCircle(center: center, radius: baseRadius),
        ),
    );

    // ---- 底圆边（橙色细环，提示交互区）----
    // 按压时描边加粗：1.5 -> 3.0
    final strokeWidth = 1.5 + pressProgress * 1.5;
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = baseStroke.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // ---- 十字准星 ----
    final crossPaint = Paint()
      ..color = crossColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cross = baseRadius * 0.65;
    canvas.drawLine(
      Offset(center.dx - cross, center.dy),
      Offset(center.dx + cross, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - cross),
      Offset(center.dx, center.dy + cross),
      crossPaint,
    );

    // ---- 中心点 ----
    canvas.drawCircle(
      center,
      2,
      Paint()..color = crossColor,
    );

    // ---- 拇指圆 ----
    // 按压时半径微微放大：1.0x -> 1.08x
    final drawThumbRadius = thumbRadius * (1.0 + pressProgress * 0.08);

    // 阴影
    canvas.drawCircle(
      thumb + const Offset(0, 2),
      drawThumbRadius,
      Paint()..color = thumbShadow.withValues(alpha: 0.5),
    );

    // 主体
    canvas.drawCircle(
      thumb,
      drawThumbRadius,
      Paint()..color = active ? thumbActive : thumbIdle,
    );

    // 内圈高光
    canvas.drawCircle(
      thumb,
      drawThumbRadius * 0.65,
      Paint()
        ..color = thumbHighlight.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.thumb != thumb ||
      old.active != active ||
      old.pressProgress != pressProgress ||
      old.baseRadius != baseRadius ||
      old.thumbRadius != thumbRadius ||
      old.baseFill != baseFill ||
      old.baseStroke != baseStroke ||
      old.crossColor != crossColor ||
      old.thumbShadow != thumbShadow ||
      old.thumbIdle != thumbIdle ||
      old.thumbActive != thumbActive ||
      old.thumbHighlight != thumbHighlight;
}
