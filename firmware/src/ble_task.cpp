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
        // 重新开始广播，等待客户端重连
        server->getAdvertising()->start();
    }
};

/* ============================================================
 * 控制特征回调：onWrite
 * ============================================================ */
class ControlCharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) override {
        // Arduino-ESP32 core 3.x 的 NimBLE 栈：getValue() 返回 Arduino String，
        // 需要 .c_str() 才能隐式构造 std::string。
        std::string value = pChar->getValue().c_str();
        if (value.empty()) return;

        const uint8_t* buf = reinterpret_cast<const uint8_t*>(value.data());
        size_t len = value.size();

        // 1) CRC 校验
        if (!proto_validate(buf, len)) {
            // 校验失败，丢弃（可在此处增加失败计数器）
            return;
        }
        // 2) 解析控制载荷
        ControlPayload ctrl;
        if (!proto_parse_control(buf, len, &ctrl)) {
            return;
        }
        // 3) 调用注册的回调（电机任务消费）
        if (g_control_cb != nullptr) {
            g_control_cb(&ctrl, g_control_user);
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
            send_image_frame(frame);
            // 释放 camera_task malloc 的内存
            free(frame->data);
            free(frame);
        }
    }
}
