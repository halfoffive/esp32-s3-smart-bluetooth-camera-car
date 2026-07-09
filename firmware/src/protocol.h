/**
 * protocol.h - 智能蓝牙摄像头小车 二进制协议定义
 *
 * 帧格式（LEN 为大端序，LEN_HI 在前）:
 *   偏移  字段      长度  说明
 *   0     SYNC0     1     固定 0xAA
 *   1     SYNC1     1     固定 0x55
 *   2     LEN_HI    1     高字节，LEN = CMD(1) + PAYLOAD 字节数（不含 sync/len/crc）
 *   3     LEN_LO    1     低字节
 *   4     CMD       1     命令类型：0x01 图像分片 / 0x02 控制 / 0x03 遥测
 *   5..   PAYLOAD   LEN-1 载荷
 *   末    CRC8      1     对 LEN_HI 起到 PAYLOAD 末字节的 CRC8（多项式 0x07，初始 0x00）
 *
 * 总包长 = LEN + 5（sync0 + sync1 + len_hi + len_lo + cmd 占 5 字节，其中 cmd 已计入 LEN）
 * CRC 输入区间 = [LEN_HI .. PAYLOAD 末字节]，长度 = total_len - 3
 */
#pragma once
#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#include "crc8.h"  /* 提供 crc8() 的 static inline 定义 */

/* ============================================================
 * 协议常量（与 config.h 一致；用 #ifndef 保护，允许独立包含本头文件）
 * ============================================================ */
#ifndef PROTO_SYNC0
#define PROTO_SYNC0           0xAA
#endif
#ifndef PROTO_SYNC1
#define PROTO_SYNC1           0x55
#endif

#ifndef CMD_IMAGE_CHUNK
#define CMD_IMAGE_CHUNK       0x01
#endif
#ifndef CMD_CONTROL
#define CMD_CONTROL           0x02
#endif
#ifndef CMD_TELEMETRY
#define CMD_TELEMETRY         0x03
#endif
#ifndef CMD_SET_PARAMS
#define CMD_SET_PARAMS        0x04
#endif
#ifndef CMD_SET_WIFI
#define CMD_SET_WIFI          0x05
#endif

/* ============================================================
 * 静态断言宏（兼容 C/C++）
 * ============================================================ */
#if defined(__cplusplus)
#define PROTO_STATIC_ASSERT(cond, msg) static_assert(cond, msg)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define PROTO_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
#else
#define PROTO_STATIC_ASSERT(cond, msg)
#endif

/* ============================================================
 * 协议帧头（5 字节，无填充）
 * ============================================================ */
#pragma pack(push, 1)
struct ProtoHeader {
    uint8_t sync0;    // 0xAA
    uint8_t sync1;    // 0x55
    uint8_t len_hi;   // LEN 高字节
    uint8_t len_lo;   // LEN 低字节
    uint8_t cmd;      // 命令类型
};
#pragma pack(pop)
PROTO_STATIC_ASSERT(sizeof(struct ProtoHeader) == 5, "ProtoHeader must be 5 bytes");

/* ============================================================
 * CMD=0x01 图像分片载荷头（6 字节，jpeg 数据紧随其后）
 * ============================================================ */
#pragma pack(push, 1)
struct ImageChunkPayload {
    uint16_t frame_id;      // 帧序号
    uint16_t chunk_idx;     // 分片索引（0-based）
    uint16_t total_chunks;  // 总片数
};
#pragma pack(pop)
PROTO_STATIC_ASSERT(sizeof(struct ImageChunkPayload) == 6, "ImageChunkPayload must be 6 bytes");

/* ============================================================
 * CMD=0x02 控制指令载荷（3 字节，App → 固件）
 * ============================================================ */
#pragma pack(push, 1)
struct ControlPayload {
    int8_t  direction;  // -1 后退 / 0 停 / 1 前
    int8_t  turn;       // -1 左 / 0 直 / 1 右
    uint8_t speed_pct;  // 0-100 目标速度百分比（相对 V_MAX_PWM）
};
#pragma pack(pop)
PROTO_STATIC_ASSERT(sizeof(struct ControlPayload) == 3, "ControlPayload must be 3 bytes");

/* ============================================================
 * CMD=0x03 遥测载荷（12 字节，固件 → App）
 * ============================================================ */
#pragma pack(push, 1)
struct TelemetryPayload {
    int16_t  left_rpm;           // 左轮 RPM
    int16_t  right_rpm;          // 右轮 RPM
    int16_t  left_speed_mm_s;    // 左轮线速度 (mm/s)
    int16_t  right_speed_mm_s;   // 右轮线速度 (mm/s)
    int16_t  target_speed_mm_s;  // 目标线速度 (mm/s)
    uint16_t battery_mv;         // 电池电压 (mV)，不可测填 0
};
#pragma pack(pop)
PROTO_STATIC_ASSERT(sizeof(struct TelemetryPayload) == 12, "TelemetryPayload must be 12 bytes");

/* ============================================================
 * CMD=0x04 下发参数载荷（21 字节，App → 固件）
 * 字段顺序与 app/rust/src/ble.rs SetParamsPayload 一致（小端）：
 *   float(4) + float(4) + float(4) + uint32(4) + uint16(2) + uint16(2) + uint8(1) = 21
 * ============================================================ */
#pragma pack(push, 1)
struct SetParamsPayload {
    float    kp;             // 比例系数
    float    ki;             // 积分系数
    float    kd;             // 微分系数
    uint32_t ramp_ms;        // 正弦加速时长 (ms)
    uint16_t wheel_dia_mm;   // 轮径 (mm)
    uint16_t wheel_base_mm;  // 轮距 (mm)
    uint8_t  enc_slots;      // 编码器槽数
};
#pragma pack(pop)
PROTO_STATIC_ASSERT(sizeof(struct SetParamsPayload) == 21, "SetParamsPayload must be 21 bytes");

/* ============================================================
 * 函数实现（static inline，header-only；含 C/C++ 兼容）
 *  - crc8()              由 crc8.h 提供（已 include）
 *  - proto_validate()    校验完整帧（sync/len/CRC8）
 *  - proto_parse_control() 解析控制载荷（调用方应先 proto_validate）
 * ============================================================ */

/**
 * 校验完整协议帧
 * 总包长 = LEN + 5；CRC 输入区间 [2 .. len-2]，长度 = len - 3
 */
static inline bool proto_validate(const uint8_t* buf, size_t len) {
    /* 最小包：SYNC(2) + LEN(2) + CMD(1) + CRC(1) = 6 字节（LEN=1, 无载荷） */
    if (buf == NULL || len < 6) return false;
    if (buf[0] != PROTO_SYNC0) return false;
    if (buf[1] != PROTO_SYNC1) return false;

    uint16_t proto_len = ((uint16_t)buf[2] << 8) | buf[3];
    /* 总包长 = proto_len + 5 */
    if (len != (size_t)proto_len + 5) return false;

    /* CRC 覆盖 LEN_HI 起到 PAYLOAD 末字节：[2 .. len-2] */
    uint8_t expected = crc8(&buf[2], len - 3);
    return expected == buf[len - 1];
}

/**
 * 解析控制指令载荷
 * 假定调用方已通过 proto_validate 完成 CRC 校验
 */
static inline bool proto_parse_control(const uint8_t* buf, size_t len, struct ControlPayload* out) {
    if (buf == NULL || out == NULL) return false;
    if (len < 7) return false;
    if (buf[0] != PROTO_SYNC0 || buf[1] != PROTO_SYNC1) return false;
    if (buf[4] != CMD_CONTROL) return false;

    uint16_t proto_len = ((uint16_t)buf[2] << 8) | buf[3];
    /* 控制载荷长度固定 3 字节，故 proto_len = 1(CMD) + 3 = 4 */
    if (proto_len != (uint16_t)(1 + sizeof(struct ControlPayload))) return false;
    if (len != (size_t)proto_len + 5) return false;

    memcpy(out, &buf[5], sizeof(struct ControlPayload));
    return true;
}

#endif // PROTOCOL_H
