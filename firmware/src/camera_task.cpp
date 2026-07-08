/**
 * camera_task.cpp - 摄像头采集任务实现
 *
 * 流程：esp_camera_fb_get() 取帧 -> malloc 拷贝 payload -> 投递到队列
 *      （队列满则丢弃最旧帧并计数）-> fb_return 归还驱动缓冲。
 *
 * 设计依据: .trae/specs/smart-bt-camera-car/spec.md
 */
#include <Arduino.h>
#include "esp_camera.h"
#include "esp_heap_caps.h"   // heap_caps_malloc / MALLOC_CAP_SPIRAM
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "config.h"
#include "camera_task.h"

/* ============================================================
 * OV2640 引脚映射（CAMERA_MODEL_ESP32S3_EYE / Freenove ESP32-S3 WROOM）
 * 引脚定义写在本文件内部，避免依赖外部 camera_pins.h
 * ============================================================ */
#define CAM_PIN_PWDN     -1
#define CAM_PIN_RESET    -1
#define CAM_PIN_XCLK     15
#define CAM_PIN_SIOD     4   // SCCB SDA
#define CAM_PIN_SIOC     5   // SCCB SCL
#define CAM_PIN_Y2       11  // D0
#define CAM_PIN_Y3       9   // D1
#define CAM_PIN_Y4       8   // D2
#define CAM_PIN_Y5       10  // D3
#define CAM_PIN_Y6       12  // D4
#define CAM_PIN_Y7       18  // D5
#define CAM_PIN_Y8       17  // D6
#define CAM_PIN_Y9       16  // D7
#define CAM_PIN_VSYNC    6
#define CAM_PIN_HREF     7
#define CAM_PIN_PCLK     13

bool camera_init() {
    camera_config_t config;
    memset(&config, 0, sizeof(config));

    // LEDC 通道与定时器（esp_camera 内部用于产生 XCLK）
    // 注意：motor_init 的 ledcAttach 已占用 LEDC_CHANNEL_0/1（左/右轮 ENA/ENB），
    // 摄像头 XCLK 必须使用 LEDC_CHANNEL_2 避免通道冲突覆盖电机 PWM。
    config.ledc_channel = LEDC_CHANNEL_2;
    config.ledc_timer   = LEDC_TIMER_2;

    // 引脚映射
    config.pin_pwdn     = CAM_PIN_PWDN;
    config.pin_reset    = CAM_PIN_RESET;
    config.pin_xclk     = CAM_PIN_XCLK;
    config.pin_sccb_sda = CAM_PIN_SIOD;
    config.pin_sccb_scl = CAM_PIN_SIOC;
    config.pin_d7       = CAM_PIN_Y9;
    config.pin_d6       = CAM_PIN_Y8;
    config.pin_d5       = CAM_PIN_Y7;
    config.pin_d4       = CAM_PIN_Y6;
    config.pin_d3       = CAM_PIN_Y5;
    config.pin_d2       = CAM_PIN_Y4;
    config.pin_d1       = CAM_PIN_Y3;
    config.pin_d0       = CAM_PIN_Y2;
    config.pin_vsync    = CAM_PIN_VSYNC;
    config.pin_href     = CAM_PIN_HREF;
    config.pin_pclk     = CAM_PIN_PCLK;

    // 采集参数
    config.xclk_freq_hz = CAMERA_XCLK_FREQ_HZ;     // 10MHz
    config.frame_size   = CAMERA_FRAME_SIZE;       // FRAMESIZE_QVGA 320x240
    config.pixel_format = PIXFORMAT_JPEG;
    config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;
    config.fb_location  = CAMERA_FB_IN_PSRAM;
    config.jpeg_quality = CAMERA_JPEG_QUALITY;     // 5
    config.fb_count     = 2;                       // 双缓冲提升吞吐

    // 初始化摄像头
    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("[camera] esp_camera_init failed: 0x%x\n", (unsigned)err);
        return false;
    }

    // 传感器参数调整：水平镜像开启、垂直翻转关闭、亮度+1、饱和度不变
    sensor_t* s = esp_camera_sensor_get();
    if (s != nullptr) {
        s->set_hmirror(s, 1);
        s->set_vflip(s, 0);
        s->set_brightness(s, 1);
        s->set_saturation(s, 0);
    } else {
        Serial.println("[camera] warning: sensor_get returned null");
    }

    return true;
}

void camera_task(void* arg) {
    // arg 为帧队列句柄，元素类型为 CameraFrame*
    QueueHandle_t frame_queue = (QueueHandle_t)arg;
    uint16_t frame_id = 0;
    uint32_t dropped_frames = 0;

    Serial.println("[camera] task started");

    for (;;) {
        camera_fb_t* fb = esp_camera_fb_get();
        if (fb == nullptr) {
            // 取帧失败，短暂退避后重试
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }

        // 分配新 CameraFrame 并拷贝 payload（fb 缓冲需归还驱动，不能直接复用）
        CameraFrame* frame = (CameraFrame*)malloc(sizeof(CameraFrame));
        if (frame == nullptr) {
            esp_camera_fb_return(fb);
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }
        // JPEG payload 优先分配到 PSRAM，释放内部 SRAM 压力
        frame->data = (uint8_t*)heap_caps_malloc(fb->len, MALLOC_CAP_SPIRAM);
        if (frame->data == nullptr) {
            free(frame);
            esp_camera_fb_return(fb);
            vTaskDelay(pdMS_TO_TICKS(10));
            continue;
        }
        memcpy(frame->data, fb->buf, fb->len);
        frame->len       = fb->len;
        frame->frame_id  = frame_id++;  // uint16_t 自增，溢出自动回绕

        // 归还驱动帧缓冲
        esp_camera_fb_return(fb);

        // 投递到队列；满则丢弃最旧帧并计数
        if (xQueueSend(frame_queue, &frame, 0) != pdTRUE) {
            CameraFrame* old = nullptr;
            if (xQueueReceive(frame_queue, &old, 0) == pdTRUE) {
                free(old->data);
                free(old);
            }
            // 二次投递仍可能失败（极端竞态），失败时释放 frame 避免内存泄漏
            if (xQueueSend(frame_queue, &frame, 0) != pdTRUE) {
                free(frame->data);
                free(frame);
            }
            dropped_frames++;
            if ((dropped_frames & 0x3F) == 0) {
                Serial.printf("[camera] queue full, dropped %u frames\n",
                              (unsigned)dropped_frames);
            }
        }

        // 让出 CPU，避免独占
        vTaskDelay(pdMS_TO_TICKS(10));
    }

    // 不会到达；保险起见自删除
    vTaskDelete(NULL);
}
