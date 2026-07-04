// tilt_controller.dart - 加速度计体感控制器
//
// 把手机倾斜角度映射为 (direction, turn, speedPct) 控制指令。
// 约定：手机平放（屏幕朝上）握持。
//   - 前倾（顶部下压，y 轴负方向）→ direction=1（前进）
//   - 后倾（顶部抬起，y 轴正方向）→ direction=-1（后退）
//   - 右倾（x 轴正）→ turn=1（右转）
//   - 左倾（x 轴负）→ turn=-1（左转）
//
// 内置 80ms 节流（≈12.5 次/秒），避免 BLE 写入队列过载。

import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// 控制指令值对象（与 BLE 协议字段一一对应）。
///
/// 直接传给 [BleController.sendControl]；Dart 无 int8/uint8 类型，
/// 用 int + 注释约束有效范围。
class ControlCommand {
  /// 方向：-1 后退 / 0 停 / 1 前进
  final int direction;

  /// 转向：-1 左转 / 0 直行 / 1 右转
  final int turn;

  /// 目标速度百分比：0-100
  final int speedPct;

  const ControlCommand({
    required this.direction,
    required this.turn,
    required this.speedPct,
  });

  @override
  String toString() =>
      'ControlCommand(dir=$direction, turn=$turn, speed=$speedPct)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControlCommand &&
          direction == other.direction &&
          turn == other.turn &&
          speedPct == other.speedPct;

  @override
  int get hashCode => Object.hash(direction, turn, speedPct);
}

/// 加速度计体感控制器。
///
/// 订阅 [accelerometerEventStream]，将手机倾斜映射为 [ControlCommand] 流。
/// 死区与映射参数可调，80ms 节流防 BLE 写入过载。
class TiltController {
  TiltController({
    this.deadZone = 0.2,
    this.maxTilt = 1.0,
    this.throttleMs = 80,
  });

  /// 死区（g 单位）：倾斜幅度 < 此值视为 0
  final double deadZone;

  /// 满速倾斜量（g 单位）：倾斜到此值时输出 100%
  final double maxTilt;

  /// 节流间隔（毫秒）。80ms ≈ 12.5 次/秒，BLE 写入队列足够。
  final int throttleMs;

  final StreamController<ControlCommand> _controller =
      StreamController<ControlCommand>.broadcast();

  StreamSubscription<AccelerometerEvent>? _sub;

  /// 上次发送时间（用于节流）
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// 控制指令输出流
  Stream<ControlCommand> get stream => _controller.stream;

  /// 启动加速度计订阅。
  ///
  /// 使用 [SensorInterval.uiInterval]（≈16ms）采样，内部节流到 80ms 输出。
  void start() {
    _sub?.cancel();
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onEvent);
  }

  /// 加速度计事件处理：归一化 → 死区 → 映射 → 节流 → 输出。
  void _onEvent(AccelerometerEvent event) {
    // 归一化为 g 单位（除以重力加速度 9.8 m/s²）
    final tiltX = event.x / 9.8;
    final tiltY = event.y / 9.8;

    // 死区过滤（独立轴）
    final effX = tiltX.abs() < deadZone ? 0.0 : tiltX;
    final effY = tiltY.abs() < deadZone ? 0.0 : tiltY;

    // 方向：前倾（y 负）→ 前进；后倾（y 正）→ 后退
    int direction = 0;
    if (effY < 0) {
      direction = 1;
    } else if (effY > 0) {
      direction = -1;
    }

    // 转向：右倾（x 正）→ 右转；左倾（x 负）→ 左转
    int turn = 0;
    if (effX > 0) {
      turn = 1;
    } else if (effX < 0) {
      turn = -1;
    }

    // 速度：倾斜幅度 → 0-100
    final mag = math.sqrt(effX * effX + effY * effY);
    final speedPct = (mag / maxTilt * 100).round().clamp(0, 100);

    // 节流：距上次发送 < throttleMs 则丢弃
    final now = DateTime.now();
    if (now.difference(_lastSent).inMilliseconds < throttleMs) return;
    _lastSent = now;

    _controller.add(ControlCommand(
      direction: direction,
      turn: turn,
      speedPct: speedPct,
    ));
  }

  /// 释放资源（取消订阅、关闭流）。
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _controller.close();
  }
}
