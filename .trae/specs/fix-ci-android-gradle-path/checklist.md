# Checklist

## Android compileSdk patch 路径修复
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤包含 `working-directory: app`
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤使用 `android/app/build.gradle` 路径
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤使用 `android/build.gradle` 路径
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤显式指定 `shell: bash`

## 诊断步骤
- [x] `app.yml` 在 "Patch Android compileSdk" 前包含 "List Android project files" 诊断步骤
- [x] 诊断步骤使用 `working-directory: app` 并列出 `android/app/build.gradle` 与 `android/build.gradle`

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下记录 Android patch 路径修复
- [x] `AGENTS.md` 追加 Android patch 工作目录约定
