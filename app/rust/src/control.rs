//! 控制指令编码（App→固件）
//!
//! 构造完整 BLE 协议帧：`SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD CRC8`
//! PAYLOAD = `direction(1) + turn(1) + speed_pct(1)`，共 3 字节，故 LEN = 4。

use crate::ble::{crc8, CMD_CONTROL, SYNC0, SYNC1};

/// 编码控制指令为完整 packet 字节流。
///
/// - `direction ∈ {-1, 0, 1}`（-1 后退 / 0 停 / 1 前进）
/// - `turn ∈ {-1, 0, 1}`（-1 左 / 0 直 / 1 右）
/// - `speed_pct ∈ 0..=100`
///
/// 非法输入返回 `Err(String)`，避免 `assert` 跨 FFI 触发 panic
/// （Dart 侧无法捕获 Rust panic，会导致整个进程崩溃）。
pub fn encode_control(direction: i8, turn: i8, speed_pct: u8) -> Result<Vec<u8>, String> {
    if !(-1..=1).contains(&direction) {
        return Err(format!("direction 越界: {}", direction));
    }
    if !(-1..=1).contains(&turn) {
        return Err(format!("turn 越界: {}", turn));
    }
    if speed_pct > 100 {
        return Err(format!("speed_pct 越界: {}", speed_pct));
    }

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
    Ok(buf)
}
