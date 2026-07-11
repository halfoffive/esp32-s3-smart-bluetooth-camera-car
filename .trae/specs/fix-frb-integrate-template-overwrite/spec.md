# 修复 frb integrate 覆盖 lib/main.dart 模板 Spec

## Why

`flutter_rust_bridge_codegen integrate` 以模板覆盖方式注入 `rust_builder/` 构建系统时，会**覆写** `lib/main.dart`：将原有内容注释掉，并注入模板演示代码（import `simple.dart` + 调用 `greet`）。CI 中随后删除 `simple.dart` 但 `main.dart` 仍引用它，导致 `flutter build apk` 编译失败。

## What Changes

- **`.github/workflows/app.yml`**：在 `integrate` 命令之后，用 `git checkout -- lib/main.dart` 恢复被覆写的入口文件；同时清理 `integrate` 生成的其他模板演示文件（`integration_test/simple_test.dart`、`test_driver/integration_test.dart`）。
- **`AGENTS.md`**：补充 `integrate` 会覆写 `lib/main.dart` 的陷阱说明。
- **`CHANGELOG.md`**：新增 Fixed 条目。

## Impact

- 受影响代码：`.github/workflows/app.yml` — `Integrate flutter_rust_bridge (Android)` 步骤
- 受影响文档：`AGENTS.md`、`CHANGELOG.md`
- 不影响业务逻辑、协议、引脚分配、UI

## ADDED Requirements

### Requirement: integrate 后恢复项目文件

CI 中执行 `flutter_rust_bridge_codegen integrate` 后，系统 SHALL 恢复被模板覆写的 `lib/main.dart`，并清理所有模板演示文件，确保后续 `generate` 与 `flutter build` 步骤使用项目真实的入口文件。

#### Scenario: integrate 覆写 main.dart 后恢复

- **WHEN** CI 在 `flutter create .` 之后执行 `flutter_rust_bridge_codegen integrate`
- **THEN** `lib/main.dart` 被 `git checkout` 恢复为版本控制中的真实内容
- **AND** 模板演示文件 `rust/src/api/simple.rs`、`lib/src/rust/api/simple.dart`、`integration_test/simple_test.dart`、`test_driver/integration_test.dart` 被删除
- **AND** 后续 `flutter_rust_bridge_codegen generate` 与 `flutter build apk` 正常通过
