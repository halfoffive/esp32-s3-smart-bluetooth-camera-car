# Checklist

## List Android project files 步骤
- [x] `app.yml` 的 "List Android project files" 步骤使用 `build.gradle*` glob 兼容两种扩展名

## Patch Android compileSdk 步骤
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤自动检测 `build.gradle` 或 `build.gradle.kts`
- [x] 检测到 `.kts` 文件时 sed 正常执行
- [x] 检测到 Groovy 文件时 sed 正常执行
- [x] 两种文件均不存在时输出明确错误信息并以非零退出码退出
- [x] subprojects 块追加到检测到的根 build 文件

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下记录 Gradle 文件扩展名兼容修复
