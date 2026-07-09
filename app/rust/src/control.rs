//! 控制指令编码（App→固件）
//!
//! 构造完整 BLE 协议帧：`SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD CRC8`
//! - `LEN = CMD(1) + PAYLOAD 字节数`（大端存放）
//! - CRC8 覆盖 `LEN_HI..PAYLOAD` 末字节（即 `buf[2..]`，组帧末追加 CRC）

use crate::ble::{crc8, CMD_CONTROL, CMD_SET_PARAMS, CMD_SET_WIFI, SYNC0, SYNC1};

/// 组装完整协议帧：`SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD CRC8`。
/// LEN = 1(CMD) + payload.len()；CRC 覆盖 LEN_HI..PAYLOAD 末字节。
fn encode_frame(cmd: u8, payload: &[u8]) -> Result<Vec<u8>, String> {
    let len: u16 = 1 + payload.len() as u16;
    let mut buf = Vec::with_capacity(2 + 2 + 1 + payload.len() + 1);
    buf.push(SYNC0);
    buf.push(SYNC1);
    buf.push((len >> 8) as u8);
    buf.push((len & 0xFF) as u8);
    buf.push(cmd);
    buf.extend_from_slice(payload);
    // CRC 覆盖 LEN_HI..PAYLOAD = buf[2..]
    let crc = crc8(&buf[2..]);
    buf.push(crc);
    Ok(buf)
}

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
    let payload: [u8; 3] = [direction as u8, turn as u8, speed_pct];
    encode_frame(CMD_CONTROL, &payload)
}

/// 编码下发参数命令（CMD=0x04）为完整 packet。
///
/// 载荷 21 字节，全部小端：
///   Kp(f32) + Ki(f32) + Kd(f32) + T_ramp_ms(u32) + wheel_diameter_mm(u16)
///   + wheel_base_mm(u16) + encoder_slots(u8)
///
/// 非法输入（NaN / 无穷）返回 `Err`，避免跨 FFI panic。
pub fn encode_set_params(
    kp: f32,
    ki: f32,
    kd: f32,
    ramp_ms: u32,
    wheel_diameter_mm: u16,
    wheel_base_mm: u16,
    encoder_slots: u8,
) -> Result<Vec<u8>, String> {
    if kp.is_nan() || kp.is_infinite() {
        return Err(format!("kp 非法: {}", kp));
    }
    if ki.is_nan() || ki.is_infinite() {
        return Err(format!("ki 非法: {}", ki));
    }
    if kd.is_nan() || kd.is_infinite() {
        return Err(format!("kd 非法: {}", kd));
    }

    // 载荷 21 字节
    let mut payload = Vec::with_capacity(21);
    payload.extend_from_slice(&kp.to_le_bytes());
    payload.extend_from_slice(&ki.to_le_bytes());
    payload.extend_from_slice(&kd.to_le_bytes());
    payload.extend_from_slice(&ramp_ms.to_le_bytes());
    payload.extend_from_slice(&wheel_diameter_mm.to_le_bytes());
    payload.extend_from_slice(&wheel_base_mm.to_le_bytes());
    payload.push(encoder_slots);

    encode_frame(CMD_SET_PARAMS, &payload)
}

/// 编码下发 WiFi 配置命令（CMD=0x05）为完整 packet。
///
/// 载荷 = `ssid_len(u8) + ssid(≤32B) + pass_len(u8) + pass(≤64B)`，长度可变。
/// SSID > 32 或密码 > 64 返回 `Err`。
pub fn encode_set_wifi(ssid: String, password: String) -> Result<Vec<u8>, String> {
    let ssid_bytes = ssid.as_bytes();
    let pass_bytes = password.as_bytes();
    if ssid_bytes.len() > 32 {
        return Err(format!("SSID 过长: {} > 32", ssid_bytes.len()));
    }
    if pass_bytes.len() > 64 {
        return Err(format!("密码过长: {} > 64", pass_bytes.len()));
    }

    let mut payload = Vec::with_capacity(2 + ssid_bytes.len() + pass_bytes.len());
    payload.push(ssid_bytes.len() as u8);
    payload.extend_from_slice(ssid_bytes);
    payload.push(pass_bytes.len() as u8);
    payload.extend_from_slice(pass_bytes);

    encode_frame(CMD_SET_WIFI, &payload)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ble::{crc8, SYNC0, SYNC1};

    /// 通用帧校验：sync 头、LEN 字段、CRC 全部正确
    fn assert_valid_frame(buf: &[u8], cmd: u8, payload_len: usize) {
        assert!(buf.len() >= 6, "帧过短");
        assert_eq!(buf[0], SYNC0, "SYNC0");
        assert_eq!(buf[1], SYNC1, "SYNC1");
        let len = ((buf[2] as u16) << 8) | buf[3] as u16;
        assert_eq!(len as usize, 1 + payload_len, "LEN 字段");
        assert_eq!(buf[4], cmd, "CMD");
        // CRC 覆盖 LEN_HI..PAYLOAD 末字节
        let expected = crc8(&buf[2..buf.len() - 1]);
        assert_eq!(buf[buf.len() - 1], expected, "CRC");
    }

    #[test]
    fn encode_control_still_produces_9_byte_frame() {
        let buf = encode_control(1, 0, 50).unwrap();
        // sync(2) + len(2) + cmd(1) + payload(3) + crc(1) = 9
        assert_eq!(buf.len(), 9);
        assert_valid_frame(&buf, CMD_CONTROL, 3);
    }

    #[test]
    fn encode_set_params_returns_27_byte_frame_with_valid_crc() {
        let buf = encode_set_params(0.8, 0.05, 0.1, 1500, 65, 130, 20).unwrap();
        // 5 头 + 21 载荷 + 1 CRC = 27
        assert_eq!(buf.len(), 27);
        assert_valid_frame(&buf, CMD_SET_PARAMS, 21);
        // 抽样校验 Kp 小端字节（payload[0..4]）
        let kp_bytes = &buf[5..9];
        assert_eq!(kp_bytes, 0.8f32.to_le_bytes());
    }

    #[test]
    fn encode_set_params_rejects_nan_and_infinity() {
        assert!(encode_set_params(f32::NAN, 0.0, 0.0, 0, 0, 0, 0).is_err());
        assert!(encode_set_params(0.0, f32::INFINITY, 0.0, 0, 0, 0, 0).is_err());
        assert!(encode_set_params(0.0, 0.0, f32::NEG_INFINITY, 0, 0, 0, 0).is_err());
    }

    #[test]
    fn encode_set_wifi_returns_expected_length() {
        let buf = encode_set_wifi("MyHome".into(), "12345678".into()).unwrap();
        // payload = 1 + 6 + 1 + 8 = 16；帧 = 5 + 16 + 1 = 22
        assert_eq!(buf.len(), 22);
        assert_valid_frame(&buf, CMD_SET_WIFI, 16);
        // 抽样：ssid_len=6 紧跟 "MyHome"
        assert_eq!(buf[5], 6);
        assert_eq!(&buf[6..12], b"MyHome");
        assert_eq!(buf[12], 8);
        assert_eq!(&buf[13..21], b"12345678");
    }

    #[test]
    fn encode_set_wifi_rejects_overlong_inputs() {
        let long_ssid = "A".repeat(33);
        let long_pass = "B".repeat(65);
        assert!(encode_set_wifi(long_ssid, "ok".into()).is_err());
        assert!(encode_set_wifi("ok".into(), long_pass).is_err());
    }
}
