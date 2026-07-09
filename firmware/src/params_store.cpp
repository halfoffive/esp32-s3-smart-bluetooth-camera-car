/**
 * params_store.cpp - PID / 物理参数 NVS 持久化实现
 *
 * 基于 Preferences.h（Arduino-ESP32 内置，封装 ESP-IDF nvs_flash）。
 * App 下发参数后保存到 NVS，固件启动时加载以覆盖 config.h 编译期默认值。
 * 主键未设置时 load_* 返回 false，调用方回退编译期默认。
 */

#include <Arduino.h>
#include <Preferences.h>

#include "config.h"
#include "params_store.h"

bool params_store_save_pid(float kp, float ki, float kd, uint32_t ramp_ms) {
    Preferences prefs;
    if (!prefs.begin(PARAMS_NVS_NAMESPACE, false)) {
        return false;
    }
    // put* 返回写入字节数（size_t），>0 表示成功
    bool ok = prefs.putFloat(PARAMS_NVS_KEY_KP, kp) > 0
           && prefs.putFloat(PARAMS_NVS_KEY_KI, ki) > 0
           && prefs.putFloat(PARAMS_NVS_KEY_KD, kd) > 0
           && prefs.putUInt(PARAMS_NVS_KEY_RAMP_MS, ramp_ms) > 0;
    prefs.end();
    return ok;
}

bool params_store_load_pid(float* kp_out, float* ki_out, float* kd_out, uint32_t* ramp_ms_out) {
    if (kp_out == nullptr || ki_out == nullptr
        || kd_out == nullptr || ramp_ms_out == nullptr) {
        return false;
    }

    Preferences prefs;
    if (!prefs.begin(PARAMS_NVS_NAMESPACE, true)) {
        return false;
    }
    // 主键未设置视为"从未配置"，调用方回退 config.h 默认值
    if (!prefs.isKey(PARAMS_NVS_KEY_KP)) {
        prefs.end();
        return false;
    }
    // 已配置则读出，单键缺失时用编译期默认兜底
    *kp_out = prefs.getFloat(PARAMS_NVS_KEY_KP, PID_KP);
    *ki_out = prefs.getFloat(PARAMS_NVS_KEY_KI, PID_KI);
    *kd_out = prefs.getFloat(PARAMS_NVS_KEY_KD, PID_KD);
    *ramp_ms_out = prefs.getUInt(PARAMS_NVS_KEY_RAMP_MS, T_RAMP_MS);
    prefs.end();
    return true;
}

bool params_store_save_physical(uint16_t wheel_dia_mm, uint16_t wheel_base_mm, uint8_t enc_slots) {
    Preferences prefs;
    if (!prefs.begin(PARAMS_NVS_NAMESPACE, false)) {
        return false;
    }
    bool ok = prefs.putUShort(PARAMS_NVS_KEY_WHEEL_DIA, wheel_dia_mm) > 0
           && prefs.putUShort(PARAMS_NVS_KEY_WHEEL_BASE, wheel_base_mm) > 0
           && prefs.putUChar(PARAMS_NVS_KEY_ENC_SLOTS, enc_slots) > 0;
    prefs.end();
    return ok;
}

bool params_store_load_physical(uint16_t* wheel_dia_out, uint16_t* wheel_base_out, uint8_t* enc_slots_out) {
    if (wheel_dia_out == nullptr || wheel_base_out == nullptr || enc_slots_out == nullptr) {
        return false;
    }

    Preferences prefs;
    if (!prefs.begin(PARAMS_NVS_NAMESPACE, true)) {
        return false;
    }
    if (!prefs.isKey(PARAMS_NVS_KEY_WHEEL_DIA)) {
        prefs.end();
        return false;
    }
    *wheel_dia_out = prefs.getUShort(PARAMS_NVS_KEY_WHEEL_DIA, WHEEL_DIAMETER_MM);
    *wheel_base_out = prefs.getUShort(PARAMS_NVS_KEY_WHEEL_BASE, WHEEL_TRACK_MM);
    *enc_slots_out = prefs.getUChar(PARAMS_NVS_KEY_ENC_SLOTS, ENCODER_SLOTS);
    prefs.end();
    return true;
}
