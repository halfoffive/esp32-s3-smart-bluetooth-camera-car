// telemetry_panel.dart - 遥测面板
//
// 监听 telemetryStreamProvider，横向显示 4 列数据 + 电池：
//   左 RPM / 右 RPM / 当前速度 / 目标速度 / 电池电压
// 数值用等宽字体，下方小字标签；电池电压按阈值染色（<6.5V 红 / <7.0V 黄 / 否则绿）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import '../ble/frame_stream.dart';
import 'theme.dart';

/// 遥测面板：横向 4 列 + 电池。
class TelemetryPanel extends ConsumerWidget {
  const TelemetryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final Telemetry? t = ref.watch(telemetryStreamProvider).value;

    // 当前线速度 = 左右轮平均，mm/s → cm/s
    final speedCmS = (t == null)
        ? null
        : ((t.leftSpeedMmS + t.rightSpeedMmS) / 2) / 10.0;
    final targetCmS = t == null ? null : t.targetSpeedMmS / 10.0;

    return Container(
      color: cs.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _cell(context, '左 RPM', t?.leftRpm.toString()),
          _cell(context, '右 RPM', t?.rightRpm.toString()),
          _cell(context, '速度 cm/s', speedCmS?.toStringAsFixed(1)),
          _cell(context, '目标 cm/s', targetCmS?.toStringAsFixed(1)),
          _batteryCell(context, t?.batteryMv ?? 0),
        ],
      ),
    );
  }

  /// 数据单元格：数值（等宽）+ 标签（小字）。
  Widget _cell(BuildContext context, String label, String? value) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value ?? '——',
                style: AppTheme.mono(size: 18, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ) ??
                    TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 电池单元格：电压按阈值染色。0 视为未测，显示 ——。
  Widget _batteryCell(BuildContext context, int mv) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = mv > 0;
    final text = hasValue
        ? '${(mv / 1000).toStringAsFixed(2)} V'
        : '——';
    return Expanded(
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: AppTheme.mono(
                  size: 16,
                  color: _batteryColor(context, mv),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '电池',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ) ??
                    TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 电池电压染色：未测=灰 / <6.5V=红 / <7.0V=黄 / 否则=绿
  Color _batteryColor(BuildContext context, int mv) {
    final cs = Theme.of(context).colorScheme;
    if (mv == 0) return cs.onSurfaceVariant;
    if (mv < 6500) return HudStatus.dangerOf(context);
    if (mv < 7000) return HudStatus.warn;
    return HudStatus.active;
  }
}
