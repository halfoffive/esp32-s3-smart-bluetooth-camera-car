// control_screen.dart - 横屏控制页
//
// 连接成功后展示：左侧摄像头（含 HUD）+ 右侧单摇杆操控列。
// 横屏锁定（landscapeLeft / landscapeRight），离开控制页时恢复全方向
// （设备连接页 / 设置页允许竖屏，表单更友好）。
// 设置与「断开连接」藏在 AppBar 的 PopupMenuButton 中，不占底部导航。
//
// 路由：由 _AppRouter 按 bleControllerProvider.status == connected 切入。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import 'camera_viewport.dart';
import 'control_panel.dart';
import 'telemetry_panel.dart';

/// 控制页：横屏布局，摄像头 + 单摇杆。
class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  @override
  void initState() {
    super.initState();
    // FPV 操控锁定横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 离开控制页恢复全方向
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('驾驶'),
        actions: [_buildMenu()],
      ),
      body: const SafeArea(
        child: Row(
          children: [
            // 左：摄像头（含 HUD）+ 遥测条
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(child: CameraViewport()),
                  TelemetryPanel(),
                ],
              ),
            ),
            // 右：单摇杆 + 紧急停车
            SizedBox(width: 300, child: ControlPanel()),
          ],
        ),
      ),
    );
  }

  /// AppBar 菜单：设置 / 断开连接。
  Widget _buildMenu() {
    return PopupMenuButton<_MenuItem>(
      icon: const Icon(Icons.more_vert),
      tooltip: '菜单',
      onSelected: (item) {
        switch (item) {
          case _MenuItem.settings:
            Navigator.pushNamed(context, '/settings');
          case _MenuItem.disconnect:
            ref.read(bleControllerProvider.notifier).disconnect();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _MenuItem.settings,
          child: Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 12),
              Text('设置'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuItem.disconnect,
          child: Row(
            children: [
              Icon(Icons.link_off),
              SizedBox(width: 12),
              Text('断开连接'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 菜单项。
enum _MenuItem { settings, disconnect }
