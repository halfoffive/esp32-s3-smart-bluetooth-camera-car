// 智能蓝牙摄像头小车遥控 App 入口
//
// 导航流程（spec 要求）：
//   打开应用 -> 设备连接页（扫描/连接）
//   连接成功 -> 控制页（横屏：摄像头 + 单摇杆）
//   设置藏在菜单栏（AppBar PopupMenuButton），不占底部导航。
//
// 路由由 bleControllerProvider.status 驱动，无 IndexedStack：
//   connected       -> ControlScreen（横屏锁定）
//   其它（含扫描/连接中/重连）-> DeviceConnectionScreen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ble_controller.dart';
import 'ui/control_screen.dart';
import 'ui/devices_screen.dart';
import 'ui/settings_screen.dart';
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
      home: const _AppRouter(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// 顶层路由：按 BLE 连接状态在「设备连接页」与「控制页」之间切换。
///
/// 错误反馈 SnackBar 监听挂在 root，确保任意子页可见时都能弹出。
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  ProviderSubscription<BleState>? _bleSub;

  @override
  void initState() {
    super.initState();
    // 错误反馈监听延迟到第一帧，确保 ScaffoldMessenger 已挂载。
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
    final status = ref.watch(bleControllerProvider.select((s) => s.status));
    // 连接成功才进入控制页；连接中/重连中保留在设备连接页以便观察状态。
    if (status == ConnectionStatus.connected) {
      return const ControlScreen();
    }
    return const DeviceConnectionScreen();
  }
}
