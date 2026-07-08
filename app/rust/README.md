# rust_lib — Flutter Rust Bridge 子 crate

智能蓝牙摄像头小车 App 的 Rust 侧，通过 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) v2.x
与 Flutter/Dart 互操作。Rust 侧以纯函数承载：

- BLE 二进制帧协议解析（同步头 `0xAA55` + 长度 + 命令 + 载荷 + CRC8）
- JPEG 帧分片重组（`assemble_chunk`）
- 控制指令编码（方向 / 速度）

## 集成方式

- crate 名 `rust_lib`，crate-type `["staticlib", "cdylib", "rlib"]`（flutter_rust_bridge 默认约定）
- 接口写在 `src/api.rs` 下，由 `flutter_rust_bridge_codegen generate` 生成 `frb_generated.rs` 与 Dart 侧胶水代码
- codegen 跑之前本 crate 不可独立编译（缺 `frb_generated.rs`），属正常工作流
- `flutter_rust_bridge` 版本以 codegen 生成为准（当前 latest 2.x）

参考：<https://cjycode.com/flutter_rust_bridge/>
