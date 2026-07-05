# Firmware — 智能蓝牙摄像头小车固件 (ESP32-S3)

ESP32-S3 WROOM（FNK0085）固件工程，基于 PlatformIO + Arduino + FreeRTOS 多线程实现：板载 OV2640 摄像头采集、L298N 电机正弦加速 + PID 直线平衡、双红外测速、BLE GATT 图像/控制/遥测三通道通信。

完整硬件清单、接线表、协议说明、控制原理见仓库根目录 [README](../README.md)。

## 目录结构
```
firmware/
├── src/
│   ├── main.cpp              # 入口：初始化各模块 + xTaskCreatePinnedToCore 创建四个任务
│   ├── config.h              # 全局配置（引脚、物理参数、PID、BLE UUID、任务核心绑定）
│   ├── camera_task.{h,cpp}   # 摄像头任务：OV2640 QVGA@quality5 抓帧入队列
│   ├── speed_sensor.{h,cpp}  # 测速任务：IR 中断 → RPM/线速度/角速度（10ms 窗口）
│   ├── motor_task.{h,cpp}    # 电机任务：正弦加速 + 左右轮 PID 平衡（10ms 周期）
│   ├── ble_task.{h,cpp}      # BLE 任务：GATT 服务 + 图像分片 NOTIFY + 控制解析 + 遥测 NOTIFY
│   ├── protocol.h            # 二进制帧格式定义（同步头 / CMD / 载荷布局）
│   └── crc8.h                # CRC8 校验（多项式 0x07，初始 0x00）
├── partitions.csv            # 自定义分区表（app0 3.75MB + nvs / otadata / fr / coredump）
└── platformio.ini            # PlatformIO 工程配置（board=esp32-s3-devkitc-1，PSRAM 启用）
```

## 配置参数

所有可调参数集中在 [`src/config.h`](src/config.h)：
- 引脚映射（L298N ENA/IN1-4/ENB、左右 IR）
- 物理参数（轮径 65mm、轮距 130mm、编码器槽数 20）
- 控制参数（控制周期 10ms、T_ramp 1.5s、PID Kp/Ki/Kd）
- 摄像头参数（QVGA、JPEG quality 5、xclk 10MHz）
- BLE 参数（设备名、服务/特征 UUID、MTU 512、分片载荷 480B）
- FreeRTOS 任务核心绑定与栈大小

## 构建命令

完整的构建、合并 bin、烧录步骤见根目录 [README](../README.md#固件构建与烧录)。常用命令：

```bash
# 编译（默认 esp32s3 环境）
pio run -e esp32s3

# 合并 bootloader + partitions + boot_app0 + firmware 为单一 bin
# pioarduino 平台不支持 pio run -t mergebin，须用 esptool.py 直接合并
esptool.py --chip esp32s3 merge-bin -o firmware-merged.bin \
  0x0 .pio/build/esp32s3/bootloader.bin \
  0x8000 .pio/build/esp32s3/partitions.bin \
  0xe000 ~/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin \
  0x10000 .pio/build/esp32s3/firmware.bin

# 直接上传（仅 firmware 部分，走 PlatformIO）
pio run -e esp32s3 -t upload
```

> CI 环境使用 `esp32s3-ci`（与 `esp32s3` 配置相同，仅用于在 GitHub Actions 中区分环境）。

## 串口调试

```bash
pio device monitor -p /dev/ttyUSB0 -b 115200
```

`monitor_speed = 115200` 已在 `platformio.ini` 中配置，可直接 `pio device monitor` 启动。启动后串口会打印各任务初始化日志、BLE 连接状态、PID 调试信息等。
