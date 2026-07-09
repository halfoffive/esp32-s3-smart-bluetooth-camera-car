/**
 * ble_task.cpp - BLE 通信任务实现
 *
 * 实现 GATT 服务端，三个特征：
 *   - image    (NOTIFY) 上行图像分片
 *   - control  (WRITE)  下行控制指令
 *   - telemetry(NOTIFY) 上行遥测
 *
 * 任务循环消费图像帧队列并周期上报遥测。
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"

#include "config.h"
#include "protocol.h"
#include "crc8.h"
#include "ble_task.h"
#include "camera_task.h"  // CameraFrame 类型定义
#include "motor_task.h"   // motor_stop() / motor_set_pid / motor_set_ramp / motor_set_physical
#include "params_store.h" // params_store_save_pid / params_store_save_physical
#include "wifi_config.h"  // wifi_config_set

/* ============================================================
 * 全局状态
 * ============================================================ */
static BLEServer*         g_server    = nullptr;
static BLECharacteristic* g_img_char  = nullptr;
static BLECharacteristic* g_ctrl_char = nullptr;
static BLECharacteristic* g_telem_char= nullptr;
static volatile bool      g_connected = false;

static SemaphoreHandle_t  g_telem_mutex = nullptr;
static TelemetryPayload   g_telem_cache;

static ControlCallback    g_control_cb   = nullptr;
static void*              g_control_user = nullptr;

/* ============================================================
 * Server 回调：连接 / 断开
 * ============================================================ */
class SmartCarServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* server) override {
        g_connected = true;
        // 注：ESP32 BLE Arduino 在 server 端无法主动协商 MTU，
        // MTU 交换由客户端发起请求；ble_init() 中已调用
        // BLEDevice::setMTU(BLE_MTU_SIZE) 设置本端期望 MTU，
        // 客户端请求 MTU 时将按此值协商。
        (void)server;
    }
    void onDisconnect(BLEServer* server) override {
        g_connected = false;
        // 断连即时保护：直接停车，不再等 loop() 检测
        // motor_stop 线程安全（volatile 写 + ledcWrite + digitalWrite）
        motor_stop();
        // 重新开始广播，等待客户端重连
        server->getAdvertising()->start();
    }
};

/* ============================================================
 * 控制特征回调：onWrite
 * ============================================================ */
class ControlCharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) override {
        // Arduino-ESP32 core 3.x 的 NimBLE 栈：getValue() 返回 Arduino String。
        // 必须 .length() + .c_str() 二进制安全读取，避免 .c_str() 在
        // LEN_HI=0x00 等内部 0x00 字节处截断（std::string 构造同样会截断）。
        String raw = pChar->getValue();
        size_t len = raw.length();
        // 最小包 SYNC(2)+LEN(2)+CMD(1)+CRC(1)=6 字节
        if (len < 6) return;
        const uint8_t* buf = reinterpret_cast<const uint8_t*>(raw.c_str());

        // 1) CRC + 帧结构校验（sync / len / crc）
        if (!proto_validate(buf, len)) {
            // 校验失败，丢弃（BLE 控制特征无 response，不回复）
            return;
        }

        // 2) 按 CMD 分发
        //    payload 起始于 buf[5]，长度 = proto_len - 1（已减去 CMD 字节）
        uint8_t  cmd         = buf[4];
        uint16_t proto_len   = ((uint16_t)buf[2] << 8) | buf[3];
        size_t   payload_len = (size_t)proto_len - 1;
        const uint8_t* payload = &buf[5];

        switch (cmd) {
        case CMD_CONTROL: {
            // 走原有解析路径：proto_parse_control 内部会再次校验 CMD 与载荷长度
            ControlPayload ctrl;
            if (!proto_parse_control(buf, len, &ctrl)) {
                return;
            }
            if (g_control_cb != nullptr) {
                g_control_cb(&ctrl, g_control_user);
            }
            break;
        }
        case CMD_SET_PARAMS: {
            // 期望 proto_len = 1(CMD) + 21(载荷) = 22
            if (proto_len != (uint16_t)(1 + sizeof(SetParamsPayload))) {
                return;
            }
            // #pragma pack 保证结构紧凑，memcpy 后字段即与 Rust 侧小端布局一致
            SetParamsPayload p;
            memcpy(&p, payload, sizeof(p));
            // 运行时覆盖内存中参数
            motor_set_pid(p.kp, p.ki, p.kd);
            motor_set_ramp(p.ramp_ms);
            motor_set_physical(p.wheel_dia_mm, p.wheel_base_mm, p.enc_slots);
            // 持久化到 NVS，下次启动时 motor_init / speed_sensor_init 恢复
            params_store_save_pid(p.kp, p.ki, p.kd, p.ramp_ms);
            params_store_save_physical(p.wheel_dia_mm, p.wheel_base_mm, p.enc_slots);
            break;
        }
        case CMD_SET_WIFI: {
            // 载荷布局：ssid_len(u8) + ssid(ssid_len) + pass_len(u8) + pass(pass_len)
            // 至少需要两个长度字节
            if (payload_len < 2) {
                return;
            }
            uint8_t ssid_len = payload[0];
            if (ssid_len > WIFI_SSID_MAX_LEN) {
                return;
            }
            // 检查 ssid 后还能读到一个 pass_len 字节
            if (payload_len < (size_t)1 + ssid_len + 1) {
                return;
            }
            uint8_t pass_len = payload[1 + ssid_len];
            if (pass_len > WIFI_PASS_MAX_LEN) {
                return;
            }
            // 总长度必须严格匹配，防止尾部垃圾
            if (payload_len != (size_t)(1 + ssid_len + 1 + pass_len)) {
                return;
            }
            // 拷贝到本地缓冲区并强制 \0 结尾，防 overflow
            char ssid[33];
            char pass[65];
            memcpy(ssid, &payload[1], ssid_len);
            ssid[ssid_len] = '\0';
            memcpy(pass, &payload[2 + ssid_len], pass_len);
            pass[pass_len] = '\0';
            // 当前阶段仅持久化到 NVS，不发起 WiFi 连接
            wifi_config_set(ssid, pass);
            break;
        }
        default:
            // 未知 CMD：丢弃，不崩溃
            break;
        }
    }
};

/* ============================================================
 * 内部辅助：发送一帧图像（按 BLE_IMAGE_CHUNK_PAYLOAD 切片）
 * ============================================================ */
static void send_image_frame(CameraFrame* frame) {
    const size_t payload_cap = BLE_IMAGE_CHUNK_PAYLOAD;
    const size_t total_chunks = (frame->len + payload_cap - 1) / payload_cap;

    // 静态缓冲区避免栈压力；最大 12 + 480 = 492 字节，BLE_MTU_SIZE(512) 足够
    static uint8_t buf[BLE_MTU_SIZE];

    for (size_t idx = 0; idx < total_chunks; idx++) {
        if (!g_connected) break;  // 断连提前退出，避免无效发送
        size_t offset = idx * payload_cap;
        size_t chunk_len = (offset + payload_cap > frame->len)
                           ? (frame->len - offset)
                           : payload_cap;

        // LEN = CMD(1) + ImageChunkPayload 头(6) + jpeg(chunk_len)
        uint16_t proto_len = (uint16_t)(1 + 6 + chunk_len);
        buf[0] = PROTO_SYNC0;
        buf[1] = PROTO_SYNC1;
        buf[2] = (uint8_t)((proto_len >> 8) & 0xFF);
        buf[3] = (uint8_t)(proto_len & 0xFF);
        buf[4] = CMD_IMAGE_CHUNK;
        // ImageChunkPayload 头（小端）
        buf[5] = (uint8_t)(frame->frame_id & 0xFF);
        buf[6] = (uint8_t)((frame->frame_id >> 8) & 0xFF);
        buf[7] = (uint8_t)(idx & 0xFF);
        buf[8] = (uint8_t)((idx >> 8) & 0xFF);
        buf[9] = (uint8_t)(total_chunks & 0xFF);
        buf[10] = (uint8_t)((total_chunks >> 8) & 0xFF);
        // JPEG 数据
        memcpy(&buf[11], frame->data + offset, chunk_len);
        // CRC 覆盖 LEN_HI 起到 PAYLOAD 末字节 = 9 + chunk_len 字节
        size_t total_len = 11 + chunk_len + 1;
        buf[11 + chunk_len] = crc8(&buf[2], 9 + chunk_len);

        g_img_char->setValue(buf, total_len);
        g_img_char->notify();
        // 片间延时 2ms，避免淹没 BLE 栈
        vTaskDelay(pdMS_TO_TICKS(2));
    }
}

/* ============================================================
 * 内部辅助：发送遥测包
 * ============================================================ */
static void send_telemetry(void) {
    if (g_telem_mutex == nullptr) return;

    TelemetryPayload telem;
    if (xSemaphoreTake(g_telem_mutex, pdMS_TO_TICKS(10)) != pdTRUE) return;
    memcpy(&telem, &g_telem_cache, sizeof(telem));
    xSemaphoreGive(g_telem_mutex);

    // 包：SYNC(2) + LEN(2) + CMD(1) + PAYLOAD(12) + CRC(1) = 18 字节
    uint8_t buf[6 + sizeof(TelemetryPayload)];
    uint16_t proto_len = (uint16_t)(1 + sizeof(TelemetryPayload)); // CMD + payload
    buf[0] = PROTO_SYNC0;
    buf[1] = PROTO_SYNC1;
    buf[2] = (uint8_t)((proto_len >> 8) & 0xFF);
    buf[3] = (uint8_t)(proto_len & 0xFF);
    buf[4] = CMD_TELEMETRY;
    memcpy(&buf[5], &telem, sizeof(telem));
    // CRC 覆盖 LEN_HI + LEN_LO + CMD + PAYLOAD = 3 + sizeof(TelemetryPayload)
    buf[5 + sizeof(telem)] = crc8(&buf[2], 3 + sizeof(TelemetryPayload));

    g_telem_char->setValue(buf, sizeof(buf));
    g_telem_char->notify();
}

/* ============================================================
 * 公开接口实现
 * ============================================================ */
bool ble_init() {
    BLEDevice::init(BLE_DEVICE_NAME);
    // 设置期望 MTU（实际协商由客户端发起）
    BLEDevice::setMTU(BLE_MTU_SIZE);

    g_server = BLEDevice::createServer();
    g_server->setCallbacks(new SmartCarServerCallbacks());

    BLEService* pService = g_server->createService(BLE_SERVICE_UUID);

    // 图像特征（NOTIFY）。
    // NimBLE 会在创建带 PROPERTY_NOTIFY / PROPERTY_INDICATE 的特征时
    // 自动添加 CCCD（UUID 0x2902），因此无需（也不应）手动 new BLE2902()：
    // 该类在 Arduino-ESP32 core 3.x + NimBLE 下已被标记为 deprecated。
    g_img_char = pService->createCharacteristic(
        BLE_CHAR_IMAGE_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );

    // 控制特征（WRITE）—— 不需要 CCCD(2902)：
    // 2902 描述符仅用于 NOTIFY/INDICATE 特征，客户端通过它订阅通知；
    // WRITE 特征由客户端直接写入，无需订阅描述符。
    g_ctrl_char = pService->createCharacteristic(
        BLE_CHAR_CONTROL_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    g_ctrl_char->setCallbacks(new ControlCharacteristicCallbacks());

    // 遥测特征（NOTIFY）—— 同上，NimBLE 自动添加 CCCD。
    g_telem_char = pService->createCharacteristic(
        BLE_CHAR_TELEMETRY_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );

    pService->start();
    g_server->getAdvertising()->start();

    g_telem_mutex = xSemaphoreCreateMutex();
    memset(&g_telem_cache, 0, sizeof(g_telem_cache));

    return true;
}

void ble_on_control(ControlCallback cb, void* user) {
    g_control_cb = cb;
    g_control_user = user;
}

void ble_set_telemetry(const TelemetryPayload* telemetry) {
    if (telemetry == nullptr || g_telem_mutex == nullptr) return;
    if (xSemaphoreTake(g_telem_mutex, pdMS_TO_TICKS(10)) != pdTRUE) return;
    memcpy(&g_telem_cache, telemetry, sizeof(g_telem_cache));
    xSemaphoreGive(g_telem_mutex);
}

bool ble_is_connected() {
    return g_connected;
}

/* ============================================================
 * BLE FreeRTOS 任务
 * arg: 图像帧队列 QueueHandle_t，元素类型 CameraFrame*
 * ============================================================ */
void ble_task(void* arg) {
    QueueHandle_t frame_q = (QueueHandle_t)arg;
    TickType_t last_telem_notify = xTaskGetTickCount();
    const TickType_t telem_period = pdMS_TO_TICKS(50);

    for (;;) {
        if (!g_connected) {
            // 未连接时低功耗等待
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        // 周期性发送遥测（每 50ms）
        TickType_t now = xTaskGetTickCount();
        if (now - last_telem_notify >= telem_period) {
            send_telemetry();
            last_telem_notify = now;
        }

        // 从队列取一帧（阻塞最多 100ms）
        CameraFrame* frame = nullptr;
        if (xQueueReceive(frame_q, &frame, pdMS_TO_TICKS(100)) == pdTRUE && frame != nullptr) {
            // NimBLE 栈没有 getSubscribedCount()，直接发送；notify() 内部会在无订阅时跳过
            send_image_frame(frame);
            // 释放 camera_task malloc 的内存
            free(frame->data);
            free(frame);
        }
    }
}
