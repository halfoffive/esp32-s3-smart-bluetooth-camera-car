//! 控制指令编码（App→固件）
//!
//! 构造完整 BLE 协议帧：`SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD CRC8`
//! PAYLOAD = `direction(1) + turn(1) + speed_pct(1)`，共 3 字节，故 LEN = 4。

use crate::ble::{crc8, CMD_CONTROL, SYNC0, SYNC1};
use flutter_rust_bridge::frb;

/// 编码控制指令为完整 packet 字节流。
///
/// - `direction ∈ {-1, 0, 1}`（-1 后退 / 0 停 / 1 前进）
/// - `turn ∈ {-1, 0, 1}`（-1 左 / 0 直 / 1 右）
/// - `speed_pct ∈ 0..=100`
///
/// 非法输入触发 `assert`（按 Rust 惯例，调用方应保证参数合法）。
/// 如需软失败可改为返回 `Result`，本实现遵循任务约定的 assert 风格。
#[frb(named_args)]
pub fn encode_control(direction: i8, turn: i8, speed_pct: u8) -> Vec<u8> {
    assert!(
        direction == -1 || direction == 0 || direction == 1,
        "direction must be -1/0/1, got {}",
        direction
    );
    assert!(
        turn == -1 || turn == 0 || turn == 1,
        "turn must be -1/0/1, got {}",
        turn
    );
    assert!(speed_pct <= 100, "speed_pct must be 0..=100, got {}", speed_pct);

    // LEN = CMD(1) + PAYLOAD(3) = 4
    let len: u16 = 4;
    let payload: [u8; 3] = [direction as u8, turn as u8, speed_pct];

    // 帧：sync(2) + len(2) + cmd(1) + payload(3) + crc(1) = 8 字节
    let mut buf = Vec::with_capacity(8);
    buf.push(SYNC0);
    buf.push(SYNC1);
    buf.push((len >> 8) as u8); // LEN_HI
    buf.push((len & 0xFF) as u8); // LEN_LO
    buf.push(CMD_CONTROL);
    buf.extend_from_slice(&payload);
    // CRC 覆盖 LEN_HI..PAYLOAD = buf[2..7]
    let crc = crc8(&buf[2..]);
    buf.push(crc);
    buf
}
