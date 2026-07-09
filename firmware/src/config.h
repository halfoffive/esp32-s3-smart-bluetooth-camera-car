/**
 * config.h - 智能蓝牙摄像头小车 全局配置
 *
 * 集中定义所有可调参数：引脚映射、物理参数、控制参数、
 * 摄像头参数、BLE 参数、协议常量、FreeRTOS 任务核心绑定。
 *
 * 硬件: Freenove ESP32-S3 WROOM (FNK0085) + OV2640 + L298N + 双红外测速
 * 设计依据: .trae/specs/smart-bt-camera-car/spec.md
 */
#pragma once
#ifndef CONFIG_H
#define CONFIG_H

/* ============================================================
 * 引脚映射
 * 已避开摄像头占用 GPIO 4-18、USB 19/20、Flash 26-32
 * ============================================================ */

/* L298N 双 H 桥电机驱动 */
#define MOTOR_L_ENA_GPIO    1   // 左轮 PWM 使能
#define MOTOR_L_IN1_GPIO    41  // 左轮方向 IN1
#define MOTOR_L_IN2_GPIO    42  // 左轮方向 IN2
#define MOTOR_R_IN3_GPIO    45  // 右轮方向 IN3
#define MOTOR_R_IN4_GPIO    46  // 右轮方向 IN4
#define MOTOR_R_ENB_GPIO    2   // 右轮 PWM 使能

/* 红外对射测速模块（中断输入） */
#define SPEED_IR_LEFT_GPIO  14  // 左轮测速
#define SPEED_IR_RIGHT_GPIO 47  // 右轮测速

/* ============================================================
 * 物理参数
 * ============================================================ */
#define WHEEL_DIAMETER_MM   65    // 轮径 (mm)
#define WHEEL_TRACK_MM      130   // 轮距 (mm)
#define ENCODER_SLOTS       20    // 编码器槽数（每圈脉冲数）

#define PWM_RESOLUTION_BITS 10    // PWM 分辨率位数 (10 -> 0-1023)
#define PWM_FREQ_HZ         20000 // PWM 频率 20kHz（高于可闻上限）

/* ============================================================
 * 控制参数
 * ============================================================ */
#define CONTROL_PERIOD_MS   10      // 控制周期 10ms = 100Hz
#define T_RAMP_MS           1500    // 正弦加速总时长 1.5s
#define V_MAX_PWM           1023    // 最大目标速度对应的 PWM 占空比

#define PID_KP              0.8f
#define PID_KI              0.05f
#define PID_KD              0.1f
#define PID_INTEGRAL_MAX    300.0f  // 积分限幅

/* ============================================================
 * 摄像头参数 (OV2640)
 * 注：CAMERA_FRAME_SIZE 实际为 esp_camera 的 framesize_t 枚举值，
 *     使用前需包含 esp_camera.h
 * ============================================================ */
#define CAMERA_FRAME_SIZE     FRAMESIZE_QVGA  // 320x240
#define CAMERA_JPEG_QUALITY   5               // 数值越小质量越高
#define CAMERA_XCLK_FREQ_HZ   10000000        // 10MHz

/* ============================================================
 * BLE 参数
 * ============================================================ */
#define BLE_DEVICE_NAME         "ESP32S3_SmartCar"
#define BLE_SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define BLE_CHAR_IMAGE_UUID     "12345678-1234-5678-1234-56789abcdef1"
#define BLE_CHAR_CONTROL_UUID   "12345678-1234-5678-1234-56789abcdef2"
#define BLE_CHAR_TELEMETRY_UUID "12345678-1234-5678-1234-56789abcdef3"
#define BLE_MTU_SIZE            512   // 协商 MTU
#define BLE_IMAGE_CHUNK_PAYLOAD 480   // 每包载荷字节数（留余量给包头）

/* ============================================================
 * 协议常量（二进制帧：同步头 + 长度 + 命令 + 载荷 + CRC8）
 * ============================================================ */
#define PROTO_SYNC0           0xAA
#define PROTO_SYNC1           0x55

/* 命令类型 */
#define CMD_IMAGE_CHUNK       0x01
#define CMD_CONTROL           0x02
#define CMD_TELEMETRY         0x03

/* ============================================================
 * FreeRTOS 任务核心绑定与栈大小
 * ESP32-S3 双核：Core0=PRO, Core1=APP
 * ============================================================ */
#define TASK_CORE_CAMERA      1
#define TASK_CORE_BLE         0
#define TASK_CORE_MOTOR       0
#define TASK_CORE_SPEED       1

#define TASK_STACK_CAMERA     8192
#define TASK_STACK_BLE        8192
#define TASK_STACK_MOTOR      4096
#define TASK_STACK_SPEED      4096

/* ============================================================
 * NVS 持久化（Preferences.h，Arduino-ESP32 内置）
 * - WiFi 配置：供未来 WiFi 推流 / OTA 升级使用，当前仅存储
 * - PID / 物理参数：供 App 下发覆盖 config.h 编译期默认值
 * ============================================================ */
#define WIFI_NVS_NAMESPACE   "wifi_cfg"
#define WIFI_NVS_KEY_SSID    "ssid"
#define WIFI_NVS_KEY_PASS    "pass"

#define PARAMS_NVS_NAMESPACE "params"
#define PARAMS_NVS_KEY_KP            "kp"
#define PARAMS_NVS_KEY_KI            "ki"
#define PARAMS_NVS_KEY_KD            "kd"
#define PARAMS_NVS_KEY_RAMP_MS        "ramp_ms"
#define PARAMS_NVS_KEY_WHEEL_DIA      "wheel_dia"
#define PARAMS_NVS_KEY_WHEEL_BASE     "wheel_base"
#define PARAMS_NVS_KEY_ENC_SLOTS      "enc_slots"

/* WiFi 配置长度上限（与 App/Rust encode_set_wifi 校验一致） */
#define WIFI_SSID_MAX_LEN   32
#define WIFI_PASS_MAX_LEN   64

#endif // CONFIG_H
