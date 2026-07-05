/**
 * camera_task.h - 摄像头采集任务接口
 *
 * 负责 OV2640 初始化与持续 JPEG 帧采集，并将帧以指针形式
 * 投递到 FreeRTOS 队列供下游（BLE 发送）消费。
 *
 * 设计依据: .trae/specs/smart-bt-camera-car/spec.md
 */
#pragma once
#include <stdint.h>
#include <stddef.h>
#include "esp_camera.h"

// 采集到的一帧 JPEG（堆分配，调用方负责 free payload）
// 所有权契约：
//   - data 与 CameraFrame 结构体本身均由 malloc 分配
//   - 消费者从队列取出后必须先 free(frame->data) 再 free(frame)
struct CameraFrame {
    uint8_t* data;       // JPEG 字节流
    size_t   len;        // 字节数
    uint16_t frame_id;   // 帧序号（递增）
};

// 初始化摄像头（在 setup 中调用一次）
bool camera_init();

// 摄像头 FreeRTOS 任务（参数为帧队列句柄）
void camera_task(void* arg);
