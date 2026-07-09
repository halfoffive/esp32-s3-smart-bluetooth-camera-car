//! flutter_rust_bridge 入口模块
//!
//! frb v2 默认扫描 `api.rs` 中的 `pub` 项并生成 Dart 绑定。
//! 本模块整合 BLE 协议解析、JPEG 重组、控制编码等子模块，
//! 并提供面向 Flutter 的高层便捷 API。
//!
//! 注：子模块文件平铺于 `src/`，由 crate 根 `lib.rs` 声明为 `pub mod`
//! （兄弟文件内通过 `crate::ble` 等路径互引）；本模块通过 `pub use` 重导出
//! 常用类型与高层 API 供 frb codegen 扫描。

use flutter_rust_bridge::frb;

// 重新导出常用类型，便于 Flutter 侧直接引用
pub use crate::ble::{ControlPayload, ImageChunk, PacketKind, TelemetryPayload};
pub use crate::control::encode_control;
pub use crate::control::{encode_set_params, encode_set_wifi};
pub use crate::image::ImageAssembler;

/// 构造一个新的 ImageAssembler 实例供 Dart 侧使用。
#[frb(sync)]
pub fn create_image_assembler() -> ImageAssembler {
    ImageAssembler::new()
}

/// 处理来自 BLE NOTIFY 的原始包。
///
/// - 图像分片：推入 `assembler`，完整帧返回 JPEG 字节
/// - 遥测：由 Flutter 侧直接 `parse_packet` 取用，这里不处理
/// - 其它（控制回环 / 未知）：返回 `None`
pub fn handle_notify_packet(assembler: &mut ImageAssembler, raw: Vec<u8>) -> Option<Vec<u8>> {
    // 解析失败（帧不完整 / 校验失败）直接返回 None
    let packet = crate::ble::parse_packet(&raw)?;
    match packet {
        PacketKind::Image(chunk) => assembler.push(chunk),
        // 遥测由 Flutter 侧直接 parse_packet 取用；控制回环 / 未知：不处理
        _ => None,
    }
}
