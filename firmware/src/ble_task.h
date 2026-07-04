/**
 * ble_task.h - BLE 通信任务接口
 *
 * 职责：
 *   - 暴露 GATT 服务（图像 NOTIFY / 控制 WRITE / 遥测 NOTIFY）
 *   - 接收 App 控制指令，回调通知电机任务
 *   - 从图像帧队列消费 JPEG 帧并分片 NOTIFY
 *   - 周期性 NOTIFY 遥测数据
 *
 * 依赖：ESP32 BLE Arduino 库 + FreeRTOS
 */
#pragma once
#ifndef BLE_TASK_H
#define BLE_TASK_H

#include <stdint.h>
#include <stdbool.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 控制指令回调（电机任务注册）
 * @param ctrl 控制载荷指针（回调内有效，回调返回后失效）
 * @param user 注册时传入的用户上下文
 */
typedef void (*ControlCallback)(const ControlPayload* ctrl, void* user);

/**
 * 初始化 BLE（在 setup 中调用一次）
 * - 创建 BLE 设备、Server、Service、3 个 Characteristic
 * - 注册 Server/Control 回调
 * - 启动 Service 与 Advertising
 * - 创建遥测互斥量
 * @return true=成功
 */
bool ble_init();

/**
 * 注册控制指令回调（电机任务用）
 * @param cb   回调函数指针（NULL 取消注册）
 * @param user 用户上下文
 */
void ble_on_control(ControlCallback cb, void* user);

/**
 * 设置遥测数据源（电机/测速任务更新，BLE 任务周期 NOTIFY）
 * 内部持锁拷贝，线程安全
 * @param telemetry 遥测数据指针
 */
void ble_set_telemetry(const TelemetryPayload* telemetry);

/**
 * BLE FreeRTOS 任务
 * @param arg 图像帧队列 QueueHandle_t，元素类型为 CameraFrame*
 */
void ble_task(void* arg);

/**
 * 当前是否已连接
 * @return true=已连接
 */
bool ble_is_connected();

#ifdef __cplusplus
}
#endif

#endif // BLE_TASK_H
