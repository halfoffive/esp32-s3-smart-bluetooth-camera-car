/**
 * wifi_config.h - WiFi 配置 NVS 持久化接口
 *
 * 职责：存储 / 读取 App 下发的 WiFi SSID 与密码到 NVS。
 *       当前阶段仅持久化，不主动发起 WiFi 连接（"以后有用"）。
 *
 * 依赖：Preferences.h（Arduino-ESP32 内置，封装 ESP-IDF nvs_flash）
 */
#pragma once
#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 保存 WiFi 配置到 NVS。
 * @param ssid  SSID 字符串（以 '\0' 结尾，长度 ≤ WIFI_SSID_MAX_LEN）
 * @param pass  密码字符串（以 '\0' 结尾，长度 ≤ WIFI_PASS_MAX_LEN）
 * @return true=成功
 *
 * 注：调用方（ble_task onWrite）应已校验长度，此处做防御性截断。
 */
bool wifi_config_set(const char* ssid, const char* pass);

/**
 * 从 NVS 读取已保存的 WiFi 配置。
 * @param ssid_out    SSID 输出缓冲区（调用方分配，容量 ≥ WIFI_SSID_MAX_LEN+1）
 * @param ssid_cap    ssid_out 容量
 * @param pass_out    密码输出缓冲区（容量 ≥ WIFI_PASS_MAX_LEN+1）
 * @param pass_cap    pass_out 容量
 * @return true=NVS 中有已存配置且成功读出；false=未配置或读取失败
 */
bool wifi_config_get(char* ssid_out, size_t ssid_cap,
                     char* pass_out, size_t pass_cap);

/**
 * 清除 NVS 中的 WiFi 配置。
 */
void wifi_config_clear(void);

#ifdef __cplusplus
}
#endif

#endif // WIFI_CONFIG_H
