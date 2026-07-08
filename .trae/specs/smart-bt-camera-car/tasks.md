# Tasks

## 阶段一：固件（ESP32-S3）

- [x] Task 1: 初始化 PlatformIO 工程
  - [x] 1.1 创建 `firmware/platformio.ini`：board=esp32-s3-devkitc-1，framework=arduino，自定义分区表，PSRAM 启用
  - [x] 1.2 创建 `firmware/partitions.csv`（参考 Freenove 示例，≥3MB app 区 + 数据区）
  - [x] 1.3 创建 `firmware/src/config.h`：定义引脚映射（L298N ENA/IN1-4/ENB、左右 IR）、轮径、轮距、编码器槽数、T_ramp、PID 系数、BLE UUID
- [x] Task 2: 摄像头任务
  - [x] 2.1 复用 `CAMERA_MODEL_ESP32S3_EYE` 引脚定义（参考 Freenove `camera_pins.h`）
  - [x] 2.2 实现 `camera_task`：esp_camera_init，FRAMESIZE_QVGA，jpeg_quality=5，PSRAM 缓冲，循环抓帧入队列
- [x] Task 3: 转速测量任务
  - [x] 3.1 实现 IR 中断服务：累加左右轮脉冲计数（volatile）
  - [x] 3.2 实现 `speed_task`：10ms 窗口统计脉冲 → RPM → 线速度/角速度，写入共享结构（带互斥锁）
- [x] Task 4: 电机控制任务
  - [x] 4.1 实现 L298N 驱动：方向引脚 + LEDC PWM（ENA/ENB）
  - [x] 4.2 实现正弦加速：`v(t) = V_max × sin(π/2 × min(t/T_ramp, 1))`
  - [x] 4.3 实现 PID 平衡：`error = left_rpm − right_rpm`，`correction = Kp·e + Ki·∫e + Kd·de/dt`
  - [x] 4.4 实现 10ms 周期循环：更新目标速度 → PID → 写左右 PWM
- [x] Task 5: BLE 通信任务
  - [x] 5.1 定义 GATT 服务与三特征（图像 NOTIFY / 控制 WRITE / 遥测 NOTIFY）+ 二进制协议（同步头 0xAA55、长度、命令类型、载荷、CRC8）
  - [x] 5.2 实现 `ble_task`：BLEDevice::init、createServer、createService、start、advertising，协商 MTU 512
  - [x] 5.3 实现图像分片发送：从帧队列取 JPEG → 切包 NOTIFY（携带 frame_id/chunk_idx/total_chunks）
  - [x] 5.4 实现控制指令解析：onWrite 解析方向/速度 → 更新共享目标速度
  - [x] 5.5 实现遥测 NOTIFY：周期上报 RPM/速度/目标
- [x] Task 6: 主入口与任务调度
  - [x] 6.1 `main.cpp`：初始化各模块，`xTaskCreatePinnedToCore` 创建四个任务（摄像头 Core1、BLE Core0、电机 Core0、测速 Core1）
  - [x] 6.2 启动后串口打印调试信息
- [x] Task 7: 固件 GitHub Actions
  - [x] 7.1 创建 `.github/workflows/firmware.yml`
  - [x] 7.2 步骤：setup-python → pip install platformio esptool → `pio run -d firmware -e esp32s3-ci` → `esptool.py --chip esp32s3 merge-bin` → upload artifact `firmware-merged.bin`

## 阶段二：App（Flutter + Rust）

- [x] Task 8: 初始化 Flutter 工程 + flutter_rust_bridge
  - [x] 8.1 `flutter create app --platforms=android,linux,windows,macos`
  - [x] 8.2 在 `app/` 下集成 flutter_rust_bridge（latest），创建 `rust/` crate（先查阅官方文档与 cargo doc）
  - [x] 8.3 配置 `pubspec.yaml`（flutter_reactive_ble、sensors_plus、provider/riverpod、material 3）
  - [x] 8.4 配置 `rust/Cargo.toml`
- [x] Task 9: Rust 侧——协议与图像处理（纯函数）
  - [x] 9.1 `ble.rs`：解析图像/控制/遥测包（同步头、长度、CRC8 校验）
  - [x] 9.2 `image.rs`：`assemble_chunk(state, packet) -> Option<Vec<u8>>` 分片重组
  - [x] 9.3 `control.rs`：`encode_command(dir, speed) -> Vec<u8>` 控制指令编码
  - [x] 9.4 `telemetry.rs`：解码遥测结构体
- [x] Task 10: Flutter 侧——BLE 连接层
  - [x] 10.1 设备扫描与连接（按名称 `ESP32S3_SmartCar`）
  - [x] 10.2 协商 MTU 512，订阅图像/遥测特征
  - [x] 10.3 收到 NOTIFY → 调用 Rust 重组函数 → 流式输出 JPEG
  - [x] 10.4 断线自动重连 + UI 提示
- [x] Task 11: Flutter 侧——UI（Material 3，遵循 frontend-design 指引）
  - [x] 11.1 设计 plan：调色板、字体配对、布局概念、signature 元素（先在思考中完成，再落代码）
  - [x] 11.2 主界面骨架：上方视频 viewport（Image.memory + HUD 覆盖层）
  - [x] 11.3 下方操控区：虚拟摇杆 widget
  - [x] 11.4 遥测面板：左右 RPM、线速度、目标速度、电池
  - [x] 11.5 设置页：PID 系数、T_ramp、轮径、轮距、编码器槽数（本地持久化）
- [x] Task 12: 体感与键盘输入
  - [x] 12.1 手机端：sensors_plus 加速度计 → 目标速度/转向映射，模式切换按钮
  - [x] 12.2 桌面端：KeyboardListener（WASD/方向键）→ 控制指令
  - [x] 12.3 输入去抖 + 速率限制（避免 BLE 写入过载）
- [x] Task 13: App GitHub Actions
  - [x] 13.1 `.github/workflows/app.yml`
  - [x] 13.2 setup-flutter + setup Rust + flutter_rust_bridge codegen
  - [x] 13.3 矩阵构建：Android APK / Linux / Windows / macOS
  - [x] 13.4 `cargo doc` 步骤 → 上传 artifact

## 阶段三：仓库工程化

- [x] Task 14: 根目录文件
  - [x] 14.1 `.gitignore`（Rust target/、Flutter build/、.pio/、IDE 配置、本地密钥）
  - [x] 14.2 `README.md`：项目介绍、硬件接线图（表格）、固件构建烧录命令、App 构建运行命令、协议说明
  - [x] 14.3 `CHANGELOG.md`：初始 v0.1.0 版本
  - [x] 14.4 `app/README.md` 与 `firmware/README.md`（子说明）

# Task Dependencies
- Task 2/3/5 依赖 Task 1
- Task 4 依赖 Task 1 + Task 3
- Task 6 依赖 Task 2/3/4/5
- Task 7 依赖 Task 6
- Task 9 依赖 Task 8
- Task 10 依赖 Task 9
- Task 11 依赖 Task 10
- Task 12 依赖 Task 11
- Task 13 依赖 Task 12
- Task 14 可与阶段三并行，但 README 内容需引用 Task 7/13 产出的命令
