# 修复 Windows 桌面构建因 MSVC 弃用 <experimental/coroutine> 而失败

## Why

CI 在 `windows-latest` runner 上执行 `flutter build windows --release` 时，`permission_handler_windows` 插件引用了 MSVC 14.51（Visual Studio 2026）已弃用的 `<experimental/coroutine>` 头文件，触发 `STL1011` 静态断言错误，导致 Windows 桌面包构建失败。需要在 CI 中提供兼容开关，使构建能继续使用当前插件版本完成编译。

## What Changes

- 在 `.github/workflows/app.yml` 的 `Build Windows desktop` 步骤注入 MSVC 编译器宏 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`，抑制 `STL1011` 静态断言。
- 更新 `AGENTS.md`，记录 Visual Studio 2026 / MSVC 14.51 下 Windows 桌面构建需要设置该宏的工作区约定。
- 更新 `CHANGELOG.md`，在 `[Unreleased]` → Fixed 下记录本次修复。

## Impact

- 受影响的 CI job：`app.yml` 的 `build-matrix` Windows 矩阵条目。
- 受影响的能力：Windows 桌面 release 产物重新可构建、可上传 artifact。
- 无 Dart/Rust 业务代码变更；`permission_handler` 的 Dart API 使用保持不变。

## ADDED Requirements

### Requirement: Windows 构建兼容性开关
CI 在 Visual Studio 2026 / MSVC 14.51 环境下 SHALL 能成功编译 `permission_handler_windows` 插件。

#### Scenario: Windows release 构建成功
- **WHEN** CI 执行 `flutter build windows --release`
- **THEN** MSVC 不再因 `<experimental/coroutine>` 弃用报错，构建退出码为 0，且 `app/build/windows/x64/runner/Release` 生成可执行产物。

### Requirement: 文档记录
仓库 SHALL 在 `AGENTS.md` 中记录 Windows 桌面构建遇到 MSVC 2026 协程头弃用时的处理方式。

#### Scenario: 后续会话可复现修复
- **WHEN** 新会话在 VS 2026 环境下遇到相同 STL1011 错误
- **THEN** 通过阅读 `AGENTS.md` 可知道需要设置 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`。

## MODIFIED Requirements

无。

## REMOVED Requirements

无。
