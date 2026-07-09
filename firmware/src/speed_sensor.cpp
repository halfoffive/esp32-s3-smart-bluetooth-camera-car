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
#include "params_store.h"  // params_store_load_physical

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ============================================================
 * IR 脉冲累计（ISR 写入，任务读取并清零）
 * ============================================================ */
static volatile uint32_t g_left_pulses = 0;
static volatile uint32_t g_right_pulses = 0;

/* 物理参数（App 下发覆盖，speed_task 读取）
 * u16/u8 单字读写 ESP32 上原子，10ms 周期容忍跨字段不一致，无需 mutex
 * g_wheel_base_mm 当前未参与换算，仅持久化以备转向半径等后续计算 */
static volatile uint16_t g_wheel_dia_mm = WHEEL_DIAMETER_MM;
static volatile uint16_t g_wheel_base_mm = WHEEL_TRACK_MM;
static volatile uint8_t  g_enc_slots = ENCODER_SLOTS;

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

    /* NVS 加载物理参数：无已存值时回退 config.h 编译期默认 */
    uint16_t wheel_dia = WHEEL_DIAMETER_MM;
    uint16_t wheel_base = WHEEL_TRACK_MM;
    uint8_t  enc_slots = ENCODER_SLOTS;
    if (params_store_load_physical(&wheel_dia, &wheel_base, &enc_slots)) {
        g_wheel_dia_mm = wheel_dia;
        g_wheel_base_mm = wheel_base;
        g_enc_slots = enc_slots;
    }

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

void speed_sensor_set_physical(uint16_t wheel_dia_mm, uint16_t wheel_base_mm, uint8_t enc_slots) {
    /* 单字写原子，无需 critical section */
    g_wheel_dia_mm = wheel_dia_mm;
    g_wheel_base_mm = wheel_base_mm;
    g_enc_slots = enc_slots;
}

/* ============================================================
 * 测速任务：每 CONTROL_PERIOD_MS (10ms) 计算一次
 * 公式严格遵循 spec.md "转速测量" 章节：
 *   RPM = (pulses × 60) / (window_sec × enc_slots)
 *   v   = π × wheel_dia_mm × RPM / 60
 * （enc_slots / wheel_dia_mm 为运行时变量，由 NVS 或 config.h 默认提供）
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

        // 物理参数快照（volatile 单字读原子，本周期内一致）
        const uint16_t wheel_dia_mm = g_wheel_dia_mm;
        const uint8_t  enc_slots   = g_enc_slots;

        // RPM = (pulses × 60000) / (delta_ms × enc_slots)
        // 推导: 60 / (delta_ms/1000) = 60000/delta_ms
        // pulses × 60000 在 uint32 范围内安全（10ms 窗口脉冲数有限）
        uint32_t divisor = delta_ms * (uint32_t)enc_slots;
        if (divisor == 0) divisor = 1;  // 防御：enc_slots 异常时避免除零
        uint32_t left_rpm_u  = (left_pulses  * 60000UL) / divisor;
        uint32_t right_rpm_u = (right_pulses * 60000UL) / divisor;

        // 饱和到 int16 范围，避免有符号溢出为负值
        if (left_rpm_u  > 32767) left_rpm_u  = 32767;
        if (right_rpm_u > 32767) right_rpm_u = 32767;

        // 线速度 v_mm_s = π × wheel_dia_mm × RPM / 60
        float wheel_circ_mm = (float)M_PI * (float)wheel_dia_mm;
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
