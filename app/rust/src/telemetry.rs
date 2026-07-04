//! 遥测结构体与解码辅助
//!
//! 遥测载荷定义在 `ble.rs`（与解析逻辑同源，避免重复定义），
//! 本模块仅重导出类型并提供可选的 UI 摘要格式化函数。

pub use crate::ble::TelemetryPayload;

/// 生成 UI 友好的遥测摘要字符串（示例格式，供 Flutter 侧直接显示）。
///
/// 例：`L:120 R:118 rpm | v:409 mm/s | bat:7420 mV`
pub fn format_summary(t: &TelemetryPayload) -> String {
    format!(
        "L:{} R:{} rpm | v:{} mm/s | bat:{} mV",
        t.left_rpm, t.right_rpm, t.target_speed_mm_s, t.battery_mv
    )
}
