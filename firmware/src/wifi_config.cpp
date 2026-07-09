/**
 * wifi_config.cpp - WiFi 配置 NVS 持久化实现
 *
 * 基于 Preferences.h（Arduino-ESP32 内置，封装 ESP-IDF nvs_flash）。
 * 当前阶段仅存储 SSID/密码到 NVS，不发起 WiFi 连接。
 */

#include <Arduino.h>
#include <Preferences.h>
#include <string.h>

#include "config.h"
#include "wifi_config.h"

bool wifi_config_set(const char* ssid, const char* pass) {
    if (ssid == nullptr || pass == nullptr) return false;

    Preferences prefs;
    if (!prefs.begin(WIFI_NVS_NAMESPACE, false)) {
        return false;
    }
    // 防御性截断：超长写入会破坏 NVS，调用方应已校验
    char ssid_buf[WIFI_SSID_MAX_LEN + 1] = {0};
    char pass_buf[WIFI_PASS_MAX_LEN + 1] = {0};
    strncpy(ssid_buf, ssid, WIFI_SSID_MAX_LEN);
    strncpy(pass_buf, pass, WIFI_PASS_MAX_LEN);

    bool ok = prefs.putString(WIFI_NVS_KEY_SSID, ssid_buf) > 0
           && prefs.putString(WIFI_NVS_KEY_PASS, pass_buf) > 0;
    prefs.end();
    return ok;
}

bool wifi_config_get(char* ssid_out, size_t ssid_cap,
                     char* pass_out, size_t pass_cap) {
    if (ssid_out == nullptr || ssid_cap == 0
        || pass_out == nullptr || pass_cap == 0) {
        return false;
    }
    ssid_out[0] = '\0';
    pass_out[0] = '\0';

    Preferences prefs;
    if (!prefs.begin(WIFI_NVS_NAMESPACE, true)) {
        return false;
    }
    // 未设置键时 getString 返回默认空串
    String ssid = prefs.getString(WIFI_NVS_KEY_SSID, "");
    String pass = prefs.getString(WIFI_NVS_KEY_PASS, "");
    prefs.end();

    if (ssid.length() == 0) {
        // 从未配置
        return false;
    }

    strncpy(ssid_out, ssid.c_str(), ssid_cap - 1);
    ssid_out[ssid_cap - 1] = '\0';
    strncpy(pass_out, pass.c_str(), pass_cap - 1);
    pass_out[pass_cap - 1] = '\0';
    return true;
}

void wifi_config_clear(void) {
    Preferences prefs;
    if (!prefs.begin(WIFI_NVS_NAMESPACE, false)) {
        return;
    }
    prefs.remove(WIFI_NVS_KEY_SSID);
    prefs.remove(WIFI_NVS_KEY_PASS);
    prefs.end();
}
