/**
 * main.cpp - 智能蓝牙摄像头小车 固件主入口
 *
 * 职责：
 *   - 初始化串口、帧队列、电机/测速/摄像头/BLE 各子系统
 *   - 创建 4 个 FreeRTOS 任务并绑定到指定核心
 *   - loop() 仅做 BLE 断连检测并紧急停车，不阻塞任何任务
 *
 * 设计依据: .trae/specs/smart-bt-camera-car/spec.md
 */

#include <Arduino.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "config.h"
#include "camera_task.h"
#include "speed_sensor.h"
#include "motor_task.h"
#include "ble_task.h"

/* 全局：图像帧队列，元素为 CameraFrame* 指针，容量 2 避免内存占用过大 */
static QueueHandle_t g_frame_queue = nullptr;

/* 全局：上次 BLE 连接状态，用于检测断连沿触发紧急停车
 * 仅 loop() 单线程读写，无需 volatile */
static bool g_ble_connected_prev = false;

/* BLE 控制回调：把 ControlPayload 转成 motor_set_target 调用 */
static void on_control(const ControlPayload* ctrl, void* user) {
    (void)user;
    motor_set_target(ctrl->direction, ctrl->turn, ctrl->speed_pct);
}

void setup() {
    Serial.begin(115200);
    delay(200);

    // ---- 启动 banner ----
    Serial.println();
    Serial.println("========================================");
    Serial.println("  智能蓝牙摄像头小车 (ESP32-S3)");
    Serial.println("  项目: smart-bt-camera-car  v0.1.0");
    Serial.println("========================================");

    // ---- 1. 创建图像帧队列（容量 2）----
    g_frame_queue = xQueueCreate(2, sizeof(CameraFrame*));
    if (g_frame_queue == nullptr) {
        Serial.println("[main][FATAL] xQueueCreate(frame) 失败，重启中...");
        esp_restart();
    }

    // ---- 2. 初始化电机（失败仅告警，不阻塞）----
    if (!motor_init()) {
        Serial.println("[main][WARN] motor_init 失败，电机可后续重启恢复");
    }

    // ---- 3. 初始化测速（中断注册）----
    speed_sensor_init();

    // ---- 4. 初始化摄像头（失败仅告警，不阻塞 BLE）----
    if (!camera_init()) {
        Serial.println("[main][ERROR] camera_init 失败，BLE 仍可工作");
    }

    // ---- 5. 初始化 BLE 并注册控制回调 ----
    ble_init();
    ble_on_control(on_control, nullptr);

    // ---- 6. 创建 4 个 FreeRTOS 任务，绑定到指定核心 ----
    BaseType_t ok;

    ok = xTaskCreatePinnedToCore(
        camera_task, "camera_task", TASK_STACK_CAMERA,
        g_frame_queue, 2, nullptr, TASK_CORE_CAMERA);
    Serial.printf("[main] camera_task 创建: %s (core=%d, stack=%d)\n",
                  ok == pdPASS ? "OK" : "FAIL",
                  TASK_CORE_CAMERA, TASK_STACK_CAMERA);

    ok = xTaskCreatePinnedToCore(
        speed_task, "speed_task", TASK_STACK_SPEED,
        nullptr, 3, nullptr, TASK_CORE_SPEED);
    Serial.printf("[main] speed_task 创建: %s (core=%d, stack=%d)\n",
                  ok == pdPASS ? "OK" : "FAIL",
                  TASK_CORE_SPEED, TASK_STACK_SPEED);

    ok = xTaskCreatePinnedToCore(
        motor_task, "motor_task", TASK_STACK_MOTOR,
        nullptr, 3, nullptr, TASK_CORE_MOTOR);
    Serial.printf("[main] motor_task 创建: %s (core=%d, stack=%d)\n",
                  ok == pdPASS ? "OK" : "FAIL",
                  TASK_CORE_MOTOR, TASK_STACK_MOTOR);

    ok = xTaskCreatePinnedToCore(
        ble_task, "ble_task", TASK_STACK_BLE,
        g_frame_queue, 2, nullptr, TASK_CORE_BLE);
    Serial.printf("[main] ble_task 创建: %s (core=%d, stack=%d)\n",
                  ok == pdPASS ? "OK" : "FAIL",
                  TASK_CORE_BLE, TASK_STACK_BLE);

    // ---- 7. 初始状态：未连接 ----
    g_ble_connected_prev = ble_is_connected();

    Serial.printf("[main] 启动完成，剩余堆内存: %u bytes\n",
                  (unsigned)ESP.getFreeHeap());
}

void loop() {
    // 极轻量：每 100ms 检查 BLE 连接状态，断连时紧急停车
    bool connected = ble_is_connected();
    if (g_ble_connected_prev && !connected) {
        motor_stop();
        Serial.println("[main] BLE 断开，已紧急停车");
    }
    g_ble_connected_prev = connected;
    vTaskDelay(pdMS_TO_TICKS(100));
}
