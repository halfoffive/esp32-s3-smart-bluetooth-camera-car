// ble_permissions.dart - BLE 运行时权限封装
//
// 职责：按平台聚合所需权限，提供统一请求/判断/引导弹窗接口。
// 依赖：permission_handler

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE 权限请求辅助类。
///
/// 不同平台所需运行时权限不同：
/// - Android：请求 [bluetoothScan]、[bluetoothConnect]；为兼容 Android 11 及以下，
///   额外请求 [location]。permission_handler 会在不需要 location 的系统上自行忽略。
/// - iOS / macOS：请求 [bluetooth]。
/// - Linux / Windows：无需运行时权限，直接视为已授予。
class BlePermissions {
  BlePermissions._();

  static final List<Permission> _required = _buildRequired();

  /// 按平台构造权限列表。
  static List<Permission> _buildRequired() {
    if (Platform.isAndroid) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return [Permission.bluetooth];
    }
    // Linux / Windows 无需运行时权限。
    return [];
  }

  /// 请求所有平台所需 BLE 权限，返回各权限状态映射。
  static Future<Map<Permission, PermissionStatus>> requestAll() async {
    if (_required.isEmpty) {
      return {};
    }
    return _required.request();
  }

  /// 所有必需权限均已授予时返回 true。
  static bool isGranted(Map<Permission, PermissionStatus> statuses) {
    if (_required.isEmpty) return true;
    return statuses.entries.every((e) => e.value.isGranted);
  }

  /// 任一权限被永久拒绝时返回 true，此时应引导用户去系统设置开启。
  static bool isPermanentlyDenied(Map<Permission, PermissionStatus> statuses) {
    return statuses.values.any((s) => s.isPermanentlyDenied);
  }

  /// 任一权限被拒绝但未永久拒绝时返回 true，可在此向用户展示权限用途说明。
  ///
  /// 注意：permission_handler 的 [isDenied] 包含尚未请求与已拒绝两种情况，
  /// 配合 [requestAll] 调用后，可用于判断是否需要显示解释性 rationale。
  static bool shouldShowRationale(Map<Permission, PermissionStatus> statuses) {
    return statuses.values.any((s) => s.isDenied);
  }

  /// 展示权限说明对话框，并提供跳转到应用设置的入口。
  static Future<void> showRationaleDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要蓝牙权限'),
        content: const Text(
          '本应用需要蓝牙权限以扫描并连接智能小车。请在系统设置中开启。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}
