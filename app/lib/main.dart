// 智能蓝牙摄像头小车遥控 App 入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/camera_viewport.dart';
import 'ui/control_panel.dart';
import 'ui/settings_screen.dart';
import 'ui/telemetry_panel.dart';
import 'ui/theme.dart';
import 'ui/theme_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动时恢复用户上次选择的主题模式（默认跟随系统）
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).load();
  runApp(UncontrolledProviderScope(
    container: container,
    child: const SmartCarApp(),
  ));
}

class SmartCarApp extends ConsumerWidget {
  const SmartCarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '智能小车遥控',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
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
