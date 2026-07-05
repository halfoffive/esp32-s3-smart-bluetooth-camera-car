# Tasks

- [x] Task 1: 修改 "List Android project files" 步骤兼容两种扩展名
  - [x] SubTask 1.1: 将 `ls -la android/app/build.gradle android/build.gradle` 改为 `ls -la android/app/build.gradle* android/build.gradle*`

- [x] Task 2: 修改 "Patch Android compileSdk" 步骤自动检测 Gradle 文件扩展名
  - [x] SubTask 2.1: 用 shell 变量 `APP_GRADLE` 检测 `android/app/build.gradle` 或 `android/app/build.gradle.kts`，两者均不存在时报错退出
  - [x] SubTask 2.2: 用 shell 变量 `ROOT_GRADLE` 检测 `android/build.gradle` 或 `android/build.gradle.kts`
  - [x] SubTask 2.3: 对 `$APP_GRADLE` 执行 sed patch compileSdk 至 35
  - [x] SubTask 2.4: 对 `$ROOT_GRADLE` 追加 subprojects 块

- [x] Task 3: 同步文档
  - [x] SubTask 3.1: 在 `CHANGELOG.md` `[Unreleased]` Fixed 下记录 Gradle 文件扩展名兼容修复

# Task Dependencies

- Task 2 依赖 Task 1（诊断步骤验证 Task 2 检测逻辑）
- Task 3 依赖 Task 1 / Task 2 完成后汇总变更点
