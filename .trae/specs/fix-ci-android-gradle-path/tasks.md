# Tasks

- [ ] Task 1: 调整 Android compileSdk patch 步骤的工作目录与路径
  - [ ] SubTask 1.1: 在 `app.yml` 的 "Patch Android compileSdk" 步骤添加 `working-directory: app`
  - [ ] SubTask 1.2: 将 `test -f app/android/app/build.gradle` 改为 `test -f android/app/build.gradle`
  - [ ] SubTask 1.3: 将 `sed -i ... app/android/app/build.gradle` 改为 `sed -i ... android/app/build.gradle`
  - [ ] SubTask 1.4: 将 `cat >> app/android/build.gradle` 改为 `cat >> android/build.gradle`
  - [ ] SubTask 1.5: 为该步骤显式指定 `shell: bash`

- [ ] Task 2: 增加 Android 文件存在性诊断步骤
  - [ ] SubTask 2.1: 在 "Patch Android compileSdk" 步骤前新增 "List Android project files" 步骤
  - [ ] SubTask 2.2: 设置 `working-directory: app` 与 `shell: bash`
  - [ ] SubTask 2.3: 运行 `ls -la android/app/build.gradle android/build.gradle` 以便日志排查

- [ ] Task 3: 同步文档
  - [ ] SubTask 3.1: 在 `CHANGELOG.md` `[Unreleased]` Fixed 下记录路径修复
  - [ ] SubTask 3.2: 在 `AGENTS.md` 追加 Android patch 步骤须在 `app/` 工作目录内执行、使用相对路径的约定

# Task Dependencies

- Task 2 依赖 Task 1（诊断步骤验证的是 Task 1 调整后的路径）
- Task 3 依赖 Task 1 / Task 2 完成后汇总变更点
