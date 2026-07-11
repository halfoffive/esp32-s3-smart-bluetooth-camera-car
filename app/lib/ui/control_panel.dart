// control_panel.dart - 单摇杆操控面板（横屏右侧列）
//
// 仅虚拟摇杆 + 紧急停车，符合 spec「使用单电子摇杆控制」。
// 摇杆释放时（onChanged(0,0)）发送 stop：speed_pct=0 但保留上次方向，
// 告知固件「前进-停止」而非「方向变更-停止」。
// 连续摇动 80ms 节流，防 BLE 写入队列过载。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import 'joystick.dart';
import 'theme.dart';

/// 单摇杆操控面板（公开类签名 ConsumerStatefulWidget）。
///
/// 需要状态追踪上次方向（释放时保留 direction）与节流时间戳。
class ControlPanel extends ConsumerStatefulWidget {
  const ControlPanel({super.key});

  @override
  ConsumerState<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends ConsumerState<ControlPanel> {
  /// 上次方向（释放时保留以告知固件"前进-停止"而非"方向变更-停止"）
  int _lastDirection = 0;

  /// 上次摇杆发送时间戳（80ms 节流，防 BLE 写入队列过载）
  DateTime? _lastJoystickSend;

  /// 摇杆回调：归一化 (dx, dy) -> 协议 (direction, turn, speedPct)。
  void _onJoystick(double dx, double dy) {
    final notifier = ref.read(bleControllerProvider.notifier);

    // 释放：发送 stop，保留上次方向（释放事件不节流，确保及时停车）
    if (dx == 0 && dy == 0) {
      notifier.sendControl(_lastDirection, 0, 0);
      return;
    }

    // 80ms 节流：连续摇动时限制下发频率，避免 BLE 写入队列过载
    final now = DateTime.now();
    if (_lastJoystickSend != null &&
        now.difference(_lastJoystickSend!) <
            const Duration(milliseconds: 80)) {
      return;
    }
    _lastJoystickSend = now;

    // 方向：dy 上为正 -> 前进
    int direction = 0;
    if (dy > 0.15) {
      direction = 1;
    } else if (dy < -0.15) {
      direction = -1;
    }

    // 转向：dx 右为正 -> 右转
    int turn = 0;
    if (dx > 0.15) {
      turn = 1;
    } else if (dx < -0.15) {
      turn = -1;
    }

    // 速度百分比 = 摇杆模长 × 100
    final mag = math.sqrt(dx * dx + dy * dy);
    final speedPct = (mag * 100).round().clamp(0, 100);

    if (direction != 0) _lastDirection = direction;

    notifier.sendControl(direction, turn, speedPct);
  }

  /// 紧急停车：等价 motor_stop，立即下发 (0, 0, 0)。
  Future<void> _emergencyStop() async {
    _lastDirection = 0;
    await ref.read(bleControllerProvider.notifier).sendControl(0, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ---- 摇杆区 ----
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  // 取宽高较短边构建方形摇杆
                  final side =
                      (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth) *
                          0.95;
                  return SizedBox(
                    width: side,
                    height: side,
                    child: Joystick(onChanged: _onJoystick),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ---- 紧急停车 ----
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _emergencyStop,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: const Text('紧急停车'),
              style: FilledButton.styleFrom(
                backgroundColor: HudStatus.dangerOf(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
