# 智能蓝牙摄像头小车 Spec

## Why
基于 Freenove ESP32-S3 WROOM（FNK0085）套件搭建一辆可远程操控的智能小车：通过蓝牙低功耗（BLE）将车载摄像头画面与控制指令双向传输到 Flutter+Rust 跨端 App，实现低延时遥操与直线行驶自动平衡。

## What Changes
- 新增 ESP32-S3 固件（Arduino + PlatformIO），多线程 FreeRTOS 任务：摄像头采集、BLE 通信、电机 PID 控制、转速测量
- 固件 BLE 传输 JPEG 帧（QVGA、JPEG 质量 5）+ 控制指令 + 遥测数据
- 电机控制：正弦曲线加速 + 10ms 周期左右轮转速 PID 平衡，实现直线行驶
- 红外对射测速模块（中断）→ RPM → 线速度（轮径）→ 角速度（轮距）
- 新增 Flutter（latest）+ Rust（flutter_rust_bridge latest）跨端 App：Material Design 3，适配桌面（Windows/Linux/macOS）+ Android；桌面键盘、手机体感（加速度计）操控
- GitHub Actions：固件构建并合并出可烧录到 0x0 的 bin；App 构建 APK 与桌面二进制 + cargo doc
- 配套 `.gitignore`、`README.md`、`CHANGELOG.md`

## 关键假设（请在审阅时确认）
1. **"5.qwga清晰度"** 解读为 JPEG 质量 = 5（数值越小质量越高）、帧尺寸 QVGA（320×240）。QVGA 是 BLE 低延时传输的合理折中。
2. **移动端范围**：仅 Android。iOS 需 macOS 签名环境，暂不纳入流水线（Flutter 工程仍保留 ios 目录占位）。
3. **构建工具链**：固件用 PlatformIO（CI 友好，可一条命令合并 bin）。
4. **引脚分配**（已避开板载摄像头占用的 GPIO 4-18 与 USB 19/20、Flash 26-32）：
   - L298N：ENA=GPIO1(PWM)、IN1=GPIO41、IN2=GPIO42、IN3=GPIO45、IN4=GPIO46、ENB=GPIO2(PWM)
   - 红外测速：左=GPIO14、右=GPIO47
5. **物理参数**（写入 `config.h` 可调）：轮径 65mm、轮距 130mm、编码器槽数 20、T_ramp=1.5s、V_max=100% PWM 占空比对应线速度约 0.5m/s。

## Impact
- 受影响硬件：Freenove ESP32-S3 WROOM（FNK0085）+ 板载 OV2640（引脚固定）+ 外接 L298N 双马达驱动 + 双红外对射测速模块
- 受影响代码：
  - `firmware/`：PlatformIO 工程，多线程 FreeRTOS 任务
  - `app/`：Flutter 工程 + `rust/` 子 crate（flutter_rust_bridge）
  - `.github/workflows/`：两条构建流水线
  - 根目录 `README.md`、`CHANGELOG.md`、`.gitignore`

## ADDED Requirements

### Requirement: 固件多线程架构
系统 SHALL 在 ESP32-S3 上以 FreeRTOS 多任务方式运行，主循环不阻塞，至少包含四个独立任务：摄像头采集、BLE 通信、电机控制（10ms 周期）、转速采样。

#### Scenario: 任务并发运行
- **WHEN** 固件启动
- **THEN** 摄像头、BLE、电机控制、转速测量任务各自绑定到不同核心或时间片运行
- **AND** 任何一个任务阻塞不影响其它任务

### Requirement: 摄像头采集与配置
系统 SHALL 使用板载 OV2640（`CAMERA_MODEL_ESP32S3_EYE` 引脚映射），输出 JPEG，帧尺寸 QVGA（320×240），JPEG 质量 5，PSRAM 帧缓冲，参考 Freenove `Sketch_07.1_CameraWebServer` 配置。

#### Scenario: 帧采集
- **WHEN** 摄像头任务运行
- **THEN** 持续获取 JPEG 帧
- **AND** 帧尺寸为 320×240、质量参数为 5
- **AND** 帧缓冲位于 PSRAM（`CAMERA_FB_IN_PSRAM`）

### Requirement: BLE 通信协议
系统 SHALL 通过 BLE GATT 暴露一个 UART 风格的服务，包含三个特征：图像数据（NOTIFY）、控制输入（WRITE）、遥测数据（NOTIFY）。所有数据采用二进制帧格式（同步头 `0xAA55`、长度、命令类型、载荷、CRC8 校验）。参考 Freenove `Sketch_03.1_BLE_USART` 的服务/特征结构。

#### Scenario: 图像帧分片传输
- **WHEN** 一帧 JPEG 大于单包 MTU
- **THEN** 固件将帧拆分为多个 NOTIFY 包，每包携带 `frame_id`、`chunk_idx`、`total_chunks`、`payload`
- **AND** 连接建立后协商 MTU 至 512 字节以降低包数

#### Scenario: 控制指令接收
- **WHEN** App 写入控制特征
- **THEN** 固件解析方向/速度指令并更新目标速度
- **AND** CRC 校验失败的指令被丢弃并计数

#### Scenario: 遥测上报
- **WHEN** 控制周期完成
- **THEN** 通过遥测特征 NOTIFY 当前左右轮 RPM、线速度、目标速度

### Requirement: 转速测量
系统 SHALL 通过两个红外对射测速模块（左/右轮各一）以中断方式计数脉冲，按编码器槽数换算 RPM，结合轮径换算线速度，结合轮距换算角速度。

#### Scenario: RPM 计算
- **WHEN** 检测到脉冲边沿
- **THEN** 中断累加计数（volatile）
- **AND** 测速任务以固定窗口计算 `RPM = (脉冲数 × 60) / (窗口秒数 × 槽数)`

#### Scenario: 速度换算
- **WHEN** 已知 RPM
- **THEN** 线速度 `v = π × 轮径 × RPM / 60`
- **AND** 角速度 `ω = (v_right − v_left) / 轮距`

### Requirement: 电机控制——正弦加速 + 直线平衡
系统 SHALL 在 10ms（100Hz）控制周期内：
1. 按正弦曲线生成目标速度：`v(t) = V_max × sin(π/2 × min(t/T_ramp, 1))`，t 从指令到达起计时
2. 用 PID 平衡左右轮转速使两者一致
3. 输出左右 PWM

#### Scenario: 平滑起步
- **WHEN** 收到前进指令
- **THEN** 目标速度沿正弦曲线从 0 升至 V_max，耗时 T_ramp
- **AND** 升速期间不出现阶跃

#### Scenario: 直线行驶平衡
- **WHEN** 左右轮转速出现偏差
- **THEN** PID 计算 `correction = Kp·e + Ki·∫e + Kd·de/dt`，`e = left_rpm − right_rpm`
- **AND** 左 PWM 减 `correction/2`、右 PWM 加 `correction/2`
- **AND** 每 10ms 调整一次

### Requirement: App 跨端架构
App SHALL 使用 Flutter（latest stable）+ Rust（flutter_rust_bridge latest），Rust 侧以纯函数处理 BLE 协议解析、JPEG 分片重组、控制指令编码；Flutter 侧负责 UI（Material Design 3）、BLE 连接管理、传感器输入。开发遵循社区规范，函数式编程风格，适量中文注释。

#### Scenario: 跨端调用
- **WHEN** Flutter 收到 BLE NOTIFY 包
- **THEN** 调用 Rust 纯函数 `assemble_chunk(state, packet) -> Option<Frame>`
- **AND** 一帧完整后返回 JPEG 字节流供 Flutter 渲染

### Requirement: App BLE 连接
App SHALL 通过 `flutter_reactive_ble`（或等价库）扫描、连接名为 `ESP32S3_SmartCar` 的设备，协商 MTU 512，订阅图像与遥测特征，写入控制特征。

#### Scenario: 自动重连
- **WHEN** 连接断开
- **THEN** App 在 UI 上提示并尝试重连
- **AND** 重连不阻塞 UI 线程

### Requirement: App UI——视频与控制
App SHALL 提供主界面：上方摄像头实时画面（带 HUD 显示速度/转速），下方操控区。手机端启用加速度计体感操控（前倾前进、左右倾转向），桌面端提供键盘 WASD/方向键 + 屏幕虚拟摇杆。设计须遵循"frontend-design"指引：以小车遥操仪表盘为主题，做出有辨识度的视觉选择，而非模板化默认外观。

#### Scenario: 手机体感
- **WHEN** 用户在手机端倾斜设备
- **THEN** 加速度计读数映射为目标速度与转向角
- **AND** 用户可一键切换"体感/摇杆"模式

#### Scenario: 桌面键盘
- **WHEN** 用户按下 W/A/S/D
- **THEN** 对应方向/速度指令立即下发
- **AND** 松开按键触发平滑减速

### Requirement: 构建流水线
仓库 SHALL 提供两条 GitHub Actions 工作流：
1. `firmware.yml`：PlatformIO 编译固件，使用 `pio run -t mergebin` 合并 bootloader+partitions+firmware，产物 `firmware-merged.bin` 可直接烧录到 0x0
2. `app.yml`：Flutter 构建 Android APK + Linux/Windows/macOS 桌面包，并运行 `cargo doc` 上传文档产物

#### Scenario: 固件产物
- **WHEN** firmware.yml 触发
- **THEN** 产出 `firmware-merged.bin`
- **AND** `esptool.py write_flash 0x0 firmware-merged.bin` 可烧录成功

#### Scenario: App 产物
- **WHEN** app.yml 触发
- **THEN** 上传 APK 与各平台桌面二进制为 artifact

### Requirement: 工程文档与配置
仓库根目录 SHALL 包含 `.gitignore`（覆盖 Rust/Flutter/PlatformIO/IDE）、`README.md`（项目说明、硬件接线、构建与烧录、App 安装、协议说明）、`CHANGELOG.md`（语义化版本变更记录）。`cargo doc` 与 flutter_rust_bridge 官方文档须在写代码前查阅以确认 latest API。

#### Scenario: 文档完整
- **WHEN** 开发者克隆仓库
- **THEN** 通过 README 可独立完成硬件接线、固件烧录、App 构建运行
