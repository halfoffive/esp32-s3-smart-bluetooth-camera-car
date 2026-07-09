// 智能蓝牙摄像头小车遥控 App 入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/camera_viewport.dart';
import 'ui/control_panel.dart';
import 'ui/devices_screen.dart';
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
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // IndexedStack 保活三个 tab：切换时不重建子页，
    // 保留 BLE 连接与摄像头流。
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DriveTab(),
          DevicesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car),
            label: '驾驶',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 驾驶 tab：摄像头视口 + 遥测面板 + 操控面板（沿用原 HomeScreen body 布局）。
class _DriveTab extends StatelessWidget {
  const _DriveTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(flex: 3, child: CameraViewport()),
        TelemetryPanel(),
        Expanded(flex: 2, child: ControlPanel()),
      ],
    );
  }
}
