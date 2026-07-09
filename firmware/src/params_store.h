/**
 * params_store.h - PID / 物理参数 NVS 持久化接口
 *
 * App 下发 CMD_SET_PARAMS 后，固件调用本模块保存到 NVS；
 * motor_init / speed_sensor_init 启动时调用 *_load 从 NVS 恢复
 * （无已存值时回退 config.h 编译期默认）。
 */
#pragma once
#ifndef PARAMS_STORE_H
#define PARAMS_STORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* PID 参数（f32）+ 加速时长（u32 ms） */
bool params_store_save_pid(float kp, float ki, float kd, uint32_t ramp_ms);
bool params_store_load_pid(float* kp_out, float* ki_out, float* kd_out, uint32_t* ramp_ms_out);

/* 物理参数（u16 + u16 + u8） */
bool params_store_save_physical(uint16_t wheel_dia_mm, uint16_t wheel_base_mm, uint8_t enc_slots);
bool params_store_load_physical(uint16_t* wheel_dia_out, uint16_t* wheel_base_out, uint8_t* enc_slots_out);

#ifdef __cplusplus
}
#endif

#endif // PARAMS_STORE_H
