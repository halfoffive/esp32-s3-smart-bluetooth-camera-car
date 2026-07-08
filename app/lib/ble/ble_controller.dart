// ble_controller.dart - BLE 连接层 Riverpod 状态管理
//
// 职责：扫描 / 连接 / 订阅特征 / 写控制指令 / 异常自动重连。
// 状态机节点见 [ConnectionStatus]，状态迁移见文件末尾注释。
//
// 依赖：
//   - flutter_reactive_ble ^5.3.1（BLE 扫描/连接/GATT 读写）
//   - flutter_riverpod ^2.5.1（StateNotifier 状态管理）
//   - flutter_rust_bridge codegen 产物（encode_control 控制指令编码）
//
// frb codegen 绑定路径（须先 flutter_rust_bridge_codegen generate）：
//   package:smart_car_remote/src/rust/control.dart  —— encodeControl

// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// frb codegen 绑定
import 'package:smart_car_remote/src/rust/control.dart' as control_rust;

import 'car_device.dart';
import 'frame_stream.dart';

/* ============================================================
 * 状态模型
 * ============================================================ */

/// 连接状态机节点。
///
/// 迁移图（详见文件末尾）：
///   disconnected → scanning → disconnected（扫描完，待选设备）
///   disconnected → connecting → connected
///   connected → reconnecting → connected / disconnected
///   * → disconnected（用户主动断开）
enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}

/// 哨兵：区分 copyWith 中「不修改」与「置空」
const Object _unset = Object();

/// BLE 不可变状态。
///
/// [frameStream] / [telemetryStream] 不放状态（流非值语义），
/// 而是由 [BleController] 内部持有，通过单独 StreamProvider 暴露。
class BleState {
  final ConnectionStatus status;
  final String? deviceId;
  final String? errorMessage;
  final List<DiscoveredDevice> discoveredDevices;

  const BleState({
    this.status = ConnectionStatus.disconnected,
    this.deviceId,
    this.errorMessage,
    this.discoveredDevices = const [],
  });

  /// 通用 copyWith；nullable 字段传 null 表示置空，省略表示保持。
  BleState copyWith({
    ConnectionStatus? status,
    Object? deviceId = _unset,
    Object? errorMessage = _unset,
    List<DiscoveredDevice>? discoveredDevices,
  }) {
    return BleState(
      status: status ?? this.status,
      deviceId: identical(deviceId, _unset)
          ? this.deviceId
          : deviceId as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }
}

/* ============================================================
 * Provider
 * ============================================================ */

/// BLE 控制器 Provider（全局单例，随 ProviderScope 生命周期 dispose）。
final bleControllerProvider =
    StateNotifierProvider<BleController, BleState>((ref) => BleController());

/// 图像帧流 Provider：UI（Image.memory）通过 ref.watch 读取。
final frameStreamProvider = StreamProvider<Uint8List>((ref) {
  final controller = ref.watch(bleControllerProvider.notifier);
  return controller.frameStream;
});

/// 遥测流 Provider：HUD 面板通过 ref.watch 读取。
final telemetryStreamProvider = StreamProvider<Telemetry>((ref) {
  final controller = ref.watch(bleControllerProvider.notifier);
  return controller.telemetryStream;
});

/* ============================================================
 * BleController
 * ============================================================ */

/// BLE 连接层控制器：封装扫描、连接、特征订阅、控制指令、自动重连。
///
/// 内部维护一个 [FlutterReactiveBle] 实例与若干流订阅；
/// 图像/遥测包分别由 [FrameStreamAssembler] / [TelemetryParser] 解析后
/// 通过广播 StreamController 输出，UI 侧经 StreamProvider 订阅。
class BleController extends StateNotifier<BleState> {
  BleController() : super(const BleState());

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final FrameStreamAssembler _frameAssembler = FrameStreamAssembler();
  final TelemetryParser _telemetryParser = TelemetryParser();

  // ---- 流订阅 ----
  StreamSubscription<DiscoveredDevice>? _scanSub;
  Timer? _scanTimer; // 扫描超时定时器（可取消，避免 dispose 后回调竞态）
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _imageSub;
  StreamSubscription<List<int>>? _telemetrySub;

  // ---- 重连状态 ----
  bool _userDisconnect = false; // 用户主动断开标志
  int _reconnectAttempts = 0; // 已尝试重连次数
  Timer? _reconnectTimer;
  String? _lastDeviceId; // 重连目标
  bool _initializing = false; // _onConnected 重入保护（connected 事件可能重复触发）

  /// 释放资源（ProviderScope dispose 时自动调用）。
  @override
  void dispose() {
    _cancelAllSubscriptions();
    _scanTimer?.cancel();
    _reconnectTimer?.cancel();
    _frameAssembler.dispose();
    _telemetryParser.dispose();
    super.dispose();
  }

  /* ---- 流暴露 ---- */

  /// 完整 JPEG 帧流（供 [frameStreamProvider] 转发）。
  Stream<Uint8List> get frameStream => _frameAssembler.stream;

  /// 遥测数据流（供 [telemetryStreamProvider] 转发）。
  Stream<Telemetry> get telemetryStream => _telemetryParser.stream;

  /* ---- 扫描 ---- */

  /// 扫描 5 秒，过滤设备名 == [CarDeviceConstants.deviceName]。
  ///
  /// 扫描期间匹配设备实时写入 [BleState.discoveredDevices]；
  /// 扫描结束后若发现设备则保持列表供 UI 选择 connect，否则置错误信息。
  Future<void> startScan() async {
    // 已连接时不重新扫描：避免清掉特征订阅导致画面/遥测中断
    if (state.status == ConnectionStatus.connected) return;
    if (state.status == ConnectionStatus.scanning) return;

    // 清理旧订阅（连接订阅除外，避免打断进行中的连接）
    _scanSub?.cancel();
    _scanSub = null;
    _scanTimer?.cancel();
    _scanTimer = null;
    _cancelCharacteristicSubs();

    state = const BleState(status: ConnectionStatus.scanning);

    final found = <DiscoveredDevice>[];
    final done = Completer<void>();

    _scanSub = _ble.scanForDevices(withServices: const []).listen(
      (device) {
        if (device.name == CarDeviceConstants.deviceName &&
            !found.any((d) => d.id == device.id)) {
          found.add(device);
          state = state.copyWith(discoveredDevices: List.of(found));
        }
      },
      onError: (Object e) {
        // 扫描流出错时一并取消超时定时器，避免回调竞态
        _scanTimer?.cancel();
        _scanTimer = null;
        if (!done.isCompleted) {
          state = BleState(
            status: ConnectionStatus.disconnected,
            errorMessage: '扫描失败: $e',
          );
          done.complete();
        }
      },
    );

    // 5 秒后停止扫描并收尾（用 Timer 以便 dispose/重扫时取消，避免回调竞态）
    _scanTimer = Timer(const Duration(seconds: 5), () {
      // 状态已离开 scanning（被取消/重置）则不更新，避免回调竞态
      if (state.status != ConnectionStatus.scanning) return;
      _scanSub?.cancel();
      _scanSub = null;
      _scanTimer = null;
      if (!done.isCompleted) {
        if (found.isEmpty) {
          state = BleState(
            status: ConnectionStatus.disconnected,
            errorMessage: '未发现设备 ${CarDeviceConstants.deviceName}',
          );
        } else {
          // 保持 discoveredDevices 供 UI 选择，状态回 disconnected
          state = BleState(
            status: ConnectionStatus.disconnected,
            discoveredDevices: List.of(found),
          );
        }
        done.complete();
      }
    });

    return done.future;
  }

  /* ---- 连接 ---- */

  /// 连接指定设备：建立连接 → 协商 MTU 512 → 订阅 image/telemetry 特征 → 写控制占位。
  Future<void> connect(DiscoveredDevice device) async {
    _userDisconnect = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelCharacteristicSubs();
    _connSub?.cancel();

    _lastDeviceId = device.id;
    state = BleState(
      status: ConnectionStatus.connecting,
      deviceId: device.id,
    );

    _connSub = _ble.connectToDevice(id: device.id).listen(
      _onConnectionStateChange,
      onError: (Object e) {
        // 连接流异常：触发断开处理（含自动重连）
        _onDisconnected(error: '连接错误: $e');
      },
    );
  }

  /// 连接状态变化回调。
  void _onConnectionStateChange(ConnectionStateUpdate update) {
    switch (update.connectionState) {
      case DeviceConnectionState.connected:
        _onConnected();
        break;
      case DeviceConnectionState.connecting:
        // 已在 connect() 中置 connecting，无需重复
        break;
      case DeviceConnectionState.disconnecting:
        // 中间态，等待 disconnected
        break;
      case DeviceConnectionState.disconnected:
        _onDisconnected();
        break;
    }
  }

  /// 连接成功后：协商 MTU、订阅特征、写控制占位。
  Future<void> _onConnected() async {
    // 重入保护：connected 事件可能重复触发，避免并发初始化破坏订阅
    if (_initializing) return;
    _initializing = true;
    try {
      final deviceId = state.deviceId ?? _lastDeviceId;
      if (deviceId == null) return;

      try {
        // 1) 协商 MTU 512（与固件 BLE_MTU_SIZE 一致）
        await _ble.requestMtu(
          deviceId: deviceId,
          mtu: CarDeviceConstants.negotiatedMtu,
        );

        // 2) 订阅图像与遥测特征
        final imageChar = _qualifiedChar(
          deviceId,
          CarDeviceConstants.imageCharacteristicUuid,
        );
        final telemetryChar = _qualifiedChar(
          deviceId,
          CarDeviceConstants.telemetryCharacteristicUuid,
        );

        _imageSub = _ble.subscribeToCharacteristic(imageChar).listen(
          (bytes) {
            _frameAssembler.handlePacket(Uint8List.fromList(bytes));
          },
          onError: (e) {
            state = state.copyWith(errorMessage: '特征订阅错误: $e');
          },
        );
        _telemetrySub = _ble.subscribeToCharacteristic(telemetryChar).listen(
          (bytes) {
            _telemetryParser.handlePacket(Uint8List.fromList(bytes));
          },
          onError: (e) {
            state = state.copyWith(errorMessage: '特征订阅错误: $e');
          },
        );

        // 3) 先置 connected 状态：sendControl 内部校验 status==connected，
        //    顺序颠倒会导致占位指令被静默丢弃。
        _reconnectAttempts = 0;
        state = state.copyWith(
          status: ConnectionStatus.connected,
          errorMessage: null, // 清除旧错误
        );

        // 4) 写入控制特征占位（零速停机），确认 WRITE 通道可用
        //    直接调用底层写入：sendControl 内部 catch 会吞错，
        //    导致 WRITE 通道失败时 UI 仍假性显示已连接
        try {
          await _ble.writeCharacteristicWithResponse(
            _qualifiedChar(
              deviceId,
              CarDeviceConstants.controlCharacteristicUuid,
            ),
            value: await control_rust.encodeControl(
              direction: 0,
              turn: 0,
              speedPct: 0,
            ),
          );
        } catch (e) {
          // WRITE 通道不通，视为连接失败
          _onDisconnected(error: 'WRITE 通道初始化失败: $e');
          return;
        }
      } catch (e) {
        // requestMtu / 订阅失败：统一走 _onDisconnected 触发重连，
        // 而非直接置 disconnected（否则不会进入重连流程）
        _onDisconnected(error: '连接初始化失败: $e');
      }
    } finally {
      _initializing = false;
    }
  }

  /// 连接断开回调：用户主动断开则不重连；异常断开则启动自动重连。
  void _onDisconnected({String? error}) {
    _cancelCharacteristicSubs();

    if (_userDisconnect) {
      // 用户主动断开：清理后回到 disconnected
      state = BleState(
        status: ConnectionStatus.disconnected,
        discoveredDevices: state.discoveredDevices,
      );
      return;
    }

    // 异常断开：检查重连次数上限
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: error ?? '重连失败（已尝试 $_maxReconnectAttempts 次）',
      );
      return;
    }

    // 启动自动重连（指数退避：1s / 2s / 4s）
    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      errorMessage: error ?? '连接断开，正在重连…',
    );

    final delay = Duration(seconds: 1 << _reconnectAttempts);
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  /// 单次重连尝试：重新建立连接流。
  void _attemptReconnect() {
    final id = _lastDeviceId;
    if (id == null || _userDisconnect) return;

    _connSub?.cancel();
    _connSub = _ble.connectToDevice(id: id).listen(
      _onConnectionStateChange,
      onError: (Object e) => _onDisconnected(error: '重连错误: $e'),
    );
  }

  /// 用户主动断开连接，不触发自动重连。
  Future<void> disconnect() async {
    _userDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelAllSubscriptions();

    state = BleState(
      status: ConnectionStatus.disconnected,
      discoveredDevices: state.discoveredDevices,
    );
  }

  /* ---- 控制指令 ---- */

  /// 发送控制指令。
  ///
  /// 调用 Rust [control_rust.encodeControl] 编码完整协议帧
  /// （sync + len + cmd + payload + crc8），写入控制特征（withResponse 保证可靠性）。
  ///
  /// 参数：
  /// - [direction] -1 后退 / 0 停 / 1 前进
  /// - [turn]      -1 左 / 0 直 / 1 右
  /// - [speedPct]  0-100 目标速度百分比
  Future<void> sendControl(int direction, int turn, int speedPct) async {
    if (state.status != ConnectionStatus.connected) return;
    final deviceId = state.deviceId;
    if (deviceId == null) return;

    try {
      // Rust 纯函数编码（control.rs::encode_control）
      final packet = await control_rust.encodeControl(
        direction: direction,
        turn: turn,
        speedPct: speedPct,
      );

      final char = _qualifiedChar(
        deviceId,
        CarDeviceConstants.controlCharacteristicUuid,
      );
      await _ble.writeCharacteristicWithResponse(char, value: packet);
    } catch (e) {
      state = state.copyWith(errorMessage: '控制指令发送失败: $e');
    }
  }

  /* ---- 内部辅助 ---- */

  /// 最大重连次数
  static const int _maxReconnectAttempts = 3;

  /// 构造 [QualifiedCharacteristic]。
  QualifiedCharacteristic _qualifiedChar(String deviceId, String charUuid) {
    return QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse(CarDeviceConstants.serviceUuid),
      characteristicId: Uuid.parse(charUuid),
    );
  }

  /// 取消图像/遥测特征订阅。
  void _cancelCharacteristicSubs() {
    _imageSub?.cancel();
    _imageSub = null;
    _telemetrySub?.cancel();
    _telemetrySub = null;
  }

  /// 取消所有流订阅（扫描 + 连接 + 特征）。
  void _cancelAllSubscriptions() {
    _scanSub?.cancel();
    _scanSub = null;
    _scanTimer?.cancel();
    _scanTimer = null;
    _cancelCharacteristicSubs();
    _connSub?.cancel();
    _connSub = null;
  }
}

/* ============================================================
 * BleState 状态机说明
 * ============================================================
 *
 * 节点：ConnectionStatus
 *   disconnected  — 初始 / 已断开（含扫描完成待选、重连耗尽）
 *   scanning       — 正在扫描 5s
 *   connecting     — connectToDevice 已发起，等待 connected 事件
 *   connected      — MTU 协商 + 特征订阅完成，帧/遥测流活跃
 *   reconnecting   — 异常断开后退避重连中（1s/2s/4s，最多 3 次）
 *
 * 迁移：
 *   [初始]                     → disconnected
 *   startScan()                → scanning
 *   扫描 5s 到 + 无匹配         → disconnected (errorMessage)
 *   扫描 5s 到 + 有匹配         → disconnected (discoveredDevices 非空)
 *   connect(device)            → connecting
 *   onConnected (MTU+订阅+占位) → connected
 *   连接流 onError / disconnected 事件（非用户主动）
 *                              → reconnecting (attempts < 3) / disconnected (耗尽)
 *   重连 Timer 到 → connectToDevice → connecting → connected / 循环
 *   disconnect()               → disconnected（_userDisconnect=true，不重连）
 *
 * 流暴露：
 *   frameStream    — FrameStreamAssembler 广播完整 JPEG 帧
 *   telemetryStream — TelemetryParser 广播 Telemetry 对象
 *   均通过 frameStreamProvider / telemetryStreamProvider 供 UI 订阅。
 */
