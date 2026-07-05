// settings_screen.dart - 参数设置页
//
// 表单：PID Kp/Ki/Kd、T_ramp、轮径、轮距、编码器槽数。
// 用 shared_preferences 持久化，键名前缀 car_。
// 顶部说明：这些参数当前仅本地保存，未来版本可下发设备。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// 设置页：PID + 物理参数表单。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _kpCtrl = TextEditingController();
  final _kiCtrl = TextEditingController();
  final _kdCtrl = TextEditingController();
  final _tRampCtrl = TextEditingController();
  final _wheelDiameterCtrl = TextEditingController();
  final _wheelBaseCtrl = TextEditingController();
  final _encoderSlotsCtrl = TextEditingController();

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

  /// 保存所有字段到 shared_preferences。
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('car_kp', double.tryParse(_kpCtrl.text) ?? 2.0);
    await prefs.setDouble('car_ki', double.tryParse(_kiCtrl.text) ?? 0.0);
    await prefs.setDouble('car_kd', double.tryParse(_kdCtrl.text) ?? 0.5);
    await prefs.setDouble('car_t_ramp', double.tryParse(_tRampCtrl.text) ?? 1.5);
    await prefs.setDouble(
      'car_wheel_diameter',
      double.tryParse(_wheelDiameterCtrl.text) ?? 65,
    );
    await prefs.setDouble(
      'car_wheel_base',
      double.tryParse(_wheelBaseCtrl.text) ?? 130,
    );
    await prefs.setInt(
      'car_encoder_slots',
      int.tryParse(_encoderSlotsCtrl.text) ?? 20,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参数已保存（仅本地）')),
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('参数设置')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 顶部说明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.accent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '这些参数当前仅本地保存，未来版本可下发设备。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.hudTextDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // PID 段
                  _sectionTitle('PID 系数'),
                  _numField('Kp', _kpCtrl),
                  _numField('Ki', _kiCtrl),
                  _numField('Kd', _kdCtrl),
                  const Divider(height: 32),
                  // 物理参数段
                  _sectionTitle('物理参数'),
                  _numField('T_ramp (s)', _tRampCtrl),
                  _numField('轮径 (mm)', _wheelDiameterCtrl),
                  _numField('轮距 (mm)', _wheelBaseCtrl),
                  _numField('编码器槽数', _encoderSlotsCtrl, integer: true),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 段落小标题。
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
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
        keyboardType:
            integer ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.hudTextDim),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
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
