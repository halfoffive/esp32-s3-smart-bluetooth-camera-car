#pragma once
#include <stdint.h>
#include <stdbool.h>

// 测速结果（线程间共享，需用互斥锁访问）
typedef struct {
    int16_t left_rpm;        // 左轮 RPM
    int16_t right_rpm;       // 右轮 RPM
    int16_t left_speed_mm_s; // 左轮线速度 mm/s
    int16_t right_speed_mm_s;// 右轮线速度 mm/s
    uint32_t last_update_ms; // 最近一次更新时间戳
} SpeedData;

// 初始化 IR 中断与硬件
bool speed_sensor_init();

// 获取当前测速数据（线程安全拷贝）
SpeedData speed_sensor_get();

// 运行时覆盖物理参数（轮径/轮距/编码器槽数）
// u16/u8 单字写 ESP32 上原子，无需 critical section
void speed_sensor_set_physical(uint16_t wheel_dia_mm, uint16_t wheel_base_mm, uint8_t enc_slots);

// 测速 FreeRTOS 任务
void speed_task(void* arg);
