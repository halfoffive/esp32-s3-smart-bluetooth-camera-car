// keyboard_controller.dart - 桌面键盘控制器
//
// 监听 W/A/S/D 与方向键，按下时启动移动、松开时停止。
// 按住期间每 80ms 重发一次（保活，防 BLE 链路掉命令）。
// 松开所有键时立即发 speed_pct=0（不等节流窗口）。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FocusNode;

import 'tilt_controller.dart' show ControlCommand;

/// 桌面键盘控制器。
///
/// 通过 [onKeyEvent] 接入 `Focus` widget 的 `onKeyEvent` 回调，
/// 维护当前按键集合，状态变化时输出 [ControlCommand]。
class KeyboardController {
  KeyboardController({
    this.defaultSpeedPct = 80,
    this.resendMs = 80,
  });

  /// 按下方向键时的默认速度百分比
  final int defaultSpeedPct;

  /// 保活重发间隔（毫秒）。80ms ≈ 12.5 次/秒，BLE 写入队列足够。
  final int resendMs;

  final StreamController<ControlCommand> _controller =
      StreamController<ControlCommand>.broadcast();

  /// 当前按下的按键集合
  final Set<LogicalKeyboardKey> _pressed = {};

  /// 保活定时器（按住时周期性重发）
  Timer? _resendTimer;

  /// 控制指令输出流
  Stream<ControlCommand> get stream => _controller.stream;

  /// 按键事件处理（接入 `Focus.onKeyEvent`）。
  ///
  /// - [KeyDownEvent]：加入按键集合，立即输出新指令
  /// - [KeyUpEvent]：移除按键集合，立即输出新指令（空集合 → stop）
  /// - [KeyRepeatEvent]：由 [_resendTimer] 处理，忽略
  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressed.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _pressed.remove(event.logicalKey);
    } else {
      // KeyRepeatEvent：系统自动重复，由保活定时器统一处理
      return KeyEventResult.handled;
    }

    _emit();
    return KeyEventResult.handled;
  }

  /// 根据当前按键集合计算并发送控制指令。
  void _emit() {
    final cmd = _currentCommand();

    if (cmd.speedPct == 0) {
      // 所有键松开 → 立即发 stop，停止保活重发
      _resendTimer?.cancel();
      _resendTimer = null;
      _controller.add(cmd);
      return;
    }

    // 按下时立即发一次
    _controller.add(cmd);

    // 启动保活定时器：每 resendMs 重发当前指令（防 BLE 链路掉命令）
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(
      Duration(milliseconds: resendMs),
      (_) {
        if (_pressed.isEmpty) {
          _resendTimer?.cancel();
          _resendTimer = null;
          return;
        }
        _controller.add(_currentCommand());
      },
    );
  }

  /// 根据按键集合计算当前控制指令。
  ControlCommand _currentCommand() {
    int direction = 0;
    int turn = 0;

    // 方向：W/↑ 前进，S/↓ 后退
    if (_pressed.any(_isForward)) {
      direction = 1;
    } else if (_pressed.any(_isBackward)) {
      direction = -1;
    }

    // 转向：A/← 左转，D/→ 右转
    if (_pressed.any(_isRight)) {
      turn = 1;
    } else if (_pressed.any(_isLeft)) {
      turn = -1;
    }

    final hasInput = direction != 0 || turn != 0;
    return ControlCommand(
      direction: direction,
      turn: turn,
      speedPct: hasInput ? defaultSpeedPct : 0,
    );
  }

  static bool _isForward(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp;

  static bool _isBackward(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown;

  static bool _isLeft(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft;

  static bool _isRight(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight;

  /// 释放资源（取消定时器、关闭流、清空按键集合）。
  void dispose() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _pressed.clear();
    _controller.close();
  }
}
