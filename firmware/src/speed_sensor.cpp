/**
 * speed_sensor.cpp - 红外测速任务实现 (Task 3)
 *
 * 双红外对射模块 → 中断脉冲计数 → 10ms 窗口换算 RPM/线速度。
 * 设计依据: .trae/specs/smart-bt-camera-car/spec.md
 * 物理参数与引脚定义见 config.h。
 */
#include <Arduino.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "config.h"
#include "speed_sensor.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ============================================================
 * IR 脉冲累计（ISR 写入，任务读取并清零）
 * ============================================================ */
static volatile uint32_t g_left_pulses = 0;
static volatile uint32_t g_right_pulses = 0;

/* 共享测速数据 + 自旋锁
 * 同一把锁同时保护 SpeedData 写入与脉冲计数器的"读-清零"原子操作
 * (portENTER_CRITICAL 会屏蔽同级中断，因此 ISR 期间不会抢占) */
static SpeedData g_speed_data;
static portMUX_TYPE g_speed_mux = portMUX_INITIALIZER_UNLOCKED;

/* ============================================================
 * IR 中断服务函数
 * 槽型光耦被遮挡时输出低电平，故取 FALLING 边沿对应"进入遮挡"事件。
 * ISR 内仅做自增，保持极短，避免占用中断时间。
 * ============================================================ */
static void IRAM_ATTR isr_left() {
    portENTER_CRITICAL_ISR(&g_speed_mux);
    g_left_pulses++;
    portEXIT_CRITICAL_ISR(&g_speed_mux);
}

static void IRAM_ATTR isr_right() {
    portENTER_CRITICAL_ISR(&g_speed_mux);
    g_right_pulses++;
    portEXIT_CRITICAL_ISR(&g_speed_mux);
}

/* ============================================================
 * 初始化 IR 引脚与中断
 * ============================================================ */
bool speed_sensor_init() {
    // 清零共享数据
    memset(&g_speed_data, 0, sizeof(g_speed_data));
    g_left_pulses = 0;
    g_right_pulses = 0;

    // 上拉：典型槽型光耦为开漏输出，未遮挡时保持高电平
    pinMode(SPEED_IR_LEFT_GPIO, INPUT_PULLUP);
    pinMode(SPEED_IR_RIGHT_GPIO, INPUT_PULLUP);

    // 挂 FALLING 边沿中断（匹配槽型光耦遮挡→下降沿）
    attachInterrupt(digitalPinToInterrupt(SPEED_IR_LEFT_GPIO),  isr_left,  FALLING);
    attachInterrupt(digitalPinToInterrupt(SPEED_IR_RIGHT_GPIO), isr_right, FALLING);

    return true;
}

/* ============================================================
 * 线程安全地获取测速数据快照（避免读写撕裂）
 * ============================================================ */
SpeedData speed_sensor_get() {
    SpeedData snapshot;
    portENTER_CRITICAL(&g_speed_mux);
    snapshot = g_speed_data;
    portEXIT_CRITICAL(&g_speed_mux);
    return snapshot;
}

/* ============================================================
 * 测速任务：每 CONTROL_PERIOD_MS (10ms) 计算一次
 * 公式严格遵循 spec.md "转速测量" 章节：
 *   RPM = (pulses × 60) / (window_sec × ENCODER_SLOTS)
 *   v   = π × D × RPM / 60
 * ============================================================ */
void speed_task(void* arg) {
    (void)arg;
    TickType_t last_wake = xTaskGetTickCount();
    const TickType_t period = pdMS_TO_TICKS(CONTROL_PERIOD_MS);
    uint32_t last_ms = millis();

    for (;;) {
        // 固定 10ms 节拍（vTaskDelayUntil 周期模式，与 motor_task 对齐）
        vTaskDelayUntil(&last_wake, period);

        uint32_t now_ms = millis();
        uint32_t delta_ms = now_ms - last_ms;
        last_ms = now_ms;
        if (delta_ms == 0) {
            delta_ms = 1;  // 防止除零
        }

        // 临界区：原子地读取并清零脉冲计数
        uint32_t left_pulses, right_pulses;
        portENTER_CRITICAL(&g_speed_mux);
        left_pulses  = g_left_pulses;
        right_pulses = g_right_pulses;
        g_left_pulses  = 0;
        g_right_pulses = 0;
        portEXIT_CRITICAL(&g_speed_mux);

        // RPM = (pulses × 60000) / (delta_ms × ENCODER_SLOTS)
        // 推导: 60 / (delta_ms/1000) = 60000/delta_ms
        // pulses × 60000 在 uint32 范围内安全（10ms 窗口脉冲数有限）
        uint32_t left_rpm_u  = (left_pulses  * 60000UL) / (delta_ms * ENCODER_SLOTS);
        uint32_t right_rpm_u = (right_pulses * 60000UL) / (delta_ms * ENCODER_SLOTS);

        // 饱和到 int16 范围，避免有符号溢出为负值
        if (left_rpm_u  > 32767) left_rpm_u  = 32767;
        if (right_rpm_u > 32767) right_rpm_u = 32767;

        // 线速度 v_mm_s = π × WHEEL_DIAMETER_MM × RPM / 60
        float wheel_circ_mm = (float)M_PI * (float)WHEEL_DIAMETER_MM;
        float left_v_mm_s   = wheel_circ_mm * (float)left_rpm_u  / 60.0f;
        float right_v_mm_s  = wheel_circ_mm * (float)right_rpm_u / 60.0f;

        // 线速度同样饱和到 int16 范围
        if (left_v_mm_s  > 32767.0f) left_v_mm_s  = 32767.0f;
        if (right_v_mm_s > 32767.0f) right_v_mm_s = 32767.0f;

        SpeedData update;
        update.left_rpm         = (int16_t)left_rpm_u;
        update.right_rpm        = (int16_t)right_rpm_u;
        update.left_speed_mm_s  = (int16_t)left_v_mm_s;
        update.right_speed_mm_s = (int16_t)right_v_mm_s;
        update.last_update_ms   = now_ms;

        // 临界区写入共享数据，避免与 speed_sensor_get() 撕裂
        portENTER_CRITICAL(&g_speed_mux);
        g_speed_data = update;
        portEXIT_CRITICAL(&g_speed_mux);
    }
}
