# 修复 CI 中 flutter_rust_bridge_codegen 依赖缺失 Spec

## Why
CI 运行到 `flutter_rust_bridge_codegen generate` 步骤时报错：
1. `cargo expand` 命令不存在，codegen 虽会自动安装 `cargo-expand`，但耗时且增加失败面；
2. `MissingDep: Please add freezed to your dev_dependencies. (version >=1.0.0)`。

这两个缺失阻塞了 App 全平台构建与 cargo-doc 文档生成，需要显式补齐依赖。

## What Changes
- **`.github/workflows/app.yml`**：在 `flutter_rust_bridge_codegen generate` 之前预装 `cargo-expand`（带版本锁定），避免 codegen 自动安装的不确定性与耗时。
- **`app/pubspec.yaml`**：在 `dev_dependencies` 中添加 `freezed` 与 `build_runner`；在 `dependencies` 中添加 `freezed_annotation`，满足 frb v2 生成代码对 freezed 生态的依赖。
- **文档同步**：更新 `CHANGELOG.md` 与 `AGENTS.md`，记录 codegen 需要 `cargo-expand` 与 freezed 的约定。

## Impact
- 受影响代码：
  - `.github/workflows/app.yml` — 新增 cargo-expand 安装步骤
  - `app/pubspec.yaml` — 新增 freezed / build_runner / freezed_annotation
- 受影响文档：`CHANGELOG.md`、`AGENTS.md`
- 不影响业务逻辑、协议、引脚分配、UI

## ADDED Requirements

### Requirement: CI 预装 cargo-expand
CI SHALL 在执行 `flutter_rust_bridge_codegen generate` 之前，通过 `cargo install cargo-expand --version <locked>` 预装 `cargo-expand`，确保 codegen 的 `cargo expand` 调用可用，且不依赖自动安装逻辑。

#### Scenario: codegen 不等待自动安装 cargo-expand
- **WHEN** `flutter_rust_bridge_codegen generate` 启动
- **THEN** `cargo expand` 已存在于 PATH 中
- **AND** 不再出现 `no such command: expand` 与自动安装重试的耗时/失败

### Requirement: pubspec 补齐 freezed 生态
`app/pubspec.yaml` SHALL 包含 frb v2 生成代码所需的 freezed 依赖：
- `dependencies` 中声明 `freezed_annotation`（运行时注解）
- `dev_dependencies` 中声明 `freezed` 与 `build_runner`（代码生成工具）

#### Scenario: codegen 不再报 MissingDep
- **WHEN** `flutter_rust_bridge_codegen generate` 执行
- **THEN** 不再出现 `MissingDep: Please add freezed to your dev_dependencies`
- **AND** `flutter pub get` 成功解析所有依赖

## MODIFIED Requirements

### Requirement: App CI 构建流水线
仓库 SHALL 保证 `app.yml` 在 `flutter_rust_bridge_codegen generate` 之前已预装好 `cargo-expand`，且 `app/pubspec.yaml` 已声明 freezed 相关依赖。

#### Scenario: App 全平台构建通过
- **WHEN** `app.yml` 触发
- **THEN** `flutter_rust_bridge_codegen generate` 成功生成 `frb_generated.rs` 与 Dart 绑定
- **AND** 后续 `flutter pub get` 与 `flutter build` 不再因 freezed 缺失失败
