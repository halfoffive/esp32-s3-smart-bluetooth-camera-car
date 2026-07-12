// 智能蓝牙摄像头小车遥控 App 入口
//
// 导航流程（spec 要求）：
//   打开应用 -> 启动屏 -> 设备连接页（扫描/连接）
//   连接成功 -> 控制页（横屏：摄像头 + 单摇杆）
//   设置藏在菜单栏（AppBar PopupMenuButton），不占底部导航。
//
// 路由由 bleControllerProvider.status 驱动，无 IndexedStack：
//   connected       -> ControlScreen（横屏锁定）
//   其它（含扫描/连接中/重连）-> DeviceConnectionScreen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ble_controller.dart';
import 'src/rust/frb_generated.dart';
import 'ui/control_screen.dart';
import 'ui/devices_screen.dart';
import 'ui/settings_route.dart';
import 'ui/theme.dart';
import 'ui/theme_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化失败信息；若任意启动步骤抛异常，仍尝试运行 App 并显示回退界面，
  // 避免空白页。
  String? initError;
  final container = ProviderContainer();

  // flutter_rust_bridge v2 要求：在调用任何 Rust 函数前先初始化桥接。
  try {
    await RustLib.init();
  } catch (e) {
    initError = 'Rust 桥接初始化失败：$e';
  }

  // 恢复用户上次选择的主题模式（默认跟随系统）。异常不应阻止 App 启动。
  try {
    await container.read(themeModeProvider.notifier).load();
  } catch (e) {
    initError ??= '主题模式加载失败：$e';
  }

  // 全局构建错误回退：任何未捕获的 widget 构建异常都显示 Material 界面，
  // 而不是 release 模式下的空白屏或 debug 模式下的红屏。
  ErrorWidget.builder = (details) => _ErrorFallback(details: details);

  runApp(UncontrolledProviderScope(
    container: container,
    child: SmartCarApp(initError: initError),
  ));
}

class SmartCarApp extends ConsumerWidget {
  final String? initError;

  const SmartCarApp({super.key, this.initError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '智能小车遥控',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: initError != null
          ? _InitErrorScreen(message: initError!)
          : const _AppWithSplash(),
    );
  }
}

/// 启动屏门控：先展示 [_SplashScreen]，动画结束后进入 [_AppRouter]。
class _AppWithSplash extends StatefulWidget {
  const _AppWithSplash();

  @override
  State<_AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<_AppWithSplash> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return _SplashScreen(
        onComplete: () => setState(() => _showSplash = false),
      );
    }
    return const _AppRouter();
  }
}

/// 启动屏：带图标缩放、标题淡入与进度条。
class _SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final Duration duration;

  const _SplashScreen({
    required this.onComplete,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  // 退出动画：进入完成后播放 280ms 淡出+轻微上移+放大，再回调 onComplete。
  late final AnimationController _exitController;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;
  late final Animation<Offset> _exitSlide;
  bool _exitStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnim.curves.spring),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 1.0, curve: AppAnim.curves.decel),
      ),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: AppAnim.curves.emphasized,
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: AppAnim.curves.emphasized,
      ),
    );
    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.02),
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: AppAnim.curves.emphasized,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_exitStarted) {
        _exitStarted = true;
        _exitController.forward();
      }
    });
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _exitController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _exitFade,
      child: ScaleTransition(
        scale: _exitScale,
        child: SlideTransition(
          position: _exitSlide,
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: Icon(
                      Icons.bluetooth_searching,
                      size: 80,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fade,
                    child: Text(
                      '智能小车遥控',
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fade,
                    child: const SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶层路由：按 BLE 连接状态在「设备连接页」与「控制页」之间切换，并带动画转场。
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
    final child = status == ConnectionStatus.connected
        ? const ControlScreen(key: ValueKey('control'))
        : const DeviceConnectionScreen(key: ValueKey('device'));

    return AnimatedSwitcher(
      duration: AppAnim.durations.pageTransition,
      switchInCurve: AppAnim.curves.standard,
      switchOutCurve: AppAnim.curves.standard,
      transitionBuilder: (child, animation) {
        final isControl = child.key == const ValueKey('control');
        final incoming = Tween<Offset>(
          begin: isControl ? const Offset(0.18, 0.0) : const Offset(-0.18, 0.0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: incoming,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: child,
    );
  }
}

/// 启动错误回退页：当 Rust 桥接或主题模式初始化失败时显示。
///
/// 在 [MaterialApp] 内部使用，因此可以访问主题。
class _InitErrorScreen extends StatelessWidget {
  final String message;

  const _InitErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '应用启动失败',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全局构建错误回退：不依赖外部主题，确保在任何构建阶段都能渲染。
class _ErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;

  const _ErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                '界面渲染出错',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
