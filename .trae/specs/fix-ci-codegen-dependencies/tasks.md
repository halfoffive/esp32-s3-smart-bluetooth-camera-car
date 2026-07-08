# Tasks

## Bug 1: codegen 缺少 cargo-expand

- [x] Task 1: 在 app.yml 中预装 cargo-expand
  - [x] 1.1 在 `cargo-doc` job 的 `Install flutter_rust_bridge_codegen` 步骤之前新增 `Install cargo-expand` 步骤，使用 `cargo install cargo-expand --version 1.0.88 --locked`（或当前兼容稳定版的锁定版本）
  - [x] 1.2 在 `build-matrix` job 的 `Install flutter_rust_bridge_codegen` 步骤之前新增同样的 `Install cargo-expand` 步骤
  - 验证：CI 中 `flutter_rust_bridge_codegen generate` 不再出现 `no such command: expand`，也不再触发自动安装重试

## Bug 2: codegen 缺少 freezed 依赖

- [x] Task 2: 在 pubspec.yaml 中补齐 freezed 生态
  - [x] 2.1 在 `dependencies` 中添加 `freezed_annotation: ^2.4.1`
  - [x] 2.2 在 `dev_dependencies` 中添加 `freezed: ^2.5.7` 与 `build_runner: ^2.4.11`
  - [x] 2.3 确认 `flutter pub get` 在本地/CI 中成功解析，无版本冲突
  - 验证：CI 中 `flutter_rust_bridge_codegen generate` 不再报 `MissingDep: Please add freezed to your dev_dependencies`

## 文档同步

- [x] Task 3: 更新 CHANGELOG / AGENTS
  - [x] 3.1 `CHANGELOG.md` 在 `[Unreleased]` → Fixed 下记录 cargo-expand 与 freezed 依赖修复，并删除与之矛盾的"移除 cargo-expand"旧条目
  - [x] 3.2 `AGENTS.md` 追加工具链陷阱：frb v2 codegen 需要 `cargo-expand`（CI 应预装），且生成的 Dart 代码依赖 `freezed_annotation`/`freezed`/`build_runner`
  - 验证：两个文档均反映最新 CI 行为

# Task Dependencies
- Task 1 / Task 2 互不依赖，可并行
- Task 3 依赖 Task 1 / 2 完成后汇总变更点
