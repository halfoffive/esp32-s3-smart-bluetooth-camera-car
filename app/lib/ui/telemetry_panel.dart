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
    final Telemetry? t = ref.watch(telemetryStreamProvider).value;

    // 当前线速度 = 左右轮平均，mm/s → cm/s
    final speedCmS = (t == null)
        ? null
        : ((t.leftSpeedMmS + t.rightSpeedMmS) / 2) / 10.0;
    final targetCmS = t == null ? null : t.targetSpeedMmS / 10.0;

    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _cell('左 RPM', t?.leftRpm.toString()),
          _cell('右 RPM', t?.rightRpm.toString()),
          _cell('速度 cm/s', speedCmS?.toStringAsFixed(1)),
          _cell('目标 cm/s', targetCmS?.toStringAsFixed(1)),
          _batteryCell(t?.batteryMv ?? 0),
        ],
      ),
    );
  }

  /// 数据单元格：数值（等宽）+ 标签（小字）。
  Widget _cell(String label, String? value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? '——',
            style: AppTheme.mono(size: 18, color: AppColors.hudText),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.hudTextDim,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  /// 电池单元格：电压按阈值染色。0 视为未测，显示 ——。
  Widget _batteryCell(int mv) {
    final hasValue = mv > 0;
    final text = hasValue
        ? '${(mv / 1000).toStringAsFixed(2)} V'
        : '——';
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTheme.mono(
              size: 16,
              color: _batteryColor(mv),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '电池',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.hudTextDim,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  /// 电池电压染色：未测=灰 / <6.5V=红 / <7.0V=黄 / 否则=绿
  Color _batteryColor(int mv) {
    if (mv == 0) return AppColors.hudTextDim;
    if (mv < 6500) return AppColors.danger;
    if (mv < 7000) return AppColors.warn;
    return AppColors.dataActive;
  }
}
