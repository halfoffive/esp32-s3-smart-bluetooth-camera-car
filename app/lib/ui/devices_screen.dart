// devices_screen.dart - 设备管理页
//
// 扫描 / 发现 / 连接 / 断开 BLE 设备。
// 通过 bleControllerProvider 监听 BleState，按 status 分支渲染：
//   scanning   → 进度条 + 雷达脉冲 + 「扫描中...」提示，扫描按钮显示但禁用
//   其他       → 「扫描设备」按钮可点
//   connected  → 设备卡片（名称 + ID + 「断开」）
//   发现列表   → 逐项 ListTile + 「连接」（扫描中/已连接时禁用）
//   errorMessage != null → SnackBar 弹出错误（ref.listen，不在 build 内副作用）

import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_controller.dart';
import '../ble/ble_permissions.dart';
import 'settings_route.dart';
import 'theme.dart';

/// 设备连接页（应用入口）：扫描、连接、断开 BLE 设备。
///
/// 连接成功后由 _AppRouter 自动切换到控制页。
/// 设置藏在 AppBar 菜单中。
class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  @override
  void initState() {
    super.initState();
    // 首帧后主动请求 BLE 权限，不阻塞 UI；用户点击扫描时再次检查兜底。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BlePermissions.requestAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bleControllerProvider);
    final cs = Theme.of(context).colorScheme;

    // 错误反馈的 SnackBar 监听已上移到 _AppRouter root Scaffold，
    // 避免子页不可见时错误 SnackBar 弹到隐藏的 Scaffold。

    // 已连接设备名称：从扫描结果按 id 查找（连接后 BleState 仅保留 deviceId）。
    final connectedDevice = state.deviceId == null
        ? null
        : _findDevice(state.discoveredDevices, state.deviceId!);

    final adapterOff = state.adapterState == BluetoothAdapterState.off ||
        state.adapterState == BluetoothAdapterState.unknown;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备连接'),
        actions: [_buildMenu(context)],
      ),
      body: Column(
        children: [
          // ---- 蓝牙关闭横幅 ----
          if (adapterOff)
            MaterialBanner(
              content: Text(
                state.adapterState == BluetoothAdapterState.unknown
                    ? '蓝牙状态未知，请检查蓝牙是否开启'
                    : '蓝牙已关闭，请先开启蓝牙',
              ),
              actions: [
                TextButton(
                  onPressed: () => _handleTurnOn(context),
                  child: Text(
                    Platform.isAndroid
                        ? '开启蓝牙'
                        : Platform.isWindows
                            ? '打开蓝牙设置'
                            : '我知道了',
                  ),
                ),
              ],
            ),

          // ---- 主体内容 ----
          Expanded(
            child: Column(
              children: [
                // ---- 扫描控制区 ----
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScanButton(
                        isScanning: state.status == ConnectionStatus.scanning,
                        onPressed: () => ref
                            .read(bleControllerProvider.notifier)
                            .startScan(),
                      ),
                      if (state.status == ConnectionStatus.scanning) ...[
                        const SizedBox(height: 24),
                        const Center(child: _RadarPulse()),
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('扫描中...'),
                      ],
                    ],
                  ),
                ),

                // ---- 已连接设备卡片 ----
                if (state.status == ConnectionStatus.connected)
                  _SlideInFromTop(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: HudStatus.active,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _displayName(connectedDevice) ?? '已连接设备',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                  ),

                // ---- 设备列表 ----
                Expanded(
                  child: state.discoveredDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 48,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                state.status == ConnectionStatus.scanning
                                    ? '正在搜索设备...'
                                    : '暂无设备',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.status == ConnectionStatus.scanning
                                    ? '请确保小车已上电并进入广播状态'
                                    : '点击上方按钮开始扫描',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
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
                            return _AnimatedListItem(
                              index: index,
                              child: Card(
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  title: Text(_displayName(device) ?? '未知设备'),
                                  subtitle: Text(device.device.remoteId.str),
                                  trailing: FilledButton.tonal(
                                    onPressed: connectDisabled
                                        ? null
                                        : () => ref
                                            .read(bleControllerProvider.notifier)
                                            .connect(device),
                                    child: const Text('连接'),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// AppBar 菜单：设置。
  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: '菜单',
      onSelected: (value) {
        if (value == 'settings') {
          Navigator.push(context, buildSettingsRoute());
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 12),
              Text('设置'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Android 直接请求打开蓝牙；Windows 打开系统蓝牙设置；其他平台仅给出提示。
void _handleTurnOn(BuildContext context) async {
  if (Platform.isAndroid) {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      // 用户拒绝或系统错误时静默处理，横幅仍会继续显示
      debugPrint('[DeviceConnectionScreen] turnOn error: $e');
    }
  } else if (Platform.isWindows) {
    try {
      await Process.run('cmd', ['/c', 'start', 'ms-settings:bluetooth']);
    } catch (e) {
      debugPrint('[DeviceConnectionScreen] open BT settings error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开蓝牙设置，请手动开启')),
      );
    }
  } else {
    // iOS / macOS / Linux 不支持 API 直接开启蓝牙，提示用户去系统设置
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在系统设置中开启蓝牙')),
    );
  }
}

/// 在已发现设备列表中按 remoteId 查找扫描结果。
ScanResult? _findDevice(List<ScanResult> devices, String id) {
  for (final d in devices) {
    if (d.device.remoteId.str == id) return d;
  }
  return null;
}

/// 优先使用广播名，回退到系统缓存名。
String? _displayName(ScanResult? result) {
  if (result == null) return null;
  return result.advertisementData.advName.isNotEmpty
      ? result.advertisementData.advName
      : result.device.platformName;
}

/// 带按压缩放反馈的扫描按钮。
class _ScanButton extends StatefulWidget {
  final bool isScanning;
  final VoidCallback onPressed;

  const _ScanButton({required this.isScanning, required this.onPressed});

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // 用 Listener 而不用 GestureDetector，避免与 FilledButton 内部 InkWell
    // 在手势竞技场中冲突，导致按压缩放不触发。
    return Listener(
      onPointerDown: widget.isScanning
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: widget.isScanning
          ? null
          : (_) => setState(() => _pressed = false),
      onPointerCancel: widget.isScanning
          ? null
          : (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !widget.isScanning ? 0.96 : 1.0,
        duration: AppAnim.durations.touch,
        curve: AppAnim.curves.spring,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.isScanning ? null : widget.onPressed,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('扫描设备'),
          ),
        ),
      ),
    );
  }
}

/// 雷达脉冲动画：扫描时三个圆环依次从中心向外扩散并淡出。
class _RadarPulse extends StatefulWidget {
  const _RadarPulse();

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final t = (_controller.value + i * 0.25) % 1.0;
              final size = 40.0 + t * 80.0;
              final opacity = (1 - Curves.easeOutQuad.transform(t)) * 0.5;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary.withValues(alpha: opacity),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// 列表项进入动画：从下方 16px 淡入上移，支持按 index stagger。
class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedListItem({required this.child, required this.index});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnim.durations.pageTransition,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppAnim.curves.emphasized,
    );
    // index ≥ 5 后停止 stagger 延迟，避免长列表后段进入过慢。
    Future.delayed(Duration(milliseconds: (widget.index.clamp(0, 5)) * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// 从顶部滑入并淡入的容器，用于已连接设备卡片。
class _SlideInFromTop extends StatefulWidget {
  final Widget child;

  const _SlideInFromTop({required this.child});

  @override
  State<_SlideInFromTop> createState() => _SlideInFromTopState();
}

class _SlideInFromTopState extends State<_SlideInFromTop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnim.durations.pageTransition,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppAnim.curves.spring,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(_animation),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.18),
            end: Offset.zero,
          ).animate(_animation),
          child: widget.child,
        ),
      ),
    );
  }
}
