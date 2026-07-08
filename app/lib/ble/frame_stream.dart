// frame_stream.dart - 图像帧流组装与遥测解析
//
// 依赖 flutter_rust_bridge codegen 生成的 Dart 绑定：
//   flutter_rust_bridge_codegen generate
// 产物路径（frb v2 默认）：
//   package:smart_car_remote/src/rust/api.dart        —— handleNotifyPacket / ImageAssembler
//   package:smart_car_remote/src/rust/ble.dart        —— parsePacket / PacketKind / TelemetryPayload
//
// 若实际 codegen 输出的类型名/方法签名与下方假设不符（如 handleNotifyPacket
// 返回 (ImageAssembler, U8Array?) 元组而非原地修改），请相应调整：
//   1. 若 &mut ImageAssembler 被生成为「按值传递并返回修改后实例」，
//      则需将 _assembler 重新赋值为返回值（见 _handleImagePacket 注释）。
//   2. 若 frb 为 i8 参数生成 Int8 包装类型，sendControl 处需适配。

// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:typed_data';

// frb codegen 绑定 —— 首次拉取须先 flutter_rust_bridge_codegen generate
import 'package:smart_car_remote/src/rust/api.dart' as rust;
import 'package:smart_car_remote/src/rust/ble.dart' as ble;
import 'package:smart_car_remote/src/rust/image.dart' as image;

/// 遥测数据（Dart 侧不可变模型）。
///
/// 字段与 Rust `TelemetryPayload`（ble.rs）一一对应，由 [TelemetryParser] 从
/// NOTIFY 包解析后构造。线速度单位 mm/s、电池单位 mV，与固件协议一致。
class Telemetry {
  final int leftRpm;
  final int rightRpm;
  final int leftSpeedMmS;
  final int rightSpeedMmS;
  final int targetSpeedMmS;
  final int batteryMv;

  const Telemetry({
    required this.leftRpm,
    required this.rightRpm,
    required this.leftSpeedMmS,
    required this.rightSpeedMmS,
    required this.targetSpeedMmS,
    required this.batteryMv,
  });

  @override
  String toString() =>
      'Telemetry(L:$leftRpm R:$rightRpm rpm | v:$targetSpeedMmS mm/s | bat:$batteryMv mV)';
}

/// 图像帧流组装器。
///
/// 持有 Rust 侧 [rust.ImageAssembler] 实例，逐包调用 [rust.handleNotifyPacket]：
/// 图像分片推入组装器，完整帧返回 JPEG 字节 → 通过 [stream] 广播。
/// 遥测包由该函数返回 None（不在图像流处理）。
///
/// 因 frb v2 跨 FFI 调用为异步，逐包串行化（Future 链）保证分片顺序与
/// Rust 状态机一致——乱序写入 assembler 会导致 total_chunks 判定错误。
class FrameStreamAssembler {
  FrameStreamAssembler() : _assembler = rust.createImageAssembler();

  final image.ImageAssembler _assembler;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  /// 完整 JPEG 帧流，供 UI（Image.memory）订阅渲染。
  Stream<Uint8List> get stream => _controller.stream;

  // 串行化待处理 Future，确保分片按到达顺序送入 Rust assembler
  Future<void> _pending = Future<void>.value();

  /// 处理一条 image 特征 NOTIFY 包。
  ///
  /// 包内含 frame_id/chunk_idx/total_chunks + JPEG 分片数据，
  /// Rust 侧组装完整帧后返回非 null 字节，否则返回 null。
  void handlePacket(Uint8List raw) {
    _pending = _pending.then((_) => _handleImagePacket(raw));
  }

  Future<void> _handleImagePacket(Uint8List raw) async {
    if (_controller.isClosed) return;
    // handleNotifyPacket(&mut assembler, Vec<u8>) -> Option<Vec<u8>>
    // frb v2 将 Vec<u8> / &[u8] 映射为 Uint8List（Uint8List 是 List<int> 子类，
    // 故无论 codegen 生成 Uint8List 还是 List<int> 参数均兼容）。
    // &mut ImageAssembler 默认按 opaque handle 原地修改，仅返回 Option<Vec<u8>>。
    // 若 codegen 改为返回 (assembler, frame) 元组，此处改为：
    //   final result = await rust.handleNotifyPacket(_assembler, raw);
    //   _assembler = result.$1; final frame = result.$2;
    try {
      final frame = await rust.handleNotifyPacket(assembler: _assembler, raw: raw);
      if (frame != null) {
        _controller.add(frame);
      }
    } catch (e) {
      // 吞掉 FFI 异常：避免 _pending 进入错误态导致后续分片解析断链
    }
  }

  /// 释放资源（断开连接时由 BleController 调用）。
  void dispose() {
    _controller.close();
  }
}

/// 遥测流解析器。
///
/// 逐包调用 Rust [ble.parsePacket] 区分包类型：
/// - Telemetry 变体 → 构造 [Telemetry] 广播
/// - 其它（图像/控制/未知）→ 忽略（遥测特征理论上只收遥测包）
///
/// 同样串行化以保证解析顺序，避免并发 FFI 调用竞争。
class TelemetryParser {
  final StreamController<Telemetry> _controller =
      StreamController<Telemetry>.broadcast();

  /// 遥测数据流，供 HUD 面板订阅展示。
  Stream<Telemetry> get stream => _controller.stream;

  Future<void> _pending = Future<void>.value();

  /// 处理一条 telemetry 特征 NOTIFY 包。
  void handlePacket(Uint8List raw) {
    _pending = _pending.then((_) => _handleTelemetryPacket(raw));
  }

  Future<void> _handleTelemetryPacket(Uint8List raw) async {
    if (_controller.isClosed) return;
    // parse_packet(&[u8]) -> Option<PacketKind>
    // frb v2 将 &[u8] 映射为 Uint8List，直接传 raw 即可
    // frb v2 将 Rust enum 生成 sealed class 层级：
    //   PacketKind_Telemetry(TelemetryPayload) 等子类
    try {
      final kind = await ble.parsePacket(buf: raw);
      if (kind == null) return;

      // frb v2 对 tuple variant PacketKind::Telemetry(TelemetryPayload)
      // 默认生成子类 PacketKind_Telemetry，载荷字段名 field0。
      // 若 codegen 配置为 named field，改为 kind.telemetry 之类。
      if (kind is ble.PacketKind_Telemetry) {
        final t = kind.field0;
        _controller.add(Telemetry(
          leftRpm: t.leftRpm,
          rightRpm: t.rightRpm,
          leftSpeedMmS: t.leftSpeedMmS,
          rightSpeedMmS: t.rightSpeedMmS,
          targetSpeedMmS: t.targetSpeedMmS,
          batteryMv: t.batteryMv,
        ));
      }
    } catch (e) {
      // 吞掉 FFI 异常：避免 _pending 进入错误态导致后续遥测解析断链
    }
  }

  /// 释放资源（断开连接时由 BleController 调用）。
  void dispose() {
    _controller.close();
  }
}
