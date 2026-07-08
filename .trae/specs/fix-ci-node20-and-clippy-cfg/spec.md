# Fix CI Node 20 Deprecation & Clippy Cfg Errors Spec

## Why

GitHub Actions 已弃用 Node.js 20 运行时（2025-09-19 公告），`actions/checkout@v4` 与 `actions/cache@v4` 被强制在 Node 24 上运行并产生弃用警告；同时上一次新增的 `cargo clippy --all-features -- -D warnings` 门槛在 CI 上暴露 5 个错误（`#[frb(sync)]` / `#[frb(opaque)]` 宏内部展开的 `cfg(frb_expand)` 触发 `unexpected_cfgs`，外加 `manual_range_contains` 与 `manual_flatten` 两处风格警告），导致 clippy 门槛直接挂掉、所有平台构建失败。两者都属于 CI 阻塞，须一并修复让流水线重新绿灯。

## What Changes

### CI Actions 升级（Node 24 原生）
- `.github/workflows/app.yml` 与 `.github/workflows/firmware.yml` 中所有 `actions/checkout@v4/v5` → `@v7`
- 所有 `actions/cache@v4/v5` → `@v6`
- 所有 `actions/upload-artifact@v4/v5` → `@v7`
- 所有 `actions/download-artifact@v4/v5` → `@v8`
- `actions/setup-python@v5` → `@v6`；`subosito/flutter-action@v2` 维持 v2（最新稳定，已兼容 Node 24）

### Clippy `unexpected_cfgs` 修复（`frb_expand`）
- `app/rust/Cargo.toml` 新增 `[lints.rust]` 段，声明 `frb_expand` 为已知 cfg：
  ```toml
  [lints.rust]
  unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }
  ```
  - 这样 `#[frb(sync)]` / `#[frb(opaque)]` 宏内部展开的 `#[cfg(frb_expand)]` 不再触发 `unexpected_cfgs`
  - 同时保留 `-D warnings` 门槛：其它未知 cfg 仍会被拒
  - 比 `#[allow(unexpected_cfgs)]` 散布在每处更集中、更显式

### Clippy `manual_range_contains` 修复
- `app/rust/src/control.rs` 第 17、20 行：`if x < -1 || x > 1` → `if !(-1..=1).contains(&x)`

### Clippy `manual_flatten` 修复
- `app/rust/src/image.rs` 第 69-73 行：`for slot in self.received.drain(..) { if let Some(b) = slot { ... } }` → `for b in self.received.drain(..).flatten() { ... }`

## Impact

- Affected specs: `apply-m3-default-theme-and-ci-gates`（其新增的 clippy 门槛此前在 CI 上失败，本 spec 使其真正可用）
- Affected code:
  - `.github/workflows/app.yml`、`.github/workflows/firmware.yml`（actions 版本升级）
  - `app/rust/Cargo.toml`（新增 `[lints.rust]`）
  - `app/rust/src/control.rs`（2 处范围判断）
  - `app/rust/src/image.rs`（1 处 flatten）
- 无运行时行为变化：clippy 修复均为等价改写；actions 升级仅切换运行时
- 无破坏性变更

## ADDED Requirements

### Requirement: CI Actions 须运行在受支持的 Node 运行时
CI 工作流中引用的所有 `actions/*` 仓库名空间下的 action SHALL 使用以 Node 24 为运行时的稳定大版本（`actions/checkout@v7`、`actions/cache@v6`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`actions/setup-python@v6`），不得继续使用以 Node 20 为运行时的 `@v4`/`@v5`，避免触发 GitHub Actions 的 Node 20 弃用警告。

#### Scenario: 工作流不再触发 Node 20 弃用警告
- **WHEN** CI 工作流在 GitHub-hosted runner 上执行
- **THEN** `actions/checkout` / `actions/cache` / `actions/upload-artifact` / `actions/download-artifact` 分别以 v7 / v6 / v7 / v8 运行
- **AND** `actions/setup-python` 以 v6 运行
- **AND** 作业日志中不再出现 `Node.js 20 is deprecated` 警告

### Requirement: Rust crate 须声明 frb 内部 cfg 为已知
`app/rust` crate SHALL 在 `Cargo.toml` 的 `[lints.rust]` 段声明 `frb_expand` 为已知 cfg，使 `#[frb(sync)]` / `#[frb(opaque)]` 等属性宏内部展开的 `#[cfg(frb_expand)]` 不触发 `unexpected_cfgs`，同时保留对其它未知 cfg 的拒绝策略。

#### Scenario: clippy 门槛通过
- **WHEN** 执行 `cd app/rust && cargo clippy --all-features -- -D warnings`
- **THEN** 退出码为 0
- **AND** 不报 `unexpected cfg condition name: frb_expand`

## MODIFIED Requirements

### Requirement: clippy 零警告门槛（来自 apply-m3-default-theme-and-ci-gates）
`cargo clippy --all-features -- -D warnings` 必须通过。此前该门槛因 `frb_expand` cfg 与两处风格警告在 CI 上失败；本 spec 通过声明已知 cfg 与修复风格警告使其真正生效，门槛本身不变。

### Requirement: 控制指令边界校验
`encode_control` 的 `direction` / `turn` 边界校验 SHALL 使用 `!(-1..=1).contains(&x)` 形式，语义不变（拒绝 `[-1, 1]` 之外的值），符合 clippy `manual_range_contains` 建议。

### Requirement: JPEG 分片重组拼接
`ImageAssembler::push` 在全部分片到齐时 SHALL 用 `self.received.drain(..).flatten()` 拼接 JPEG 字节，语义不变（跳过 `None` 槽位），符合 clippy `manual_flatten` 建议。
