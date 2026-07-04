// car_device.dart - 设备模型与 GATT UUID 常量
//
// 与固件 `firmware/src/config.h` 中的宏定义保持一致：
//   BLE_DEVICE_NAME         "ESP32S3_SmartCar"
//   BLE_SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
//   BLE_CHAR_IMAGE_UUID     "...cdef1"  (NOTIFY 上行图像分片)
//   BLE_CHAR_CONTROL_UUID   "...cdef2"  (WRITE  下行控制指令)
//   BLE_CHAR_TELEMETRY_UUID "...cdef3"  (NOTIFY 上行遥测)
//   BLE_MTU_SIZE            512

/// 设备名与 GATT UUID 常量（与固件 config.h 一致）。
///
/// 修改任一常量时须同步更新固件 `config.h`，否则 App 无法发现/连接小车。
class CarDeviceConstants {
  CarDeviceConstants._();

  /// BLE 广播设备名，固件 `BLEDevice::init(BLE_DEVICE_NAME)` 注册
  static const String deviceName = 'ESP32S3_SmartCar';

  /// GATT 服务 UUID（UART 风格，三特征共用）
  static const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';

  /// 图像特征 UUID（NOTIFY）：固件分片上行 JPEG
  static const String imageCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef1';

  /// 控制特征 UUID（WRITE）：App 下行方向/转向/速度
  static const String controlCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef2';

  /// 遥测特征 UUID（NOTIFY）：固件上行 RPM / 线速度 / 目标速度 / 电池
  static const String telemetryCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef3';

  /// 连接后协商的 MTU，与固件 `BLE_MTU_SIZE` 一致
  static const int negotiatedMtu = 512;
}
