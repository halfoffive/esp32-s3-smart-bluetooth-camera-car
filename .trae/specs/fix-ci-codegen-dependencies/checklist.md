# Checklist

## Bug 1: cargo-expand 预装
- [x] `app.yml` 的 `cargo-doc` job 在 `Install flutter_rust_bridge_codegen` 之前包含 `Install cargo-expand` 步骤
- [x] `app.yml` 的 `build-matrix` job 同样包含 `Install cargo-expand` 步骤
- [x] cargo-expand 安装命令带 `--version 1.0.88 --locked` 锁定版本
- [x] CI 中 `flutter_rust_bridge_codegen generate` 不再出现 `no such command: expand`

## Bug 2: freezed 依赖补齐
- [x] `app/pubspec.yaml` 的 `dependencies` 包含 `freezed_annotation: ^2.4.1`
- [x] `app/pubspec.yaml` 的 `dev_dependencies` 包含 `freezed: ^2.5.7` 与 `build_runner: ^2.4.11`
- [x] `flutter pub get` 成功解析所有依赖，无版本冲突
- [x] CI 中 `flutter_rust_bridge_codegen generate` 不再报 `MissingDep: Please add freezed to your dev_dependencies`

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下记录 cargo-expand 与 freezed 依赖修复，并删除矛盾的"移除 cargo-expand"旧条目
- [x] `AGENTS.md` 追加 frb v2 codegen 需要 cargo-expand 与 freezed 生态的陷阱说明
