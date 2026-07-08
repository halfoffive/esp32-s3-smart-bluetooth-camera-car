/**
 * motor_task.cpp - 电机控制任务实现
 *
 * L298N 驱动 + 正弦加速 + PID 直线平衡 + 遥测上报
 *
 * 硬件映射（见 config.h）：
 *   左轮 ENA=GPIO1(PWM)  IN1=GPIO41 IN2=GPIO42
 *   右轮 ENB=GPIO2(PWM)  IN3=GPIO45 IN4=GPIO46
 *
 * LEDC 分配：左轮 ENA=GPIO1，右轮 ENB=GPIO2
 * 注：本实现使用 Arduino-ESP32 core >= 3.0 的 LEDC API（ledcAttach +
 *     ledcWrite(pin, duty)），不再使用 ledcSetup/ledcAttachPin/LEDC_CHANNEL_*。
 */

#include <Arduino.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp32-hal-ledc.h"
#include <math.h>

#include "config.h"
#include "motor_task.h"
#include "speed_sensor.h"   // SpeedData / speed_sensor_get()
#include "ble_task.h"       // ble_set_telemetry()

/* V_MAX_PWM 对应线速度（spec：100% PWM ≈ 0.5 m/s = 500 mm/s） */
#define V_MAX_SPEED_MM_S  500

/* ============================================================
 * 目标速度状态（BLE 回调写 / 电机任务读，volatile 保护）
 * int8_t/uint8_t/对齐 uint32_t 在 ESP32 上单字节/单字读写原子，
 * 10ms 控制周期容忍单次读取跨字段不一致。
 * ============================================================ */
static volatile int8_t   g_direction = 0;        // -1 后退 / 0 停 / 1 前
static volatile int8_t   g_turn = 0;             // -1 左 / 0 直 / 1 右
static volatile uint8_t  g_speed_pct = 0;        // 0-100
static volatile uint32_t g_cmd_timestamp_ms = 0; // 指令到达时间，用于正弦加速 t 计算

/* ============================================================
 * 方向引脚辅助函数
 * forward : IN1=1,IN2=0（或 IN3=1,IN4=0）
 * backward: IN1=0,IN2=1（或 IN3=0,IN4=1）
 * stop    : IN1=0,IN2=0（或 IN3=0,IN4=0）
 * ============================================================ */
static void set_left_dir(bool forward) {
    digitalWrite(MOTOR_L_IN1_GPIO, forward ? HIGH : LOW);
    digitalWrite(MOTOR_L_IN2_GPIO, forward ? LOW  : HIGH);
}

static void set_right_dir(bool forward) {
    digitalWrite(MOTOR_R_IN3_GPIO, forward ? HIGH : LOW);
    digitalWrite(MOTOR_R_IN4_GPIO, forward ? LOW  : HIGH);
}

static void stop_left_dir() {
    digitalWrite(MOTOR_L_IN1_GPIO, LOW);
    digitalWrite(MOTOR_L_IN2_GPIO, LOW);
}

static void stop_right_dir() {
    digitalWrite(MOTOR_R_IN3_GPIO, LOW);
    digitalWrite(MOTOR_R_IN4_GPIO, LOW);
}

/* ============================================================
 * 饱和到 [0, V_MAX_PWM]
 * ============================================================ */
static inline uint16_t clamp_pwm(float v) {
    if (v < 0.0f) return 0;
    if (v > (float)V_MAX_PWM) return V_MAX_PWM;
    return (uint16_t)v;
}

/* ============================================================
 * 公开接口
 * ============================================================ */

bool motor_init() {
    /* 4 个方向引脚 */
    pinMode(MOTOR_L_IN1_GPIO, OUTPUT);
    pinMode(MOTOR_L_IN2_GPIO, OUTPUT);
    pinMode(MOTOR_R_IN3_GPIO, OUTPUT);
    pinMode(MOTOR_R_IN4_GPIO, OUTPUT);

    /* 初始 LOW */
    digitalWrite(MOTOR_L_IN1_GPIO, LOW);
    digitalWrite(MOTOR_L_IN2_GPIO, LOW);
    digitalWrite(MOTOR_R_IN3_GPIO, LOW);
    digitalWrite(MOTOR_R_IN4_GPIO, LOW);

    /* LEDC：按 GPIO 绑定 PWM */
    ledcAttach(MOTOR_L_ENA_GPIO, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);
    ledcAttach(MOTOR_R_ENB_GPIO, PWM_FREQ_HZ, PWM_RESOLUTION_BITS);

    /* 占空比 0 */
    ledcWrite(MOTOR_L_ENA_GPIO, 0);
    ledcWrite(MOTOR_R_ENB_GPIO, 0);

    return true;
}

void motor_set_target(int8_t direction, int8_t turn, uint8_t speed_pct) {
    // 入口饱和截断，防止越界值导致 PWM 计算异常
    if (direction < -1) direction = -1;
    if (direction > 1) direction = 1;
    if (turn < -1) turn = -1;
    if (turn > 1) turn = 1;
    if (speed_pct > 100) speed_pct = 100;

    g_direction = direction;
    g_turn = turn;
    g_speed_pct = speed_pct;
    g_cmd_timestamp_ms = millis();
}

void motor_stop() {
    /* 更新目标状态（也会让任务循环写 0） */
    motor_set_target(0, 0, 0);
    /* 立即把 PWM 与方向引脚清零，确保断连即时保护 */
    ledcWrite(MOTOR_L_ENA_GPIO, 0);
    ledcWrite(MOTOR_R_ENB_GPIO, 0);
    stop_left_dir();
    stop_right_dir();
}

/* ============================================================
 * 电机控制任务（10ms 周期）
 * ============================================================ */
void motor_task(void* arg) {
    (void)arg;

    float integral = 0.0f;
    float last_error = 0.0f;

    TickType_t last_wake = xTaskGetTickCount();
    const TickType_t period = pdMS_TO_TICKS(CONTROL_PERIOD_MS);

    for (;;) {
        vTaskDelayUntil(&last_wake, period);

        /* 1. 取目标速度快照（volatile 读） */
        int8_t   dir     = g_direction;
        int8_t   turn    = g_turn;
        uint8_t  sp_pct  = g_speed_pct;
        uint32_t cmd_ts  = g_cmd_timestamp_ms;

        /* 2. 正弦加速：ratio = sin(π/2 * min(t/T, 1))，半周期正弦 0→1 */
        uint32_t t_ms = millis() - cmd_ts;
        float ratio;
        if (t_ms >= T_RAMP_MS) {
            ratio = 1.0f;
        } else {
            ratio = sinf((M_PI / 2.0f) * (float)t_ms / (float)T_RAMP_MS);
        }

        /* 3. 目标 PWM（direction==0 时直接 0） */
        uint16_t target_pwm = 0;
        if (dir != 0) {
            target_pwm = (uint16_t)((float)sp_pct / 100.0f * (float)V_MAX_PWM * ratio);
        }

        /* 4. 转向叠加：turn_bias = turn * 0.2 * target_pwm
         *    左目标 = target - bias，右目标 = target + bias */
        float turn_bias = (float)turn * 0.2f * (float)target_pwm;
        float left_target_f  = (float)target_pwm - turn_bias;
        float right_target_f = (float)target_pwm + turn_bias;

        uint16_t left_pwm  = clamp_pwm(left_target_f);
        uint16_t right_pwm = clamp_pwm(right_target_f);

        /* 5. PID 直线平衡（仅 direction!=0 且 turn==0 时启用） */
        SpeedData spd = speed_sensor_get();

        if (dir != 0 && turn == 0 && target_pwm > 0) {
            float dt = (float)CONTROL_PERIOD_MS / 1000.0f; // 0.01s
            float error = (float)spd.left_rpm - (float)spd.right_rpm;

            integral += error * dt;
            if (integral >  PID_INTEGRAL_MAX) integral =  PID_INTEGRAL_MAX;
            if (integral < -PID_INTEGRAL_MAX) integral = -PID_INTEGRAL_MAX;

            float derivative = (error - last_error) / dt;
            float correction = PID_KP * error + PID_KI * integral + PID_KD * derivative;
            last_error = error;

            /* 左轮减 correction/2，右轮加 correction/2 */
            left_pwm  = clamp_pwm((float)left_pwm  - correction / 2.0f);
            right_pwm = clamp_pwm((float)right_pwm + correction / 2.0f);
        } else {
            /* 转向模式或停车：清零积分避免残留，保留 last_error
             * 避免从转向切回直行时 derivative 因 last_error=0 产生冲击 */
            integral = 0.0f;
        }

        /* 6. 设置方向引脚 */
        if (dir > 0) {
            set_left_dir(true);
            set_right_dir(true);
        } else if (dir < 0) {
            set_left_dir(false);
            set_right_dir(false);
        } else {
            stop_left_dir();
            stop_right_dir();
        }

        /* 7. 写 LEDC PWM */
        ledcWrite(MOTOR_L_ENA_GPIO, left_pwm);
        ledcWrite(MOTOR_R_ENB_GPIO, right_pwm);

        /* 8. 遥测上报（每周期） */
        TelemetryPayload telem;
        telem.left_rpm          = spd.left_rpm;
        telem.right_rpm         = spd.right_rpm;
        telem.left_speed_mm_s   = spd.left_speed_mm_s;
        telem.right_speed_mm_s  = spd.right_speed_mm_s;
        /* target_pwm 换算：V_MAX_PWM -> 500 mm/s */
        telem.target_speed_mm_s = (int16_t)((float)target_pwm / (float)V_MAX_PWM * (float)V_MAX_SPEED_MM_S);
        telem.battery_mv = 0;
        ble_set_telemetry(&telem);
    }
}
