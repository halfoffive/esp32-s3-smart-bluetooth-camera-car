//! JPEG 分片重组器
//!
//! 接收按 `chunk_idx` 乱序到达的图像分片（同一 `frame_id`），到齐后拼接为完整 JPEG 字节流。
//! `frame_id` 变化视为新帧开始，丢弃旧帧状态并重置。

use crate::ble::ImageChunk;

/// JPEG 分片重组状态机
///
/// 容忍乱序但要求 `frame_id` 一致；`frame_id` 变化时丢弃旧帧状态并重置。
#[frb(opaque)]
pub struct ImageAssembler {
    /// 当前正在拼接的帧 ID；None 表示尚未收到任何分片
    pub current_frame_id: Option<u16>,
    /// 当前帧总分片数（取自首个到达的分片）
    pub total_chunks: u16,
    /// 按 chunk_idx 下标保存的分片数据；None 表示该下标尚未到达
    pub received: Vec<Option<Vec<u8>>>,
    /// 已收到的分片计数（用于快速判断是否到齐）
    pub next_idx: u16,
}

impl ImageAssembler {
    pub fn new() -> Self {
        Self {
            current_frame_id: None,
            total_chunks: 0,
            received: Vec::new(),
            next_idx: 0,
        }
    }

    /// 推入一个分片；若该帧所有分片到齐则返回拼接后的 JPEG 字节并重置状态。
    ///
    /// - 帧切换（frame_id 变化）：丢弃旧帧，以新帧的 total_chunks 重置缓冲
    /// - 越界 chunk_idx（>= total_chunks）：忽略
    /// - 重复 chunk_idx：覆盖（不重复计数）
    pub fn push(&mut self, chunk: ImageChunk) -> Option<Vec<u8>> {
        // 帧切换检测：frame_id 变化时重置
        if self.current_frame_id != Some(chunk.frame_id) {
            self.current_frame_id = Some(chunk.frame_id);
            self.total_chunks = chunk.total_chunks;
            self.received.clear();
            self.received.resize_with(chunk.total_chunks as usize, || None);
            self.next_idx = 0;
        }

        // 越界保护：chunk_idx 超出 total_chunks 范围时忽略
        let idx = chunk.chunk_idx as usize;
        if idx >= self.received.len() {
            return None;
        }

        if self.received[idx].is_none() {
            // 首次到达：计入计数
            self.received[idx] = Some(chunk.jpeg_bytes);
            self.next_idx += 1;
        } else {
            // 重复分片：覆盖数据但不重复计数
            self.received[idx] = Some(chunk.jpeg_bytes);
        }

        // 全部分片到齐：按 chunk_idx 顺序拼接并重置
        if !self.received.is_empty() && self.next_idx as usize == self.received.len() {
            let mut out = Vec::new();
            for slot in self.received.drain(..) {
                if let Some(b) = slot {
                    out.extend_from_slice(&b);
                }
            }
            self.current_frame_id = None;
            self.total_chunks = 0;
            self.received.clear();
            self.next_idx = 0;
            return Some(out);
        }
        None
    }
}

impl Default for ImageAssembler {
    fn default() -> Self {
        Self::new()
    }
}
