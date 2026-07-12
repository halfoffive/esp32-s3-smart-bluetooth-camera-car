// settings_screen.dart - 参数设置页
//
// 表单：PID Kp/Ki/Kd、T_ramp、轮径、轮距、编码器槽数 + WiFi 配置。
// 本地 shared_preferences 持久化（键名前缀 car_），已连接设备时同步下发。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_controller.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

/// 设置页：PID + 物理参数表单 + WiFi 配置。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wifiFormKey = GlobalKey<FormState>();

  final _kpCtrl = TextEditingController();
  final _kiCtrl = TextEditingController();
  final _kdCtrl = TextEditingController();
  final _tRampCtrl = TextEditingController();
  final _wheelDiameterCtrl = TextEditingController();
  final _wheelBaseCtrl = TextEditingController();
  final _encoderSlotsCtrl = TextEditingController();
  final _ssidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  /// 从 shared_preferences 读取已保存值（缺失则用 spec 默认值）。
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _kpCtrl.text = (prefs.getDouble('car_kp') ?? 2.0).toString();
    _kiCtrl.text = (prefs.getDouble('car_ki') ?? 0.0).toString();
    _kdCtrl.text = (prefs.getDouble('car_kd') ?? 0.5).toString();
    _tRampCtrl.text = (prefs.getDouble('car_t_ramp') ?? 1.5).toString();
    _wheelDiameterCtrl.text =
        (prefs.getDouble('car_wheel_diameter') ?? 65).toString();
    _wheelBaseCtrl.text = (prefs.getDouble('car_wheel_base') ?? 130).toString();
    _encoderSlotsCtrl.text =
        (prefs.getInt('car_encoder_slots') ?? 20).toString();
    if (mounted) setState(() => _loaded = true);
  }

  /// 保存参数：写本地 shared_preferences 兜底 + 下发设备（已连接时）。
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    // 解析表单值（缺失用 spec 默认值兜底）
    final kp = double.tryParse(_kpCtrl.text) ?? 2.0;
    final ki = double.tryParse(_kiCtrl.text) ?? 0.0;
    final kd = double.tryParse(_kdCtrl.text) ?? 0.5;
    final tRamp = double.tryParse(_tRampCtrl.text) ?? 1.5;
    final wheelDiameter = double.tryParse(_wheelDiameterCtrl.text) ?? 65;
    final wheelBase = double.tryParse(_wheelBaseCtrl.text) ?? 130;
    final encoderSlots = int.tryParse(_encoderSlotsCtrl.text) ?? 20;

    // 本地缓存兜底
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('car_kp', kp);
    await prefs.setDouble('car_ki', ki);
    await prefs.setDouble('car_kd', kd);
    await prefs.setDouble('car_t_ramp', tRamp);
    await prefs.setDouble('car_wheel_diameter', wheelDiameter);
    await prefs.setDouble('car_wheel_base', wheelBase);
    await prefs.setInt('car_encoder_slots', encoderSlots);

    // 下发设备（失败时由 BleController.errorMessage 统一展示）
    final errBefore = ref.read(bleControllerProvider).errorMessage;
    await ref.read(bleControllerProvider.notifier).sendParams(
          kp: kp,
          ki: ki,
          kd: kd,
          rampMs: (tRamp * 1000).round(),
          wheelDiameterMm: wheelDiameter.round(),
          wheelBaseMm: wheelBase.round(),
          encoderSlots: encoderSlots,
        );
    if (mounted && ref.read(bleControllerProvider).errorMessage == errBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到设备')),
      );
    }
  }

  /// 下发 WiFi 配置到设备。
  Future<void> _sendWifi() async {
    if (!(_wifiFormKey.currentState?.validate() ?? false)) return;
    _wifiFormKey.currentState?.save();

    final errBefore = ref.read(bleControllerProvider).errorMessage;
    await ref.read(bleControllerProvider.notifier).sendWifiConfig(
          ssid: _ssidCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (mounted && ref.read(bleControllerProvider).errorMessage == errBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi 配置已下发到设备')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _kpCtrl,
      _kiCtrl,
      _kdCtrl,
      _tRampCtrl,
      _wheelDiameterCtrl,
      _wheelBaseCtrl,
      _encoderSlotsCtrl,
      _ssidCtrl,
      _passwordCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connected =
        ref.watch(bleControllerProvider).status == ConnectionStatus.connected;
    return Scaffold(
      appBar: AppBar(title: const Text('参数设置')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 外观段
                _FadeInUp(
                  delayMs: 0,
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('外观'),
                          const ListTile(
                            leading: Icon(Icons.brightness_6_outlined),
                            title: Text('主题模式'),
                            subtitle: Text('默认跟随系统'),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('系统')),
                                ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('浅色')),
                                ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('深色')),
                              ],
                              selected: {ref.watch(themeModeProvider)},
                              onSelectionChanged: (selection) {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .set(selection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // PID + 物理参数表单
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // PID 系数段
                      _FadeInUp(
                        delayMs: 80,
                        child: Card(
                          elevation: 0,
                          color: cs.surfaceContainerLow,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLg),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('PID 系数'),
                                _numField('Kp', _kpCtrl),
                                _numField('Ki', _kiCtrl),
                                _numField('Kd', _kdCtrl),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 物理参数段
                      _FadeInUp(
                        delayMs: 140,
                        child: Card(
                          elevation: 0,
                          color: cs.surfaceContainerLow,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLg),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('物理参数'),
                                _numField('T_ramp (s)', _tRampCtrl),
                                _numField(
                                    '轮径 (mm)', _wheelDiameterCtrl),
                                _numField('轮距 (mm)', _wheelBaseCtrl),
                                _numField('编码器槽数', _encoderSlotsCtrl,
                                    integer: true),
                                const SizedBox(height: 24),
                                _AnimatedActionButton(
                                  label: '保存',
                                  icon: Icons.save_outlined,
                                  onPressed: _save,
                                  enabled: connected,
                                ),
                                if (!connected) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '请先连接设备',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // WiFi 配置段
                _FadeInUp(
                  delayMs: 200,
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _wifiFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('WiFi 配置'),
                            TextFormField(
                              controller: _ssidCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'SSID'),
                              maxLength: 32,
                              validator: (v) => (v == null ||
                                      v.trim().isEmpty)
                                  ? '不能为空'
                                  : null,
                            ),
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: const InputDecoration(
                                  labelText: '密码'),
                              obscureText: true,
                              maxLength: 64,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? '不能为空'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            _AnimatedActionButton(
                              label: '下发到设备',
                              icon: Icons.wifi,
                              onPressed: _sendWifi,
                              enabled: connected,
                            ),
                            if (!connected) ...[
                              const SizedBox(height: 8),
                              Text(
                                '请先连接设备',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 段落小标题。
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// 数字输入字段。
  Widget _numField(String label, TextEditingController ctrl,
      {bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: integer
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        style: AppTheme.mono(size: 14),
        validator: (v) {
          if (v == null || v.isEmpty) return '不能为空';
          if (integer) {
            if (int.tryParse(v) == null) return '需要整数';
          } else {
            if (double.tryParse(v) == null) return '需要数字';
          }
          return null;
        },
      ),
    );
  }
}

/// 带延迟的淡入上移动画。
class _FadeInUp extends StatefulWidget {
  const _FadeInUp({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnim.durations.pageTransition,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppAnim.curves.emphasized,
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// 启用/禁用状态带渐变过渡的操作按钮。
class _AnimatedActionButton extends StatelessWidget {
  const _AnimatedActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.62,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: enabled
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
