// control_panel.dart - 操控面板
//
// 上半：根据模式显示虚拟摇杆 / 体感提示 / 键盘提示。
// 下半：模式切换（摇杆/体感/键盘，按平台显示适用项）+ 紧急停车按钮。
//
// 摇杆释放时（onChanged(0,0)）发送 stop：speed_pct=0 但保留上次方向。
// 体感/键盘控制器输出 ControlCommand 流，统一由 _onControlCommand 下发 BLE。

import 'dart:async' show StreamSubscription;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import '../input/keyboard_controller.dart';
import '../input/tilt_controller.dart';
import 'joystick.dart';
import 'theme.dart';

/// 操控模式
enum ControlMode { joystick, tilt, keyboard }

/// 操控面板（公开类签名 ConsumerWidget，per spec）。
///
/// 需要状态以追踪上次方向（释放时保留 direction），故委托给私有
/// _ControlPanelBody（ConsumerStatefulWidget）。
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ControlPanelBody();
  }
}

class _ControlPanelBody extends ConsumerStatefulWidget {
  const _ControlPanelBody();

  @override
  ConsumerState<_ControlPanelBody> createState() => _ControlPanelBodyState();
}

class _ControlPanelBodyState extends ConsumerState<_ControlPanelBody> {
  /// 上次方向（释放时保留以告知固件"前进-停止"而非"方向变更-停止"）
  int _lastDirection = 0;

  /// 当前操控模式（initState 中按平台初始化）
  late ControlMode _mode;

  // ---- 体感控制器 ----
  TiltController? _tiltController;
  StreamSubscription<ControlCommand>? _tiltSub;

  // ---- 键盘控制器 ----
  KeyboardController? _keyboardController;
  FocusNode? _keyboardFocusNode;
  StreamSubscription<ControlCommand>? _keyboardSub;

  @override
  void initState() {
    super.initState();
    // 桌面端默认键盘模式，移动端默认摇杆模式
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    _mode = isDesktop ? ControlMode.keyboard : ControlMode.joystick;
    _setupMode(_mode);
  }

  @override
  void dispose() {
    _disposeInputControllers();
    super.dispose();
  }

  /// 释放所有输入控制器与订阅
  void _disposeInputControllers() {
    _tiltSub?.cancel();
    _tiltSub = null;
    _tiltController?.dispose();
    _tiltController = null;

    _keyboardSub?.cancel();
    _keyboardSub = null;
    _keyboardController?.dispose();
    _keyboardController = null;
    _keyboardFocusNode?.dispose();
    _keyboardFocusNode = null;
  }

  /// 切换模式：dispose 旧控制器 → 停车 → 新建
  void _setMode(ControlMode mode) {
    if (_mode == mode) return;
    _disposeInputControllers();
    // 切换模式时下发停车，防止小车保持上次运动状态
    ref.read(bleControllerProvider.notifier).sendControl(_lastDirection, 0, 0);
    _lastDirection = 0;
    _setupMode(mode);
    setState(() => _mode = mode);
  }

  /// 按模式创建对应控制器（不触发 setState）
  void _setupMode(ControlMode mode) {
    switch (mode) {
      case ControlMode.joystick:
        // 摇杆模式：无后台控制器，由 Joystick widget 直接回调
        break;
      case ControlMode.tilt:
        _tiltController = TiltController();
        _tiltController!.start();
        _tiltSub = _tiltController!.stream.listen(_onControlCommand);
        break;
      case ControlMode.keyboard:
        _keyboardController = KeyboardController();
        _keyboardFocusNode = FocusNode();
        _keyboardSub = _keyboardController!.stream.listen(_onControlCommand);
        break;
    }
  }

  /// 体感/键盘控制指令统一回调
  void _onControlCommand(ControlCommand cmd) {
    if (!mounted) return;
    if (cmd.direction != 0) _lastDirection = cmd.direction;
    ref.read(bleControllerProvider.notifier).sendControl(
          cmd.direction,
          cmd.turn,
          cmd.speedPct,
        );
  }

  /// 摇杆回调：归一化 (dx, dy) → 协议 (direction, turn, speedPct)。
  void _onJoystick(double dx, double dy) {
    final notifier = ref.read(bleControllerProvider.notifier);

    // 释放：发送 stop，保留上次方向
    if (dx == 0 && dy == 0) {
      notifier.sendControl(_lastDirection, 0, 0);
      return;
    }

    // 方向：dy 上为正 → 前进
    int direction = 0;
    if (dy > 0.15) {
      direction = 1;
    } else if (dy < -0.15) {
      direction = -1;
    }

    // 转向：dx 右为正 → 右转
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
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // ---- 上半：操控区 ----
          Expanded(child: _buildInputArea()),
          const SizedBox(height: 10),
          // ---- 下半：模式切换 + 紧急停车 ----
          Row(
            children: [
              _buildModeSwitch(isDesktop, isMobile),
              const Spacer(),
              // 紧急停车
              FilledButton.icon(
                onPressed: _emergencyStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: const Text('紧急停车'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 根据模式构建操控区
  Widget _buildInputArea() {
    switch (_mode) {
      case ControlMode.joystick:
        return Center(
          child: LayoutBuilder(
            builder: (context, c) {
              final side = (c.maxHeight < c.maxWidth
                      ? c.maxHeight
                      : c.maxWidth) *
                  0.95;
              return SizedBox(
                width: side,
                height: side,
                child: Joystick(onChanged: _onJoystick),
              );
            },
          ),
        );
      case ControlMode.tilt:
        return _buildTiltHint();
      case ControlMode.keyboard:
        return Focus(
          focusNode: _keyboardFocusNode,
          onKeyEvent: _keyboardController!.onKeyEvent,
          autofocus: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _keyboardFocusNode?.requestFocus(),
            child: _buildKeyboardHint(),
          ),
        );
    }
  }

  /// 体感模式提示
  Widget _buildTiltHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.screen_rotation, size: 64, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            '请倾斜手机操控',
            style: TextStyle(
              color: AppColors.hudText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '前倾前进 · 后倾后退 · 左右倾转向',
            style: TextStyle(color: AppColors.hudTextDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 键盘模式提示卡片（W A S D）
  Widget _buildKeyboardHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '键盘操控',
            style: TextStyle(
              color: AppColors.hudText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // W 键（前进）
          _buildKey('W'),
          const SizedBox(height: 4),
          // A S D 键（左转 / 后退 / 右转）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('A'),
              _buildKey('S'),
              _buildKey('D'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '方向键也可用 · 默认速度 80%',
            style: TextStyle(color: AppColors.hudTextDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 单个按键卡片
  Widget _buildKey(String label) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.hudText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 模式切换按钮（按平台显示适用模式）
  Widget _buildModeSwitch(bool isDesktop, bool isMobile) {
    final segments = <ButtonSegment<ControlMode>>[
      const ButtonSegment(value: ControlMode.joystick, label: Text('摇杆')),
    ];
    if (isMobile) {
      segments.add(
        const ButtonSegment(value: ControlMode.tilt, label: Text('体感')),
      );
    }
    if (isDesktop) {
      segments.add(
        const ButtonSegment(value: ControlMode.keyboard, label: Text('键盘')),
      );
    }
    return SegmentedButton<ControlMode>(
      segments: segments,
      selected: {_mode},
      onSelectionChanged: (s) => _setMode(s.first),
    );
  }
}
