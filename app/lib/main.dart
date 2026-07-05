// 智能蓝牙摄像头小车遥控 App 入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/camera_viewport.dart';
import 'ui/control_panel.dart';
import 'ui/settings_screen.dart';
import 'ui/telemetry_panel.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: SmartCarApp()));
}

class SmartCarApp extends ConsumerWidget {
  const SmartCarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '智能小车遥控',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      routes: {
        '/settings': (ctx) => const SettingsScreen(),
      },
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能小车遥控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '参数设置',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(flex: 3, child: CameraViewport()),
          TelemetryPanel(),
          Expanded(flex: 2, child: ControlPanel()),
        ],
      ),
    );
  }
}
