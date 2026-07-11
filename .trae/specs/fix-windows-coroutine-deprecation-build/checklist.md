# Checklist

## CI Windows 构建步骤
- [x] `.github/workflows/app.yml` 中 `Build Windows desktop` 步骤带有 `env:` 块设置 `CL: /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`
- [x] 该步骤仍保留 `if: matrix.flutter_target == 'windows'` 条件
- [x] YAML 语法有效（无缩进错误、无非法字符）

## 文档同步
- [x] `AGENTS.md` 已新增或更新 Windows 桌面构建工具链陷阱，说明 MSVC 14.51 弃用 `<experimental/coroutine>` 及所需 `CL` 环境变量
- [x] `CHANGELOG.md` `[Unreleased]` → Fixed 下已记录本次 Windows 构建修复

## 提交
- [ ] 相关文件已用 `git add` 加入暂存区
- [ ] 提交信息符合 Conventional Commits 规范
