# Checklist

## Node 20 弃用（Actions 升级）
- [x] `.github/workflows/app.yml` 中无 `actions/checkout@v4`（grep 验证）
- [x] `.github/workflows/app.yml` 中无 `actions/cache@v4`
- [x] `.github/workflows/app.yml` 中无 `actions/upload-artifact@v4`
- [x] `.github/workflows/app.yml` 中无 `actions/download-artifact@v4`
- [x] `.github/workflows/firmware.yml` 中无 `actions/checkout@v4`
- [x] `.github/workflows/firmware.yml` 中无 `actions/cache@v4`
- [x] `.github/workflows/firmware.yml` 中无 `actions/upload-artifact@v4`
- [x] `.github/workflows/firmware.yml` 中无 `actions/download-artifact@v4`
- [x] `actions/setup-python@v5` 与 `subosito/flutter-action@v2` 未被改动
- [x] `grep -rnE 'actions/(checkout|cache|upload-artifact|download-artifact)@v4' .github/workflows/` 无输出

## Clippy `unexpected_cfgs`（frb_expand）
- [x] `app/rust/Cargo.toml` 含 `[lints.rust]` 段
- [x] `[lints.rust]` 含 `unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }`
- [x] `api.rs` 的 `#[frb(sync)]` 不再触发 `unexpected cfg condition name: frb_expand`
- [x] `image.rs` 的 `#[frb(opaque)]` 不再触发 `unexpected cfg condition name: frb_expand`

## Clippy `manual_range_contains`（control.rs）
- [x] `control.rs` 第 17 行为 `if !(-1..=1).contains(&direction) {`
- [x] `control.rs` 第 20 行为 `if !(-1..=1).contains(&turn) {`
- [x] 边界语义不变：`direction`/`turn` 在 `[-1, 1]` 之外仍返回 `Err`

## Clippy `manual_flatten`（image.rs）
- [x] `image.rs` 拼接循环为 `for b in self.received.drain(..).flatten() { out.extend_from_slice(&b); }`
- [x] 语义不变：`None` 槽位被跳过，`Some` 字节按 chunk_idx 顺序拼接

## clippy 门槛整体
- [x] `cd app/rust && cargo clippy --all-features -- -D warnings` 退出码 0（5 个错误均已消除）

## 文档
- [x] `AGENTS.md`「工具链陷阱」含 actions/* 须用 `@v5`（Node 24）约定
- [x] `AGENTS.md`「工具链陷阱」含 `frb_expand` cfg 须在 `[lints.rust]` 声明约定
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 含 3 条：actions 升级 / frb_expand cfg / clippy 风格警告

## 提交
- [x] 至少 3 个独立 commit（ci actions 升级 / rust clippy 修复 / 文档）
- [x] 每个 commit 遵循 Conventional Commits 格式
- [x] 每个 commit 独立可编译
