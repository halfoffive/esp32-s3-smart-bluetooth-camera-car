# Tasks

- [x] Task 1: 升级 GitHub Actions 至 Node 24 原生版本
  - [x] 1.1 `.github/workflows/app.yml`：所有 `actions/checkout@v4` → `@v5`（2 处：cargo-doc job 第 39 行、build-matrix job 第 126 行）
  - [x] 1.2 `.github/workflows/app.yml`：所有 `actions/cache@v4` → `@v5`（2 处：第 54、141 行）
  - [x] 1.3 `.github/workflows/app.yml`：所有 `actions/upload-artifact@v4` → `@v5`（5 处：第 96、274、281、288、295 行）
  - [x] 1.4 `.github/workflows/app.yml`：`actions/download-artifact@v4` → `@v5`（1 处：第 310 行）
  - [x] 1.5 `.github/workflows/firmware.yml`：`actions/checkout@v4` → `@v5`（2 处：第 40、93 行）
  - [x] 1.6 `.github/workflows/firmware.yml`：`actions/cache@v4` → `@v5`（1 处：第 57 行）
  - [x] 1.7 `.github/workflows/firmware.yml`：`actions/upload-artifact@v4` → `@v5`（1 处：第 80 行）
  - [x] 1.8 `.github/workflows/firmware.yml`：`actions/download-artifact@v4` → `@v5`（1 处：第 96 行）
  - [x] 1.9 不动 `actions/setup-python@v5`（已是 v5）与 `subosito/flutter-action@v2`（最新稳定，未受 Node 20 弃用影响）
  - 验证：`grep -nE 'actions/(checkout|cache|upload-artifact|download-artifact)@v4' .github/workflows/*.yml` 无输出

- [x] Task 2: 声明 `frb_expand` 为已知 cfg（修复 `unexpected_cfgs`）
  - [x] 2.1 `app/rust/Cargo.toml` 末尾新增：
        ```toml
        [lints.rust]
        unexpected_cfgs = { level = "deny", check-cfg = ['cfg(frb_expand)'] }
        ```
  - 验证：`#[frb(sync)]` / `#[frb(opaque)]` 不再触发 `unexpected cfg condition name: frb_expand`

- [x] Task 3: 修复 `manual_range_contains`（control.rs）
  - [x] 3.1 `app/rust/src/control.rs` 第 17 行：`if direction < -1 || direction > 1 {` → `if !(-1..=1).contains(&direction) {`
  - [x] 3.2 `app/rust/src/control.rs` 第 20 行：`if turn < -1 || turn > 1 {` → `if !(-1..=1).contains(&turn) {`
  - 验证：clippy 不再报 `manual_range_contains`

- [x] Task 4: 修复 `manual_flatten`（image.rs）
  - [x] 4.1 `app/rust/src/image.rs` 第 69-73 行：
        ```rust
        for slot in self.received.drain(..) {
            if let Some(b) = slot {
                out.extend_from_slice(&b);
            }
        }
        ```
        改为：
        ```rust
        for b in self.received.drain(..).flatten() {
            out.extend_from_slice(&b);
        }
        ```
  - 验证：clippy 不再报 `manual_flatten`

- [x] Task 5: 更新 AGENTS.md / CHANGELOG.md + 分批 git 提交（依赖 Task 1-4）
  - [x] 5.1 `AGENTS.md`「工具链陷阱」追加：
        - GitHub Actions `actions/*` 系列须使用 `@v5`（Node 24），`@v4` 已因 Node 20 弃用被强制升级并产生警告
        - frb v2 属性宏（`#[frb(sync)]` / `#[frb(opaque)]`）内部展开 `cfg(frb_expand)`，须在 `app/rust/Cargo.toml` 的 `[lints.rust]` 段声明该 cfg 为已知，否则 `-D warnings` 下 `cargo clippy` 报 `unexpected_cfgs`
  - [x] 5.2 `CHANGELOG.md` `[Unreleased]` 追加 Fixed：
        - 升级 `actions/checkout|cache|upload-artifact|download-artifact` 至 `@v5`（Node 24），修复 Node 20 弃用警告
        - 声明 `frb_expand` 为已知 cfg，修复 `cargo clippy -D warnings` 报 `unexpected_cfgs`
        - 修复 `manual_range_contains`（control.rs）与 `manual_flatten`（image.rs）clippy 警告
  - [x] 5.3 分批提交（Conventional Commits，每个独立可编译）：
        - `ci: 升级 GitHub Actions 至 v5 适配 Node 24 运行时`（Task 1 文件）
        - `fix(app/rust): 声明 frb_expand cfg 并修复 clippy 风格警告`（Task 2/3/4 文件）
        - `docs: 更新 AGENTS 与 CHANGELOG 记录 Node 24 与 clippy 修复`（Task 5.1/5.2 文件）
  - 验证：每个 commit 遵循 Conventional Commits；`git log` 可见 3 个独立 commit

# Task Dependencies

- Task 1 / Task 2 / Task 3 / Task 4 互不依赖，**Batch 1 可并行**
- Task 5 依赖 Task 1-4 完成
