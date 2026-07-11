# Tasks

- [x] Task 1: 修复 CI 中 integrate 步骤：恢复 main.dart 并清理模板文件
  - [x] 1.1: 在 `.github/workflows/app.yml` 的 `Integrate flutter_rust_bridge (Android)` 步骤中，`integrate` 命令后新增 `git checkout -- lib/main.dart` 恢复被覆写的入口文件
  - [x] 1.2: 扩展 `rm -f` 清理范围，新增删除 `integration_test/simple_test.dart` 与 `test_driver/integration_test.dart`
  - [x] 1.3: 更新步骤内注释，说明 `integrate` 会覆写 `lib/main.dart` 的陷阱
- [x] Task 2: 更新文档
  - [x] 2.1: `AGENTS.md` 补充 `integrate` 覆写 `lib/main.dart` 的陷阱条目
  - [x] 2.2: `CHANGELOG.md` 在 `[Unreleased]` 下新增 Fixed 条目
