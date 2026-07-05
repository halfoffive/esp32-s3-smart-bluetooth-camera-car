/**
 * crc8.h - CRC8 校验（header-only inline 实现）
 *
 * 多项式: 0x07
 * 初始值: 0x00
 * 反射输入/输出: 否
 * 输出异或: 0x00
 *
 * 与 SMBUS/CRC-8/AUTOSAR 多项式一致，无反射、无输出异或。
 * 用于智能蓝牙摄像头小车二进制协议帧校验。
 */
#pragma once
#ifndef CRC8_H
#define CRC8_H

#include <stdint.h>
#include <stddef.h>

/**
 * 计算 CRC8（多项式 0x07，初始 0x00，无反射，无输出异或）
 * @param data 待校验数据
 * @param len  数据长度
 * @return CRC8 值
 */
static inline uint8_t crc8(const uint8_t* data, size_t len) {
    uint8_t crc = 0x00;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; bit++) {
            if (crc & 0x80) {
                crc = (uint8_t)((crc << 1) ^ 0x07);
            } else {
                crc = (uint8_t)(crc << 1);
            }
        }
    }
    return crc;
}

#endif // CRC8_H
