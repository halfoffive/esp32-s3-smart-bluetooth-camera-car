//! BLE 协议帧解析与 CRC8 校验
//!
//! 与固件 `protocol.h` 二进制帧格式完全一致：
//! `SYNC0 SYNC1 LEN_HI LEN_LO CMD PAYLOAD.. CRC8`
//!
//! - `LEN = CMD(1) + PAYLOAD 字节数`（LEN_HI 在前，大端存放长度字段）
//! - 多字节载荷字段（frame_id / chunk_idx / rpm ...）一律小端
//! - CRC8：多项式 0x07，初始 0x00，无反射，覆盖 `LEN_HI..PAYLOAD`（不含 SYNC、不含 CRC 自身）

/// 同步头字节 0
pub const SYNC0: u8 = 0xAA;
/// 同步头字节 1
pub const SYNC1: u8 = 0x55;

/// 命令类型：图像分片
pub const CMD_IMAGE: u8 = 0x01;
/// 命令类型：控制指令（App→固件）
pub const CMD_CONTROL: u8 = 0x02;
/// 命令类型：遥测数据（固件→App）
pub const CMD_TELEMETRY: u8 = 0x03;

/// CRC8 校验（多项式 0x07，初始 0x00，无反射，无最终 XOR）。
/// 纯函数：对任意字节切片计算校验值。
pub fn crc8(data: &[u8]) -> u8 {
    let mut crc: u8 = 0;
    for &b in data {
        crc ^= b;
        for _ in 0..8 {
            if crc & 0x80 != 0 {
                crc = (crc << 1) ^ 0x07;
            } else {
                crc <<= 1;
            }
        }
    }
    crc
}

/// 图像分片载荷（CMD=0x01）
pub struct ImageChunk {
    pub frame_id: u16,
    pub chunk_idx: u16,
    pub total_chunks: u16,
    pub jpeg_bytes: Vec<u8>,
}

/// 控制指令载荷（CMD=0x02，App→固件）
pub struct ControlPayload {
    pub direction: i8,
    pub turn: i8,
    pub speed_pct: u8,
}

/// 遥测载荷（CMD=0x03，固件→App）
pub struct TelemetryPayload {
    pub left_rpm: i16,
    pub right_rpm: i16,
    pub left_speed_mm_s: i16,
    pub right_speed_mm_s: i16,
    pub target_speed_mm_s: i16,
    pub battery_mv: u16,
}

/// 解析后的包类型
pub enum PacketKind {
    Image(ImageChunk),
    Control(ControlPayload),
    Telemetry(TelemetryPayload),
    /// 帧结构合法但 CMD 未识别
    Unknown,
}

/// 解析完整 packet：校验 sync + len + crc，按 CMD 分发到子解析器。
///
/// 返回 `None` 表示帧不完整或校验失败；返回 `Some(Unknown)` 表示帧合法但 CMD 未知。
pub fn parse_packet(buf: &[u8]) -> Option<PacketKind> {
    // 最小帧：sync(2) + len(2) + cmd(1) + crc(1) = 6 字节
    if buf.len() < 6 {
        return None;
    }
    if buf[0] != SYNC0 || buf[1] != SYNC1 {
        return None;
    }
    // LEN 字段为大端（LEN_HI 在前）
    let len = ((buf[2] as u16) << 8) | (buf[3] as u16);
    // LEN 至少为 1（CMD 占 1 字节）；len=0 会导致后续 &buf[5..total-1]=&buf[5..4] 越界 panic
    if len < 1 {
        return None;
    }
    // 总帧长 = sync(2) + len字段(2) + LEN值 + crc(1)
    let total = 2 + 2 + len as usize + 1;
    if buf.len() < total {
        return None;
    }
    // CRC 覆盖 LEN_HI..PAYLOAD = buf[2 .. total-1]
    let crc_region = &buf[2..total - 1];
    if crc8(crc_region) != buf[total - 1] {
        return None;
    }
    let cmd = buf[4];
    let payload = &buf[5..total - 1];
    match cmd {
        CMD_IMAGE => parse_image_chunk(payload).map(PacketKind::Image),
        CMD_CONTROL => parse_control(payload).map(PacketKind::Control),
        CMD_TELEMETRY => parse_telemetry(payload).map(PacketKind::Telemetry),
        _ => Some(PacketKind::Unknown),
    }
}

/// 解析图像分片载荷：6 字节头部 + 剩余 jpeg_bytes
fn parse_image_chunk(payload: &[u8]) -> Option<ImageChunk> {
    if payload.len() < 6 {
        return None;
    }
    let frame_id = u16::from_le_bytes([payload[0], payload[1]]);
    let chunk_idx = u16::from_le_bytes([payload[2], payload[3]]);
    let total_chunks = u16::from_le_bytes([payload[4], payload[5]]);
    let jpeg_bytes = payload[6..].to_vec();
    Some(ImageChunk { frame_id, chunk_idx, total_chunks, jpeg_bytes })
}

/// 解析控制指令载荷：direction / turn / speed_pct 各 1 字节
fn parse_control(payload: &[u8]) -> Option<ControlPayload> {
    if payload.len() < 3 {
        return None;
    }
    Some(ControlPayload {
        direction: payload[0] as i8,
        turn: payload[1] as i8,
        speed_pct: payload[2],
    })
}

/// 解析遥测载荷：3×i16 + 2×i16 + 1×u16 = 12 字节，全部小端
fn parse_telemetry(payload: &[u8]) -> Option<TelemetryPayload> {
    if payload.len() < 12 {
        return None;
    }
    let left_rpm = i16::from_le_bytes([payload[0], payload[1]]);
    let right_rpm = i16::from_le_bytes([payload[2], payload[3]]);
    let left_speed_mm_s = i16::from_le_bytes([payload[4], payload[5]]);
    let right_speed_mm_s = i16::from_le_bytes([payload[6], payload[7]]);
    let target_speed_mm_s = i16::from_le_bytes([payload[8], payload[9]]);
    let battery_mv = u16::from_le_bytes([payload[10], payload[11]]);
    Some(TelemetryPayload {
        left_rpm,
        right_rpm,
        left_speed_mm_s,
        right_speed_mm_s,
        target_speed_mm_s,
        battery_mv,
    })
}
