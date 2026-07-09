// devices_screen.dart - 设备管理页
//
// 扫描 / 发现 / 连接 / 断开 BLE 设备。
// 通过 bleControllerProvider 监听 BleState，按 status 分支渲染：
//   scanning   → 进度条 + 「扫描中...」提示，扫描按钮显示但禁用
//   其他       → 「扫描设备」按钮可点
//   connected  → 设备卡片（名称 + ID + 「断开」）
//   发现列表   → 逐项 ListTile + 「连接」（扫描中/已连接时禁用）
//   errorMessage != null → SnackBar 弹出错误（ref.listen，不在 build 内副作用）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 仅需 DiscoveredDevice 类型；隐藏 flutter_reactive_ble 自带的 ConnectionStatus，
// 让本文件统一使用 ble_controller.dart 中定义的 ConnectionStatus enum。
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide ConnectionStatus;

import '../ble/ble_controller.dart';

/// 设备管理页：扫描、连接、断开 BLE 设备。
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleControllerProvider);
    final cs = Theme.of(context).colorScheme;

    // 错误反馈的 SnackBar 监听已上移到 HomeScreen root Scaffold，
    // 避免设备 tab 不可见时错误 SnackBar 弹到隐藏的 Scaffold。

    // 已连接设备名称：从扫描结果按 id 查找（连接后 BleState 仅保留 deviceId）。
    final connectedDevice = state.deviceId == null
        ? null
        : _findDevice(state.discoveredDevices, state.deviceId!);

    return Scaffold(
      appBar: AppBar(title: const Text('设备')),
      body: Column(
        children: [
          // ---- 扫描控制区 ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.status == ConnectionStatus.scanning
                        ? null
                        : () => ref
                            .read(bleControllerProvider.notifier)
                            .startScan(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('扫描设备'),
                  ),
                ),
                if (state.status == ConnectionStatus.scanning) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('扫描中...'),
                ],
              ],
            ),
          ),

          // ---- 已连接设备卡片 ----
          if (state.status == ConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connectedDevice?.name ?? '已连接设备',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.deviceId ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(bleControllerProvider.notifier)
                            .disconnect(),
                        child: const Text('断开'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ---- 设备列表 ----
          Expanded(
            child: state.discoveredDevices.isEmpty
                ? Center(
                    child: Text(
                      state.status == ConnectionStatus.scanning
                          ? '正在搜索设备...'
                          : '暂无设备，点击上方按钮扫描',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = state.discoveredDevices[index];
                      // 扫描中或已连接时禁用「连接」
                      final connectDisabled =
                          state.status == ConnectionStatus.scanning ||
                              state.status == ConnectionStatus.connected;
                      return ListTile(
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: FilledButton.tonal(
                          onPressed: connectDisabled
                              ? null
                              : () => ref
                                  .read(bleControllerProvider.notifier)
                                  .connect(device),
                          child: const Text('连接'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 在已发现设备列表中按 id 查找设备。
DiscoveredDevice? _findDevice(List<DiscoveredDevice> devices, String id) {
  for (final d in devices) {
    if (d.id == id) return d;
  }
  return null;
}
