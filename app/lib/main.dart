// 智能蓝牙摄像头小车遥控 App 入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ble_controller.dart';
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
  ProviderSubscription<BleState>? _bleSub;

  @override
  void initState() {
    super.initState();
    // 错误反馈监听注册延迟到第一帧渲染完成（addPostFrameCallback），
    // 确保 ScaffoldMessenger 已挂载，避免 initState 阶段 context 未完全可用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bleSub = ref.listenManual<BleState>(bleControllerProvider, (previous, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != previous?.errorMessage) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(msg)));
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _bleSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack 保活三个 tab：切换时不重建子页，
    // 保留 BLE 连接与摄像头流。
    return Scaffold(
      body: IndexedStack(
        sizing: StackFit.expand,
        index: _currentIndex,
        children: const [
          _DriveTab(),
          DevicesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i != _currentIndex) {
            setState(() => _currentIndex = i);
          }
        },
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

/// 驾驶 tab：摄像头视口 + 遥测面板 + 操控面板。
///
/// 包 Scaffold 与其他 tab 结构对称（DevicesScreen/SettingsScreen 均有 Scaffold），
/// 消除裸 Column 在 IndexedStack loose 约束下的 sizing 风险；
/// 无 AppBar 保留全屏沉浸感，SafeArea 处理状态栏/刘海。
class _DriveTab extends StatelessWidget {
  const _DriveTab();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: CameraViewport()),
            TelemetryPanel(),
            Expanded(flex: 2, child: ControlPanel()),
          ],
        ),
      ),
    );
  }
}
