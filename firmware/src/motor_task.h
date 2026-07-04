/**
 * motor_task.h - 电机控制任务接口
 *
 * 职责：
 *   - L298N 双 H 桥驱动（方向引脚 + LEDC PWM）
 *   - 接收目标速度指令（direction/turn/speed_pct）
 *   - 10ms 周期内执行：正弦加速 + 左右轮转速 PID 直线平衡
 *   - 周期上报 TelemetryPayload
 *
 * 依赖：config.h（引脚/PWM/PID 参数）、speed_sensor.h、ble_task.h
 */
#pragma once
#ifndef MOTOR_TASK_H
#define MOTOR_TASK_H

#include <stdint.h>
#include <stdbool.h>
#include "protocol.h"   // ControlPayload

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 初始化 L298N 引脚与 PWM
 * - 4 个方向引脚 pinMode OUTPUT，初始 LOW
 * - LEDC 通道 0/1 配置（左 ENA / 右 ENB），占空比初始 0
 * @return true=成功
 */
bool motor_init();

/**
 * 设置目标速度（由 BLE 控制回调间接调用，或直接测试用）
 * @param direction -1 后退 / 0 停 / 1 前
 * @param turn      -1 左 / 0 直 / 1 右
 * @param speed_pct 0-100，相对 V_MAX_PWM 的百分比
 */
void motor_set_target(int8_t direction, int8_t turn, uint8_t speed_pct);

/**
 * 立即停车（断连保护）
 * - 等价 motor_set_target(0,0,0)，但额外把 PWM 立即写 0
 */
void motor_stop();

/**
 * 电机 FreeRTOS 任务（10ms 周期）
 * - 正弦加速 + PID 直线平衡 + 遥测上报
 * @param arg 未使用
 */
void motor_task(void* arg);

#ifdef __cplusplus
}
#endif

#endif // MOTOR_TASK_H
