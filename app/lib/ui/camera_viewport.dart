// camera_viewport.dart - 摄像头画面 + FPV 风格 HUD 覆盖层
//
// 监听 frameStreamProvider，渲染 JPEG 帧；HUD 显示：
//   - 左上：BLE 连接状态芯片
//   - 右上：实时 FPS（按帧到达频率估算，1 秒滑动窗口）
//   - 四角：警示橙 bracket 装饰（FPV 图传感）
//   - 底部居中：当前速度（大号橙色等宽数字）
// 断流时显示占位 "等待画面..."。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import 'theme.dart';

/// 摄像头视口 + HUD 覆盖层。
class CameraViewport extends ConsumerWidget {
  const CameraViewport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(frameStreamProvider);

    return Container(
      color: AppColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ---- 视频层 ----
          frameAsync.when(
            data: (bytes) => Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            loading: () => const _Placeholder(text: '等待画面...'),
            error: (e, _) => _Placeholder(text: '画面错误: $e'),
          ),

          // ---- 顶/底渐变暗角，提升 HUD 可读性 ----
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.18, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // ---- HUD 覆盖层 ----
          Positioned.fill(child: _HudOverlay(frameAsync: frameAsync)),
        ],
      ),
    );
  }
}

/// HUD 覆盖层：连接状态 / FPS / 速度 / 四角 bracket。
///
/// 需要状态以维护 FPS 滑动窗口（每帧 didUpdateWidget 触发计数），
/// 故为 ConsumerStatefulWidget，由 CameraViewport（ConsumerWidget）持有。
class _HudOverlay extends ConsumerStatefulWidget {
  const _HudOverlay({required this.frameAsync});

  final AsyncValue<Uint8List> frameAsync;

  @override
  ConsumerState<_HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends ConsumerState<_HudOverlay> {
  /// 最近 1 秒内的帧时间戳（ms since epoch）
  final List<int> _frameTimes = <int>[];

  @override
  void didUpdateWidget(covariant _HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 帧数据变化时记录时间戳，并裁剪到 1 秒窗口
    final cur = widget.frameAsync.value;
    final prev = oldWidget.frameAsync.value;
    if (cur != null && !identical(cur, prev)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _frameTimes.add(now);
      _frameTimes.removeWhere((t) => now - t > 1000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleControllerProvider);
    final telemetry = ref.watch(telemetryStreamProvider).value;

    // 当前线速度 = 左右轮平均，mm/s → cm/s
    final speedCmS = (telemetry == null)
        ? null
        : ((telemetry.leftSpeedMmS + telemetry.rightSpeedMmS) / 2) / 10.0;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 四角 bracket 装饰
          ..._cornerBrackets(),

          // 左上：连接状态
          Positioned(
            top: 10,
            left: 12,
            child: _HudChip(
              icon: _statusIcon(bleState.status),
              color: _statusColor(bleState.status),
              text: _statusText(bleState.status),
            ),
          ),

          // 右上：FPS
          Positioned(
            top: 10,
            right: 12,
            child: _HudChip(
              text: '${_frameTimes.length} FPS',
              color: AppColors.dataActive,
            ),
          ),

          // 底部居中：速度
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: speedCmS == null ? '——' : speedCmS.toStringAsFixed(1),
                      style: AppTheme.mono(
                        size: 34,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    TextSpan(
                      text: ' cm/s',
                      style: AppTheme.mono(
                        size: 12,
                        color: AppColors.hudTextDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 四角 bracket 装饰（FPV 风格）。
  List<Widget> _cornerBrackets() {
    const side = 18.0;
    return [
      Positioned(
        top: 6,
        left: 6,
        child: CustomPaint(
          size: const Size(side, side),
          painter: const _BracketPainter(
            corner: _Corner.topLeft,
            color: AppColors.accent,
          ),
        ),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: CustomPaint(
          size: const Size(side, side),
          painter: const _BracketPainter(
            corner: _Corner.topRight,
            color: AppColors.accent,
          ),
        ),
      ),
      Positioned(
        bottom: 6,
        left: 6,
        child: CustomPaint(
          size: const Size(side, side),
          painter: const _BracketPainter(
            corner: _Corner.bottomLeft,
            color: AppColors.accent,
          ),
        ),
      ),
      Positioned(
        bottom: 6,
        right: 6,
        child: CustomPaint(
          size: const Size(side, side),
          painter: const _BracketPainter(
            corner: _Corner.bottomRight,
            color: AppColors.accent,
          ),
        ),
      ),
    ];
  }

  IconData _statusIcon(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return Icons.link;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.reconnecting:
        return Icons.sync_problem;
      case ConnectionStatus.scanning:
        return Icons.search;
      case ConnectionStatus.disconnected:
        return Icons.link_off;
    }
  }

  Color _statusColor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return AppColors.dataActive;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
      case ConnectionStatus.scanning:
        return AppColors.warn;
      case ConnectionStatus.disconnected:
        return AppColors.danger;
    }
  }

  String _statusText(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中';
      case ConnectionStatus.reconnecting:
        return '重连中';
      case ConnectionStatus.scanning:
        return '扫描中';
      case ConnectionStatus.disconnected:
        return '未连接';
    }
  }
}

/// HUD 信息芯片：图标 + 文字，半透明黑底 + 彩色边。
class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.text,
    this.icon,
    this.color = AppColors.hudText,
  });

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: AppTheme.mono(size: 11, color: color)),
        ],
      ),
    );
  }
}

/// 断流占位。
class _Placeholder extends StatelessWidget {
  const _Placeholder({this.text = '等待画面...'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, size: 48, color: AppColors.hudTextDim),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.hudTextDim)),
        ],
      ),
    );
  }
}

/// 四角 bracket 朝向。
enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// 画一个 L 形 bracket。
class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.corner, required this.color});

  final _Corner corner;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final w = size.width;
    final h = size.height;
    final path = Path();
    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, h);
        path.lineTo(0, 0);
        path.lineTo(w, 0);
        break;
      case _Corner.topRight:
        path.moveTo(0, 0);
        path.lineTo(w, 0);
        path.lineTo(w, h);
        break;
      case _Corner.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(0, h);
        path.lineTo(w, h);
        break;
      case _Corner.bottomRight:
        path.moveTo(w, 0);
        path.lineTo(w, h);
        path.lineTo(0, h);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}
