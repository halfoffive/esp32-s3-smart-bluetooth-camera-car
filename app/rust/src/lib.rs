mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// 智能蓝牙摄像头小车 Rust 子 crate：由 flutter_rust_bridge 生成 Dart<->Rust 胶水代码，
// Rust 侧承载 BLE 协议解析、JPEG 分片重组、控制指令编码等纯函数逻辑（Task 9 填充）。
//
// 子模块（ble/image/control/telemetry）文件平铺于 `src/`，必须在 crate 根声明 `pub mod`，
// 才能让兄弟文件中的 `use crate::ble::...` 正确解析；`api/mod.rs` 仅作 frb 入口与重导出。
// 注：采用目录式 `api/mod.rs` 而非平铺 `api.rs`，因为 `flutter_rust_bridge_codegen integrate`
// 会以模板创建 `src/api/mod.rs`，若已存在平铺 `api.rs` 则触发 E0761 重复模块错误。
// frb v2 既支持 `mod api;` 也支持 `pub mod api;`，采用后者更稳妥地让 codegen 扫到入口。
pub mod api;
pub mod ble;
pub mod control;
pub mod image;
pub mod telemetry;
