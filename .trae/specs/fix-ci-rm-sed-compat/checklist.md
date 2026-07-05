# Checklist

## Bug 1: Windows runner rm -rf 兼容性
- [x] `app.yml` 的 `cargo-doc` job 的 "Clean platform directories" 步骤包含 `shell: bash`
- [x] `app.yml` 的 `build-matrix` job 的 "Clean platform directories" 步骤包含 `shell: bash`
- [x] Windows runner 上 `rm -rf` 不再报 `A parameter cannot be found that matches parameter name 'rf'`

## Bug 2: Android patch 文件存在性守卫
- [x] `app.yml` 的 "Patch Android compileSdk" 步骤在 sed 前有 `test -f` 守卫
- [x] build.gradle 缺失时输出 `ERROR: app/android/app/build.gradle not found` 并以非零退出码退出
- [x] build.gradle 存在时 sed 正常执行，compileSdk 被提升至 35

## 文档同步
- [x] `CHANGELOG.md` `[Unreleased]` Fixed 下记录两处修复
- [x] `AGENTS.md` 追加 Windows runner 须为 `rm -rf` 指定 `shell: bash` 的陷阱
