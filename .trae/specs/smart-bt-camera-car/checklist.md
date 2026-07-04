# Checklist

## 固件
- [x] `platformio.ini` 配置 esp32-s3-devkitc-1 + arduino 框架 + PSRAM
- [x] `partitions.csv` 含 ≥3MB app 区
- [x] `config.h` 引脚映射避开摄像头引脚（GPIO 4-18）与 USB/Flash
- [x] 摄像头初始化使用 `CAMERA_MODEL_ESP32S3_EYE`，QVGA + jpeg_quality=5 + PSRAM 缓冲
- [x] IR 中断累加脉冲计数正确（volatile + 互斥锁）
- [x] RPM/线速度/角速度公式与 spec 一致
- [x] 正弦加速公式：`v(t) = V_max × sin(π/2 × min(t/T_ramp, 1))`
- [x] PID 平衡每 10ms 调整一次，correction 应用方向正确
- [x] 四个 FreeRTOS 任务互不阻塞（绑定到不同核心或时间片）
- [x] BLE GATT 三特征 + 二进制协议带同步头 0xAA55 与 CRC8
- [x] BLE 协商 MTU 512
- [x] 图像帧分片 NOTIFY 携带 frame_id/chunk_idx/total_chunks
- [x] GitHub Actions 产出 `firmware-merged.bin`，可烧录到 0x0

## App
- [x] flutter_rust_bridge 集成 latest，codegen 通过
- [x] Rust 侧函数为纯函数（无副作用、可测试）
- [x] Rust 侧适量中文注释
- [x] BLE 扫描连接按名称 `ESP32S3_SmartCar`
- [x] JPEG 分片重组后能渲染为完整画面
- [x] 手机加速度计 → 速度/转向映射，可切换摇杆模式
- [x] 桌面 WASD/方向键控制可用
- [x] Material Design 3 主题，视觉选择非模板化默认
- [x] 适配 Android + Linux + Windows + macOS
- [x] `cargo doc` 无警告生成
- [x] GitHub Actions 上传 APK 与桌面二进制 artifact

## 工程化
- [x] `.gitignore` 覆盖 Rust/Flutter/PlatformIO/IDE
- [x] `README.md` 含硬件接线、构建烧录、App 运行、协议说明
- [x] `CHANGELOG.md` 含 v0.1.0 初始条目
