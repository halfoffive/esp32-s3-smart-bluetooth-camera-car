# Tasks

## 修复 Windows 构建失败

- [x] Task 1: 在 CI Windows 构建步骤注入 MSVC 弃用抑制宏
  - [x] 1.1 在 `.github/workflows/app.yml` 的 `Build Windows desktop` 步骤设置环境变量 `CL: /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`，使 MSVC 在编译 `permission_handler_windows` 等使用 `<experimental/coroutine>` 的插件时不再触发 `STL1011` 静态断言。
  - [x] 1.2 验证 YAML 语法：工作流文件可正常解析，Windows 构建步骤仍仅在 `matrix.flutter_target == 'windows'` 时执行。

- [x] Task 2: 更新仓库备忘文档
  - [x] 2.1 在 `AGENTS.md`「工具链陷阱」或新增「Windows 桌面构建」小节中记录：Visual Studio 2026 / MSVC 14.51 弃用 `<experimental/coroutine>`，本地或 CI 构建 Windows 桌面端时需设置 `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`。
  - [x] 2.2 在 `CHANGELOG.md` 的 `[Unreleased]` → Fixed 下新增条目：修复 Windows 桌面 release 构建因 `permission_handler_windows` 引用弃用协程头而在 MSVC 14.51 下失败的问题。

- [x] Task 3: 提交变更
  - [x] 3.1 使用 `git add` 暂存 `.github/workflows/app.yml`、`AGENTS.md`、`CHANGELOG.md`。
  - [x] 3.2 使用 Conventional Commits 提交：`fix(ci/app): 注入 _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS 修复 Windows 构建`（若 docs 变更需同步提交或拆分为 `docs(agents)` / `docs(changelog)`，优先一次提交）。

# Task Dependencies

- Task 1 与 Task 2 互不依赖，可并行。
- Task 3 依赖 Task 1 与 Task 2 完成。
